import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/utils/helpers/currency_helper.dart';
import 'package:voyageur/providers/payment/payment_provider.dart';
import 'package:voyageur/screens/payment/widgets/order_summary.dart';
import 'package:voyageur/screens/payment/widgets/payment_method_card.dart';
import 'package:voyageur/screens/payment/widgets/secure_payment_badge.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int _selectedMethod = 0;
  bool _isProcessing = false;

  // Données de réservation injectées via GoRouter extra.
  int? _reservationId;
  double _total = 0.0;

  // ── Moyens de paiement disponibles en Algérie ─────────────────────────────
  //
  // • Carte Dorée  : carte prépayée d'Algérie Poste (CCP / Barid Bank).
  // • CIB          : Carte Interbancaire, réseau national (SATIM).
  // • Virement     : virement bancaire classique (2-3 jours ouvrés).
  //
  // PayPal et Apple Pay sont exclus : non disponibles pour les comptes
  // domiciliés en Algérie.
  static const _methods = [
    (
      title: 'Carte Dorée',
      icon: Icons.credit_card,
      subtitle: 'Barid Bank / Algérie Poste',
    ),
    (
      title: 'CIB',
      icon: Icons.credit_card_outlined,
      subtitle: 'Carte Interbancaire – SATIM',
    ),
    (
      title: 'Virement bancaire',
      icon: Icons.account_balance,
      subtitle: '2-3 jours ouvrés',
    ),
  ];

  /// Clés envoyées au backend pour chaque méthode (dans le même ordre que
  /// [_methods]). Adapter selon le contrat API du serveur.
  static const _methodKeys = [
    'carte_doree',
    'cib',
    'virement',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // BUG A FIX: guard sur _reservationId != null pour éviter de réinitialiser
    // _total à 0.0 si didChangeDependencies est rappelé après le premier chargement.
    if (_reservationId == null) {
      final extra =
          GoRouterState.of(context).extra as Map<String, dynamic>?;
      _reservationId = extra?['reservationId'] as int?;
      _total = (extra?['total'] as num?)?.toDouble() ?? 0.0;
    }
  }

  Future<void> _processPayment() async {
    if (_reservationId == null) {
      _showError('Réservation introuvable. Veuillez recommencer.');
      return;
    }

    setState(() => _isProcessing = true);

    final repo = ref.read(paymentRepositoryProvider);
    final result = await repo.processPayment(
      reservationId: _reservationId!,
      methode: _methodKeys[_selectedMethod],
      token: 'tok_test_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    result.fold(
      (error) => _showError(error.when(
        network: (m) => m,
        unauthorized: () => 'Session expirée. Reconnectez-vous.',
        notFound: (_) => 'Paiement introuvable.',
        serverError: (m) => m,
        validation: (e) =>
            e.values.isNotEmpty ? e.values.first.first : 'Erreur de validation',
        unknown: (_) => 'Une erreur inattendue est survenue.',
      )),
      (_) => context.go(AppRoutes.paymentSuccess),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SecurePaymentBadge(),
            const SizedBox(height: AppSpacing.lg),

            const Text(
              'Mode de paiement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Liste des moyens de paiement ──────────────────────────────
            ..._methods.asMap().entries.map((entry) {
              final index = entry.key;
              final method = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: PaymentMethodCard(
                  title: method.title,
                  icon: method.icon,
                  subtitle: method.subtitle,
                  isSelected: _selectedMethod == index,
                  onTap: () => setState(() => _selectedMethod = index),
                ),
              );
            }),

            const SizedBox(height: AppSpacing.lg),

            // ── Récapitulatif de commande (montants en DA) ────────────────
            OrderSummary(
              subtotal: _total,
              taxes: 0.0,
              total: _total,
              numberOfPersons: 1,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Bouton de paiement (montant en Dinar Algérien) ────────────
            PrimaryButton(
              label: 'Payer ${CurrencyHelper.format(_total)}',
              icon: Icons.lock,
              onPressed: _isProcessing ? null : _processPayment,
              isLoading: _isProcessing,
            ),
            const SizedBox(height: AppSpacing.md),

            const Center(
              child: Text(
                'En confirmant, vous acceptez nos conditions générales',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}