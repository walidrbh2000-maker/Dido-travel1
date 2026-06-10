<?php

namespace App\Services;

use App\Models\{Payment, Reservation};
use Illuminate\Support\Facades\DB;
use Stripe\Charge;
use Stripe\Stripe;

class PaymentService
{
    // BUG B FIX: ne pas initialiser Stripe dans le constructeur car la clé peut
    // être vide ; l'initialisation se fait uniquement si la méthode = 'stripe'.
    public function __construct() {}

    public function processPayment(int $reservationId, string $methode, string $token): Payment
    {
        $reservation = Reservation::findOrFail($reservationId);

        if ($reservation->statut === 'payee' || $reservation->statut === 'confirmee') {
            throw new \Exception('Cette réservation est déjà payée');
        }

        return DB::transaction(function () use ($reservation, $methode, $token) {

            // ── BUG B FIX : méthodes algériennes locales (sans Stripe) ────────
            if ($methode === 'carte_doree' || $methode === 'cib') {
                // Paiement local immédiat : pas de Stripe, statut 'payee'
                $payment = Payment::create([
                    'reservation_id'    => $reservation->id,
                    'montant'           => $reservation->prix_total,
                    'methode'           => $methode,
                    'stripe_payment_id' => null,
                    'statut'            => 'succeeded',
                ]);

                // FIX: 'payee' car le paiement local est immédiatement validé
                $reservation->update(['statut' => 'payee']);

                return $payment;
            }

            // ── BUG B FIX : virement bancaire (en attente de réception) ───────
            if ($methode === 'virement') {
                // Virement : paiement pending, réservation reste 'en_attente'
                $payment = Payment::create([
                    'reservation_id'    => $reservation->id,
                    'montant'           => $reservation->prix_total,
                    'methode'           => $methode,
                    'stripe_payment_id' => null,
                    'statut'            => 'pending',
                ]);

                // BUG B FIX: 'en_attente' car le virement n'est pas encore reçu
                // (la réservation reste en_attente, pas de changement de statut)

                return $payment;
            }

            // ── BUG B FIX : Stripe uniquement pour la méthode 'stripe' ────────
            if ($methode === 'stripe') {
                $stripeSecret = config('services.stripe.secret');

                // BUG B FIX: lever une exception métier claire si Stripe non configuré
                if (empty($stripeSecret)) {
                    throw new \Exception(
                        'Le paiement par carte internationale (Stripe) n\'est pas '
                        . 'configuré sur ce serveur. Choisissez une autre méthode.'
                    );
                }

                Stripe::setApiKey($stripeSecret);

                try {
                    $charge = Charge::create([
                        'amount'      => (int) ($reservation->prix_total * 100),
                        'currency'    => 'eur',
                        'source'      => $token,
                        'description' => "Réservation {$reservation->reference}",
                    ]);

                    $payment = Payment::create([
                        'reservation_id'    => $reservation->id,
                        'montant'           => $reservation->prix_total,
                        'methode'           => $methode,
                        'stripe_payment_id' => $charge->id,
                        'statut'            => 'succeeded',
                    ]);

                    // BUG B FIX: 'payee' uniquement si paiement Stripe effectivement réussi
                    $reservation->update(['statut' => 'payee']);

                    return $payment;

                } catch (\Exception $e) {
                    Payment::create([
                        'reservation_id'    => $reservation->id,
                        'montant'           => $reservation->prix_total,
                        'methode'           => $methode,
                        'stripe_payment_id' => null,
                        'statut'            => 'failed',
                    ]);

                    throw new \Exception('Le paiement Stripe a échoué : ' . $e->getMessage());
                }
            }

            // Méthode inconnue (ne devrait pas arriver si la validation est correcte)
            throw new \Exception("Méthode de paiement inconnue : {$methode}");
        });
    }
}
