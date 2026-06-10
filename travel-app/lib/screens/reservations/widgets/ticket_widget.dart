import 'package:flutter/material.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/utils/helpers/currency_helper.dart';
import 'package:voyageur/domain/entities/reservation_entity.dart';

class TicketWidget extends StatelessWidget {
  final ReservationEntity reservation;

  const TicketWidget({super.key, required this.reservation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête ───────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.borderRadiusXl),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VOYAGEUR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    // ── Badge type de trajet ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusMd,
                        ),
                      ),
                      child: Text(
                        reservation.isRoundTrip
                            ? 'Aller-Retour'
                            : 'Aller Simple',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Réf: ${reservation.reference}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // ── Corps du ticket ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                // Date de départ — toujours affichée
                _TicketRow(
                  label: 'Date de départ',
                  value: _fmt(reservation.dateDebut),
                ),

                // ── FIX Issue 1 ──────────────────────────────────────────
                // Date de retour → uniquement pour les vols aller-retour.
                // Pour un aller simple avec hôtel, on affiche "Fin de séjour".
                // Pour un aller simple sans hôtel, on n'affiche rien.
                if (reservation.isRoundTrip)
                  _TicketRow(
                    label: 'Date de retour',
                    value: _fmt(reservation.dateFin),
                  )
                else if (reservation.hasHotel)
                  _TicketRow(
                    label: 'Fin de séjour',
                    value: _fmt(reservation.dateFin),
                  ),
                // ── Fin FIX ──────────────────────────────────────────────

                _TicketRow(
                  label: 'Passagers',
                  value: reservation.nombrePersonnes == 1
                      ? '1 passager'
                      : '${reservation.nombrePersonnes} passagers',
                ),
                _TicketRow(
                  label: 'Total',
                  value: CurrencyHelper.format(reservation.prixTotal),
                  isBold: true,
                ),
              ],
            ),
          ),

          // ── Séparateur perforé ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: List.generate(
                20,
                (i) => Expanded(
                  child: Container(
                    height: 1,
                    color: i.isEven
                        ? AppColors.shimmerBase
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          // ── Pied du ticket ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statut',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      reservation.statutLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _statutColor(reservation.statut),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMd,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_2,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'payee':
        return AppColors.success;
      case 'confirmee':
        return AppColors.accent;
      case 'annulee':
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }
}

class _TicketRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TicketRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
