<?php

namespace App\Services;

use App\Models\{User, Reservation, Vol, Hotel, Passenger, Seat};
use App\Services\NotificationService;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;

class ReservationService
{
    public function __construct(
        private readonly SeatService         $seatService,
        private readonly NotificationService $notificationService,
    ) {}

    public function createReservation(User $user, array $data): Reservation
    {
        $reservation = DB::transaction(function () use ($user, $data) {
            // ── Vol aller ──────────────────────────────────────────────────
            /** @var Vol $vol */
            $vol = Vol::lockForUpdate()->findOrFail($data['vol_id']);

            $passagers       = collect($data['passengers']);
            $nombreNonBebes  = $passagers->filter(fn($p) =>
                Carbon::parse($p['date_naissance'])->diffInYears(now()) >= 2
            )->count();

            if ($vol->places_disponibles < $nombreNonBebes) {
                throw new \Exception('Places insuffisantes sur ce vol.');
            }

            // ── Vol retour ─────────────────────────────────────────────────
            $volRetour = null;
            if (($data['type_trajet'] ?? 'aller_simple') === 'aller_retour') {
                $volRetour = Vol::lockForUpdate()->findOrFail($data['vol_retour_id']);
                if ($volRetour->places_disponibles < $nombreNonBebes) {
                    throw new \Exception('Places insuffisantes sur le vol retour.');
                }
            }

            // ── Calcul prix ────────────────────────────────────────────────
            $prixTotal = $this->calculerPrixTotal($vol, $volRetour, $data);

            // ── Création réservation ───────────────────────────────────────
            $reservation = Reservation::create([
                'user_id'          => $user->id,
                'vol_id'           => $vol->id,
                'type_trajet'      => $data['type_trajet'] ?? 'aller_simple',
                'vol_retour_id'    => $volRetour?->id,
                'hotel_id'         => $data['hotel_id'] ?? null,
                'guide_id'         => $data['guide_id'] ?? null,
                'date_debut'       => $data['date_debut'],
                'date_fin'         => $data['date_fin'],
                'nombre_personnes' => count($data['passengers']),
                'prix_total'       => $prixTotal,
                'statut'           => 'en_attente',
                'reference'        => Reservation::generateReference(),
            ]);

            // ── Création passagers + confirmation sièges ───────────────────
            foreach ($data['passengers'] as $i => $pd) {
                $typePassager = Passenger::determinerType(
                    Carbon::parse($pd['date_naissance']),
                    Carbon::parse($data['date_debut'])
                );

                $passenger = Passenger::create([
                    'reservation_id'        => $reservation->id,
                    'prenom'                => $pd['prenom'],
                    'nom'                   => $pd['nom'],
                    'date_naissance'        => $pd['date_naissance'],
                    'type_passager'         => $typePassager,
                    'numero_passeport'      => $pd['numero_passeport'] ?? null,
                    'nationalite'           => $pd['nationalite'] ?? null,
                    'genre'                 => $pd['genre'],
                    'est_contact_principal' => $i === 0,
                ]);

                // Siège aller
                if (! empty($pd['seat_id']) && $typePassager !== 'bebe') {
                    $this->seatService->confirmerReservation(
                        (int) $pd['seat_id'],
                        $reservation->id
                    );
                    $passenger->update(['seat_id' => $pd['seat_id']]);
                }

                // Siège retour
                if (! empty($pd['seat_retour_id']) && $typePassager !== 'bebe' && $volRetour) {
                    $this->seatService->confirmerReservation(
                        (int) $pd['seat_retour_id'],
                        $reservation->id
                    );
                    $passenger->update(['seat_retour_id' => $pd['seat_retour_id']]);
                }
            }

            // ── Décrémenter places ─────────────────────────────────────────
            $vol->decrementSeats($nombreNonBebes);
            $volRetour?->decrementSeats($nombreNonBebes);

            return $reservation->load([
                'passengers.seat',
                'passengers.seatRetour',
                'vol.destination',
                'volRetour.destination',
                'hotel',
                'guide',
            ]);
        });

        // ── Notification hors transaction (évite de bloquer le commit) ─────
        // NOTE: on n'envoie la notif "confirmée" qu'après paiement validé dans
        // PaymentService. Ici on notifie uniquement la création (en_attente).
        // Si votre flux confirme directement à la création, appelez plutôt
        // sendReservationConfirmed().
        $this->notificationService->dispatch(
            userId:  $reservation->user_id,
            type:    'reservation_created',
            title:   '🎫 Réservation créée',
            body:    "Votre réservation {$reservation->reference} est en attente de paiement.",
            data:    [
                'type'           => 'reservation_created',
                'reservation_id' => (string) $reservation->id,
                'reference'      => $reservation->reference,
            ]
        );

        return $reservation;
    }

    /**
     * Met à jour une réservation existante.
     */
    public function updateReservation(Reservation $reservation, array $data): Reservation
    {
        $reservation->update($data);
        return $reservation->load(['vol.destination', 'hotel']);
    }

    public function cancelReservation(Reservation $reservation): void
    {
        DB::transaction(function () use ($reservation) {
            // Libérer les sièges
            Seat::where('reservation_id', $reservation->id)
                ->update(['statut' => 'disponible', 'reservation_id' => null, 'bloque_jusqu_a' => null]);

            // Compter uniquement les passagers non-bébés
            $nonBebes = $reservation->passengers()
                ->where('type_passager', '!=', 'bebe')
                ->count();

            $reservation->vol->increment('places_disponibles', $nonBebes);
            $reservation->volRetour?->increment('places_disponibles', $nonBebes);

            $reservation->update(['statut' => 'annulee']);
        });

        // Notification d'annulation (hors transaction)
        $this->notificationService->sendReservationCancelled($reservation);
    }

    /**
     * Appelé par PaymentService après validation du paiement.
     */
    public function confirmReservation(Reservation $reservation): void
    {
        $reservation->update(['statut' => 'confirmee']);
        $this->notificationService->sendReservationConfirmed($reservation);
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private function calculerPrixTotal(Vol $vol, ?Vol $volRetour, array $data): float
    {
        $total = 0.0;

        foreach ($data['passengers'] as $pd) {
            $age = Carbon::parse($pd['date_naissance'])->diffInYears(now());

            $multiplicateur = match (true) {
                $age < 2  => 0.10,  // bébé
                $age < 12 => 0.75,  // enfant
                default   => 1.00,  // adulte
            };

            $total += $vol->prix * $multiplicateur;
            if ($volRetour) {
                $total += $volRetour->prix * $multiplicateur;
            }
        }

        // Hôtel
        if (! empty($data['hotel_id'])) {
            $hotel = Hotel::findOrFail($data['hotel_id']);
            $nuits  = Carbon::parse($data['date_debut'])->diffInDays($data['date_fin']);
            $total += $hotel->prix_nuit * max($nuits, 1);
        }

        return round($total, 2);
    }
}
