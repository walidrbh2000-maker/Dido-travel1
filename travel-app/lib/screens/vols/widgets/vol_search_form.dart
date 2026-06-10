import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/providers/destination/destination_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';

// ── Modèle local ──────────────────────────────────────────────────────────────

class _DestItem {
  final int id;
  final String name;
  final String country;

  const _DestItem({
    required this.id,
    required this.name,
    required this.country,
  });
}

// ── Villes d'aéroports algériens connus ───────────────────────────────────────

const _kDepartCities = [
  'Alger',
  'Oran',
  'Constantine',
  'Annaba',
  'Tlemcen',
  'Béjaïa',
  'Sétif',
  'Ghardaïa',
  'Tamanrasset',
  'Biskra',
  'Batna',
  'Tébessa',
  'Ouargla',
  'In Aménas',
  'Illizi',
  'Adrar',
  'Tindouf',
  'El Oued',
];

// ── Widget principal ──────────────────────────────────────────────────────────

class VolSearchForm extends ConsumerStatefulWidget {
  final void Function({
    int? destinationId,
    String? destinationName,
    String? villeDepart,
    DateTime? dateDepart,
    int? passagers,
  })? onSearch;

  const VolSearchForm({super.key, this.onSearch});

  @override
  ConsumerState<VolSearchForm> createState() => _VolSearchFormState();
}

class _VolSearchFormState extends ConsumerState<VolSearchForm> {
  // Référence au controller de départ géré par Autocomplete
  TextEditingController? _departAutoCtrl;

  // Vide par défaut → pas de filtre ville_depart si l'utilisateur ne saisit rien
  String _villeDepart = '';
  int? _selectedDestinationId;
  String? _selectedDestinationName;
  DateTime? _departureDate;
  int _passengers = 1;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _departureDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _departureDate = date);
  }

  void _submit() {
    // Lire la valeur libre saisie si l'utilisateur n'a pas sélectionné de suggestion
    final depart =
        (_departAutoCtrl?.text.trim().isNotEmpty == true)
            ? _departAutoCtrl!.text.trim()
            : _villeDepart;

    widget.onSearch?.call(
      destinationId: _selectedDestinationId,
      destinationName: _selectedDestinationName,
      villeDepart: depart.isNotEmpty ? depart : null,
      dateDepart: _departureDate,
      passagers: _passengers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationsAsync = ref.watch(destinationsProvider);

    return Column(
      children: [
        // ── Carte De / Vers ──────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Champ "De" ─────────────────────────────────────────────────
              _RouteField(
                icon: Icons.flight_takeoff,
                iconColor: AppColors.primary,
                label: 'De',
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final q = textEditingValue.text.toLowerCase();
                    // Montre toutes les suggestions seulement si l'utilisateur tape
                    if (q.isEmpty) return const Iterable<String>.empty();
                    return _kDepartCities.where(
                      (c) => c.toLowerCase().contains(q),
                    );
                  },
                  onSelected: (city) {
                    setState(() => _villeDepart = city);
                  },
                  fieldViewBuilder: (ctx, ctrl, focusNode, _) {
                    _departAutoCtrl = ctrl;
                    return TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Alger (toutes villes)',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.borderRadiusMd),
                      color: AppColors.surface,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 220,
                          maxWidth: 280,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusMd),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final city = options.elementAt(i);
                              return InkWell(
                                onTap: () => onSelected(city),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_city,
                                        size: 15,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        city,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Séparateur ────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(left: 54),
                child: Divider(height: 1, thickness: 1),
              ),

              // ── Champ "Vers" ───────────────────────────────────────────────
              _RouteField(
                icon: Icons.flight_land,
                iconColor: AppColors.accent,
                label: 'Vers',
                child: destinationsAsync.when(
                  loading: () => const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text(
                    'Erreur de chargement des destinations',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                  data: (destinations) {
                    final items = destinations
                        .map(
                          (d) => _DestItem(
                            id: d.id,
                            name: d.name,
                            country: d.country,
                          ),
                        )
                        .toList();

                    return Autocomplete<_DestItem>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return items.take(25);
                        }
                        final q = textEditingValue.text.toLowerCase();
                        return items.where(
                          (d) =>
                              d.name.toLowerCase().contains(q) ||
                              d.country.toLowerCase().contains(q),
                        );
                      },
                      displayStringForOption: (d) => d.name,
                      onSelected: (d) {
                        setState(() {
                          _selectedDestinationId = d.id;
                          _selectedDestinationName = d.name;
                        });
                      },
                      fieldViewBuilder: (ctx, ctrl, focusNode, _) => TextField(
                        controller: ctrl,
                        focusNode: focusNode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ville ou pays de destination',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      optionsViewBuilder: (ctx, onSelected, options) => Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusMd),
                          color: AppColors.surface,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 260,
                              maxWidth: 300,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.borderRadiusMd),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (_, i) {
                                  final d = options.elementAt(i);
                                  return InkWell(
                                    onTap: () => onSelected(d),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.place,
                                            size: 15,
                                            color: AppColors.accent,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  d.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  d.country,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Date de départ ──────────────────────────────────────────────────
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date de départ',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _departureDate != null
                          ? '${_departureDate!.day.toString().padLeft(2, '0')}/${_departureDate!.month.toString().padLeft(2, '0')}/${_departureDate!.year}'
                          : 'Sélectionner une date',
                      style: TextStyle(
                        fontSize: 14,
                        color: _departureDate != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (_departureDate != null)
                  GestureDetector(
                    onTap: () => setState(() => _departureDate = null),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Passagers ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.people,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Passagers',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  if (_passengers > 1) setState(() => _passengers--);
                },
                icon: const Icon(Icons.remove_circle_outline,
                    color: AppColors.primary),
              ),
              Text(
                '$_passengers',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: () {
                  if (_passengers < 10) setState(() => _passengers++);
                },
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        PrimaryButton(
          label: 'Rechercher',
          icon: Icons.search,
          onPressed: _submit,
        ),
      ],
    );
  }
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

/// Ligne de route (De / Vers) avec icône + label + contenu dynamique.
class _RouteField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  const _RouteField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
