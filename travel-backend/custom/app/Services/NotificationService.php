<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\DeviceToken;
use App\Models\Reservation;
use App\Models\Vol;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Exception\MessagingException;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Throwable;

/**
 * Service centralisé pour l'envoi de notifications FCM et la persistance
 * des notifications in-app.
 *
 * FIX: Messaging résolu lazily via app() avec try-catch pour éviter les 500
 * sur tous les controllers qui dépendent de ce service (VolController,
 * ReservationService…) quand firebase.php n'est pas encore publié ou que
 * les credentials sont invalides. Une fois config:cache lancé avec firebase.php
 * présent, Firebase fonctionne normalement et les notifications FCM sont envoyées.
 */
class NotificationService
{
    public function __construct() {}

    // ─────────────────────────────────────────────────────────────────────────
    // Résolution lazy de Messaging
    // ─────────────────────────────────────────────────────────────────────────

    private function getMessaging(): ?Messaging
    {
        try {
            /** @var Messaging $messaging */
            $messaging = app(Messaging::class);
            return $messaging;
        } catch (Throwable $e) {
            Log::warning('NotificationService: Firebase Messaging non disponible — FCM désactivé.', [
                'error' => $e->getMessage(),
            ]);
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Méthodes publiques
    // ─────────────────────────────────────────────────────────────────────────

    public function sendReservationConfirmed(Reservation $reservation): void
    {
        $this->dispatch(
            userId: $reservation->user_id,
            type:   'reservation_confirmed',
            title:  '✅ Réservation confirmée',
            body:   "Votre réservation {$reservation->reference} est confirmée. Bon voyage !",
            data:   [
                'type'           => 'reservation_confirmed',
                'reservation_id' => (string) $reservation->id,
                'reference'      => $reservation->reference,
            ]
        );
    }

    public function sendReservationCancelled(Reservation $reservation): void
    {
        $this->dispatch(
            userId: $reservation->user_id,
            type:   'reservation_cancelled',
            title:  '❌ Réservation annulée',
            body:   "Votre réservation {$reservation->reference} a été annulée.",
            data:   [
                'type'           => 'reservation_cancelled',
                'reservation_id' => (string) $reservation->id,
                'reference'      => $reservation->reference,
            ]
        );
    }

    public function sendFlightStatusChanged(Vol $vol, string $ancienStatut): void
    {
        $userIds = $vol->reservations()
            ->whereNotIn('statut', ['annulee', 'terminee'])
            ->pluck('user_id')
            ->unique();

        $labelStatut = match ($vol->statut) {
            'en_vol'  => 'En vol ✈️',
            'atterri' => 'Atterri 🛬',
            'annule'  => 'Annulé ❌',
            'retarde' => 'Retardé ⏳',
            default   => ucfirst($vol->statut),
        };

        foreach ($userIds as $userId) {
            $this->dispatch(
                userId: $userId,
                type:   'flight_status',
                title:  "Vol {$vol->numero_vol} — {$labelStatut}",
                body:   "Le statut de votre vol {$vol->numero_vol} est maintenant : {$labelStatut}.",
                data:   [
                    'type'   => 'flight_status',
                    'vol_id' => (string) $vol->id,
                ]
            );
        }
    }

    public function sendSeatLockExpiring(int $userId, string $seatNumber, int $volId): void
    {
        $this->dispatch(
            userId: $userId,
            type:   'seat_lock_expiring',
            title:  '⏰ Siège bientôt libéré',
            body:   "Votre réservation du siège {$seatNumber} expire dans 2 minutes. Finalisez votre réservation.",
            data:   [
                'type'   => 'seat_lock_expiring',
                'vol_id' => (string) $volId,
            ]
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Méthode cœur — persiste en base PUIS envoie FCM
    // ─────────────────────────────────────────────────────────────────────────

    public function dispatch(
        int    $userId,
        string $type,
        string $title,
        string $body,
        array  $data = []
    ): void {
        // 1. Persistance in-app — toujours, même sans Firebase.
        try {
            AppNotification::create([
                'user_id' => $userId,
                'type'    => $type,
                'title'   => $title,
                'body'    => $body,
                'data'    => $data,
            ]);
        } catch (Throwable $e) {
            Log::error('NotificationService: échec persistance AppNotification', [
                'user_id' => $userId,
                'type'    => $type,
                'error'   => $e->getMessage(),
            ]);
        }

        // 2. Envoi FCM — lazy, silencieux en cas d'échec.
        $messaging = $this->getMessaging();

        if ($messaging === null) {
            return; // warning déjà loggé dans getMessaging()
        }

        $tokens = DeviceToken::tokensForUser($userId);
        if (empty($tokens)) {
            return;
        }

        $this->sendFcm($messaging, $tokens, $title, $body, $data);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Envoi FCM par lots de 500
    // ─────────────────────────────────────────────────────────────────────────

    private function sendFcm(
        Messaging $messaging,
        array     $tokens,
        string    $title,
        string    $body,
        array     $data
    ): void {
        $stringData   = array_map('strval', $data);
        $notification = Notification::create($title, $body);

        foreach (array_chunk($tokens, 500) as $chunk) {
            try {
                $messages = array_map(
                    function (string $token) use ($notification, $stringData): CloudMessage {
                        return CloudMessage::withTarget('token', $token)
                            ->withNotification($notification)
                            ->withData($stringData)
                            ->withAndroidConfig([
                                'priority'     => 'high',
                                'notification' => [
                                    'channel_id' => 'voyageur_main',
                                    'sound'      => 'default',
                                ],
                            ])
                            ->withApnsConfig([
                                'headers' => ['apns-priority' => '10'],
                                'payload' => ['aps' => ['sound' => 'default']],
                            ]);
                    },
                    $chunk
                );

                $report = $messaging->sendAll($messages);

                foreach ($report->failures()->getItems() as $failure) {
                    $invalidToken = $failure->target()->value();

                    Log::warning('NotificationService: token FCM invalide — suppression.', [
                        'token'  => $invalidToken,
                        'reason' => $failure->error()?->getMessage(),
                    ]);

                    DeviceToken::where('token', $invalidToken)->delete();
                }
            } catch (MessagingException $e) {
                Log::error('NotificationService: erreur batch FCM.', [
                    'error' => $e->getMessage(),
                ]);
            } catch (Throwable $e) {
                Log::error('NotificationService: erreur inattendue FCM.', [
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }
}
