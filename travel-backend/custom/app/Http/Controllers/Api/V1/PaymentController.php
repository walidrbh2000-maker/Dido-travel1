<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\PaymentService;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PaymentController extends Controller
{
    public function __construct(
        private PaymentService $paymentService
    ) {}

    public function process(Request $request): JsonResponse
    {
        $request->validate([
            'reservation_id' => 'required|exists:reservations,id',
            // BUG B FIX: accepter les méthodes algériennes locales en plus de 'stripe'
            // 'carte' et 'paypal' retirés car non disponibles en Algérie
            'methode'        => 'required|in:carte_doree,cib,virement,stripe',
            'token'          => 'required|string',
        ]);

        $payment = $this->paymentService->processPayment(
            $request->reservation_id,
            $request->methode,
            $request->token
        );

        return response()->json([
            'message' => 'Paiement traité',
            'payment' => $payment,
        ]);
    }

    public function show(Payment $payment): JsonResponse
    {
        $this->authorizePayment($payment);

        return response()->json($payment->load('reservation'));
    }

    private function authorizePayment(Payment $payment): void
    {
        if ($payment->reservation->user_id !== auth()->id() && !auth()->user()->isAdmin()) {
            abort(403, 'Accès non autorisé');
        }
    }
}