import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/utils/helpers/currency_helper.dart';
import 'package:voyageur/providers/booking/booking_provider.dart';
import 'package:voyageur/providers/reservation/reservation_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';
import 'package:voyageur/shared_widgets/buttons/secondary_button.dart';

class BookingSummaryScreen extends ConsumerStatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  DateTime _dateDebut = DateTime.now().add(const Duration(days: 1));
  DateTime _dateFin = DateTime.now().add(const Duration(days: 8));
  bool _isLoading = false;

  // BUG C FIX: stocker l'id et le total de la réservation créée pour éviter
  // de recréer une double réservation si l'utilisateur revient après un échec
  // de paiement.
  int? _createdReservationId;
  double? _createdTotal;

  // ── Sélecteur de date ──────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? _dateDebut : _dateFin;
    final firstDate = isStart ? now : _dateDebut.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(firstDate) ? initial : firstDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _dateDebut = picked;
        // Garantit que dateFin > dateDebut
        if (!_dateFin.isAfter(_dateDebut)) {
          _dateFin = _dateDebut.add(const Duration(days: 7));
        }
      } else {
        _dateFin = picked;
      }
    });
  }

  // ── Création de la réservation ─────────────────────────────────────────────

  Future<void> _book() async {
    final booking = ref.read(bookingProvider);
    if (booking == null) return;

    if (!_dateFin.isAfter(_dateDebut)) {
      _showError('La date de fin doit être après la date de début.');
      return;
    }

    setState(() => _isLoading = true);

    final payload = booking.toApiPayload(_dateDebut, _dateFin);

    final result =
        await ref.read(createReservationUseCaseProvider)(payload);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      (error) => _showError(error.when(
        network: (m) => m,
        unauthorized: () => 'Session expirée. Reconnectez-vous.',
        notFound: (r) => 'Ressource introuvable : $r',
        serverError: (m) => m,
        validation: (e) =>
            e.values.isNotEmpty ? e.values.first.first : 'Erreur de validation',
        unknown: (_) => 'Une erreur inattendue est survenue.',
      )),
      (reservation) {
        // BUG C FIX: stocker la réservation créée en état local pour pouvoir
        // "reprendre le paiement" si l'utilisateur revient après un échec,
        // sans recréer une nouvelle réservation.
        setState(() {
          _createdReservationId = reservation.id;
          _createdTotal = reservation.prixTotal;
        });

        // BUG C FIX: NE PAS appeler reset() ici. Le bookingProvider doit rester
        // actif jusqu'à confirmation du paiement (depuis PaymentSuccessScreen)
        // ou annulation explicite par l'utilisateur.
        // L'ancienne ligne `ref.read(bookingProvider.notifier).reset();` est
        // supprimée intentionnellement.

        ref.invalidate(reservationsProvider);

        context.push(AppRoutes.payment, extra: {
          'reservationId': reservation.id,
          'total': reservation.prixTotal,
        });
      },
    );
  }

  // BUG C FIX: reprendre le paiement d'une réservation déjà créée, sans
  // recréer de réservation (évite la duplication).
  void _resumePayment() {
    if (_createdReservationId == null || _createdTotal == null) return;
    context.push(AppRoutes.payment, extra: {
      'reservationId': _createdReservationId!,
      'total': _createdTotal!,
    });
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

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);

    // BUG C FIX: si bookingProvider est null mais qu'une réservation a déjà été
    // créée dans cette session, afficher le bouton "Reprendre le paiement" au
    // lieu du message d'erreur. Cela couvre le cas où l'utilisateur revient
    // après un échec de paiement.
    if (booking == null) {
      if (_createdReservationId != null && _createdTotal != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Récapitulatif')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payment, size: 64, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Votre réservation a été créée.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Total : ${CurrencyHelper.format(_createdTotal!)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // BUG C FIX: bouton "Reprendre le paiement" pour retourner
                  // vers PaymentScreen avec les données existantes.
                  PrimaryButton(
                    label: 'Reprendre le paiement',
                    icon: Icons.payment,
                    onPressed: _resumePayment,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return const Scaffold(
        body: Center(child: Text('Erreur: réservation non initialisée')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Récapitulatif')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Vol aller ──────────────────────────────────────────────────
            _SectionCard(
              title: booking.isRoundTrip ? '✈ Vol Aller' : '✈ Vol',
              children: [
                _InfoRow('Compagnie', booking.outboundFlight.compagnie),
                _InfoRow('N° vol', booking.outboundFlight.numeroVol),
                if (booking.outboundFlight.destinationName != null)
                  _InfoRow('Destination',
                      booking.outboundFlight.destinationName!),
                _InfoRow('Classe', booking.outboundFlight.classeLabel),
                _InfoRow('Prix / pax',
                    CurrencyHelper.format(booking.outboundFlight.prix)),
              ],
            ),

            // ── Vol retour ─────────────────────────────────────────────────
            if (booking.isRoundTrip && booking.returnFlight != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionCard(
                title: '✈ Vol Retour',
                children: [
                  _InfoRow('Compagnie', booking.returnFlight!.compagnie),
                  _InfoRow('N° vol', booking.returnFlight!.numeroVol),
                  _InfoRow('Classe', booking.returnFlight!.classeLabel),
                  _InfoRow('Prix / pax',
                      CurrencyHelper.format(booking.returnFlight!.prix)),
                ],
              ),
            ],

            // ── Dates ──────────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: '📅 Dates',
              children: [
                _DateRow(
                  label: 'Date de départ',
                  value: _dateDebut,
                  onTap: () => _pickDate(true),
                ),
                _DateRow(
                  label: 'Date de retour',
                  value: _dateFin,
                  onTap: () => _pickDate(false),
                ),
              ],
            ),

            // ── Passagers ──────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: '👥 Passagers (${booking.totalPassengers})',
              children: booking.passengers
                  .map((p) => _InfoRow(p.typeLabel, p.displayName))
                  .toList(),
            ),

            // ── Hôtel ──────────────────────────────────────────────────────
            if (booking.selectedHotel != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionCard(
                title: '🏨 Hôtel',
                children: [
                  _InfoRow('Nom', booking.selectedHotel!.nom),
                  _InfoRow('Étoiles',
                      '${'★' * booking.selectedHotel!.etoiles}'),
                  _InfoRow('Prix / nuit',
                      CurrencyHelper.format(booking.selectedHotel!.prixNuit)),
                ],
              ),
            ],

            // ── Guide ──────────────────────────────────────────────────────
            if (booking.selectedGuide != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionCard(
                title: '🧭 Guide',
                children: [
                  _InfoRow('Nom', booking.selectedGuide!.nom),
                  _InfoRow('Tarif / jour',
                      CurrencyHelper.format(booking.selectedGuide!.tarifJour)),
                ],
              ),
            ],

            // ── Prix total ─────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusLg),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total estimé',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        CurrencyHelper.format(booking.estimatedTotal),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${booking.totalPassengers} passager(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        booking.tripTypeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Avertissement ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusMd),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.secondary),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Les sièges sélectionnés sont réservés pour 10 minutes. '
                      'Confirmez rapidement.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // BUG C FIX: si une réservation est déjà créée (retour après échec
            // paiement), afficher "Reprendre le paiement" plutôt que de recréer.
            if (_createdReservationId != null) ...[
              PrimaryButton(
                label: 'Reprendre le paiement',
                icon: Icons.payment,
                isLoading: false,
                onPressed: _resumePayment,
              ),
            ] else ...[
              PrimaryButton(
                label: 'Confirmer la réservation',
                icon: Icons.check_circle,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _book,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: 'Annuler',
              onPressed: _isLoading
                  ? null
                  : () {
                      // BUG C FIX: reset() appelé ici car l'utilisateur annule
                      // EXPLICITEMENT, c'est le seul endroit légitime avec
                      // PaymentSuccessScreen.
                      ref.read(bookingProvider.notifier).reset();
                      context.go(AppRoutes.vols);
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Sous-composants privés ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.edit_calendar_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}