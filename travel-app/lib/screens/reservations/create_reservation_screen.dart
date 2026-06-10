import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/providers/booking/booking_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';
import 'package:voyageur/shared_widgets/loaders/app_loading_indicator.dart';

/// BUG 2 FIX — Ce screen envoyait auparavant {date_debut, date_fin,
/// nombre_personnes} sans vol_id ni passengers, ce qui provoquait une
/// réponse 422 systématique du backend.
///
/// Solution : le flow complet de réservation passe par BookingSummaryScreen
/// qui construit le payload correct via BookingState.toApiPayload().
/// Ce screen agit désormais comme un aiguilleur :
///   • Booking actif   → redirection immédiate vers BookingSummaryScreen.
///   • Pas de booking  → page informative invitant l'utilisateur à
///                       sélectionner un vol en premier.
class CreateReservationScreen extends ConsumerWidget {
  const CreateReservationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);

    // ── Booking en cours → redirection vers le récapitulatif ───────────────
    if (booking != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace(AppRoutes.bookingSummary);
      });
      return const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      );
    }

    // ── Aucun booking → écran informatif ───────────────────────────────────
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle réservation')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Illustration ─────────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Titre ─────────────────────────────────────────────────────
              const Text(
                'Sélectionnez un vol en premier',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Description ───────────────────────────────────────────────
              const Text(
                'Pour créer une réservation, commencez par choisir un vol '
                'depuis la page de recherche. Vous pourrez ensuite ajouter '
                'un hôtel, un guide et sélectionner vos sièges.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── CTA ───────────────────────────────────────────────────────
              PrimaryButton(
                label: 'Rechercher un vol',
                icon: Icons.search_rounded,
                onPressed: () => context.go(AppRoutes.vols),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
