import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/utils/helpers/currency_helper.dart';
import 'package:voyageur/providers/vol/vol_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';
import 'package:voyageur/shared_widgets/loaders/app_loading_indicator.dart';
import 'package:voyageur/shared_widgets/misc/guest_barrier.dart';

/// Seuil en dessous duquel le dot de disponibilité "faible" s'affiche.
const _seatsLowThreshold = 10;

class VolDetailScreen extends ConsumerWidget {
  final int volId;

  const VolDetailScreen({super.key, required this.volId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // volDetailProvider s'auto-invalide toutes les 30 s (cf. vol_provider.dart)
    final volAsync = ref.watch(volDetailProvider(volId));

    return volAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: AppLoadingIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erreur: $e')),
      ),
      data: (vol) => Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── En-tête dégradé ───────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xxxl,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            vol.dateDepart
                                .toLocal()
                                .toString()
                                .substring(11, 16),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(Icons.flight,
                              color: Colors.white70, size: 32),
                          Text(
                            vol.dateArrivee
                                .toLocal()
                                .toString()
                                .substring(11, 16),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ✅ Ville de départ (ex. "Alger")
                          Text(
                            vol.villeDepart ?? 'Alger',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                          // ✅ Destination (ex. "Paris")
                          Text(
                            vol.destinationName ?? 'Arrivée',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Corps ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                        icon: Icons.airlines,
                        label: 'Compagnie',
                        value: vol.compagnie),
                    _DetailRow(
                        icon: Icons.confirmation_number,
                        label: 'N° de vol',
                        value: vol.numeroVol),
                    // ✅ Ville de départ
                    _DetailRow(
                        icon: Icons.flight_takeoff,
                        label: 'Départ de',
                        value: vol.villeDepart ?? 'Alger'),
                    _DetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value:
                          '${vol.dateDepart.day.toString().padLeft(2, '0')}/'
                          '${vol.dateDepart.month.toString().padLeft(2, '0')}/'
                          '${vol.dateDepart.year}',
                    ),
                    _DetailRow(
                        icon: Icons.airline_seat_recline_normal,
                        label: 'Classe',
                        value: vol.classeLabel),

                    // ── Disponibilité en temps réel ────────────────────────
                    _AvailabilityRow(places: vol.placesDisponibles),

                    const SizedBox(height: AppSpacing.xl),

                    // Prix
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Prix par personne',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            CurrencyHelper.format(vol.prix),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Booking button — blocked for guests ────────────────
                    GuestBarrier(
                      reason: 'pour réserver ce vol',
                      child: PrimaryButton(
                        label: vol.placesDisponibles > 0
                            ? 'Réserver maintenant'
                            : 'Complet',
                        icon: vol.placesDisponibles > 0
                            ? Icons.bookmark_add
                            : Icons.block,
                        onPressed: vol.placesDisponibles > 0
                            ? () => context.push(
                                  AppRoutes.bookingTripType,
                                  extra: vol,
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicateur de disponibilité en temps réel ─────────────────────────────────

/// Affiche le nombre de places disponibles avec :
///   - dot orange clignotant si [places] < [_seatsLowThreshold] (urgence)
///   - dot vert fixe + texte vert si places suffisantes
///   - texte rouge "Complet" si places == 0
class _AvailabilityRow extends StatefulWidget {
  final int places;

  const _AvailabilityRow({required this.places});

  @override
  State<_AvailabilityRow> createState() => _AvailabilityRowState();
}

class _AvailabilityRowState extends State<_AvailabilityRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.places > 0 && widget.places < _seatsLowThreshold) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AvailabilityRow old) {
    super.didUpdateWidget(old);
    final isLow = widget.places > 0 && widget.places < _seatsLowThreshold;
    if (isLow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!isLow && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.places;
    final isLow  = places > 0 && places < _seatsLowThreshold;
    final isEmpty = places == 0;

    final dotColor = isEmpty
        ? AppColors.error
        : isLow
            ? Colors.orange
            : AppColors.success;

    final textColor = isEmpty
        ? AppColors.error
        : isLow
            ? Colors.orange.shade800
            : AppColors.success;

    final label = isEmpty
        ? 'Complet'
        : isLow
            ? 'Plus que $places place${places > 1 ? 's' : ''} !'
            : '$places places disponibles';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.people, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          const Text(
            'Disponibilité',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),

          // Dot animé
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor
                    .withOpacity(isLow ? 0.4 + _pulse.value * 0.6 : 1.0),
                shape: BoxShape.circle,
                boxShadow: isLow
                    ? [
                        BoxShadow(
                          color: dotColor
                              .withOpacity(0.35 * _pulse.value),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Texte
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── DetailRow ─────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
