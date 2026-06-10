<?php

namespace App\Jobs;

use App\Models\Seat;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Job dispatché avec un délai de 8 minutes lors du verrouillage d'un siège.
 * Il vérifie que le siège est toujours bloqué (pas encore réservé ou libéré)
 * avant d'envoyer la notification d'avertissement.
 *
 * Durée du verrou = 10 min → Avertissement à t+8 min → 2 min restantes.
 */
class SeatLockExpiryWarning implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 1; // Pas de retry — l'avertissement n'a de sens qu'une fois

    public function __construct(
        private readonly int    $seatId,
        private readonly int    $userId,
        private readonly string $seatNumber,
        private readonly int    $volId,
    ) {}

    public function handle(NotificationService $notificationService): void
    {
        $seat = Seat::find($this->seatId);

        // Ne rien faire si le siège a déjà été réservé ou libéré
        if (! $seat || $seat->statut !== 'bloque') {
            return;
        }

        // Vérifier que le verrou n'est pas déjà expiré
        if ($seat->bloque_jusqu_a && $seat->bloque_jusqu_a->isPast()) {
            return;
        }

        $notificationService->sendSeatLockExpiring(
            userId:     $this->userId,
            seatNumber: $this->seatNumber,
            volId:      $this->volId,
        );
    }
}
