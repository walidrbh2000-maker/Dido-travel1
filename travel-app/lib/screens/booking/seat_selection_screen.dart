import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/data/datasources/remote/seat_remote_datasource.dart';
import 'package:voyageur/data/models/passenger_input.dart';
import 'package:voyageur/data/models/seat_model.dart';
import 'package:voyageur/data/repositories/seat_repository.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/booking/booking_provider.dart';
import 'package:voyageur/shared_widgets/buttons/primary_button.dart';
import 'package:voyageur/shared_widgets/loaders/app_loading_indicator.dart';

// Providers locaux pour la sélection de sièges
final _seatRepoProvider = Provider.autoDispose<SeatRepository>((ref) {
  return SeatRepository(
    datasource: SeatRemoteDatasource(apiClient: ref.watch(apiClientProvider)),
  );
});

final _seatMapProvider =
    FutureProvider.autoDispose.family<SeatMapResponse, int>((ref, volId) async {
  final repo   = ref.watch(_seatRepoProvider);
  final result = await repo.getSeatMap(volId);
  return result.fold((e) => throw Exception(e), (r) => r);
});

class SeatSelectionScreen extends ConsumerStatefulWidget {
  /// false = aller, true = retour
  final bool isReturn;

  const SeatSelectionScreen({super.key, this.isReturn = false});

  @override
  ConsumerState<SeatSelectionScreen> createState() =>
      _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  /// passengerId → SeatModel sélectionné
  final Map<String, SeatModel> _selections = {};
  int _currentPassengerIndex = 0;

  /// Timer de polling toutes les 30 secondes pour détecter les sièges
  /// réservés par d'autres utilisateurs depuis la dernière mise à jour.
  Timer? _pollTimer;

  // BUG 11 FIX: store vol ID and repo reference so dispose() can unlock seats
  // without using ref (which is unsafe after widget is unmounted).
  int? _volId;
  SeatRepository? _seatRepo;
  bool _initialized = false;

  /// Timestamp de la dernière mise à jour visible (pour l'indicateur).
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    // Le timer est démarré après le premier build (on connaît le volId)
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _unlockAllOnDispose();
    super.dispose();
  }

  void _startPolling(int volId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(_seatMapProvider(volId));
        setState(() => _lastRefresh = DateTime.now());
      }
    });
  }

  /// Fire-and-forget: unlock all seats that this screen has locked.
  void _unlockAllOnDispose() {
    if (_volId == null || _seatRepo == null || _selections.isEmpty) return;
    for (final seat in _selections.values) {
      _seatRepo!.unlockSeat(_volId!, seat.id); // intentionally unawaited
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    if (booking == null) {
      return const Scaffold(
          body: Center(child: Text('Erreur: réservation non initialisée')));
    }

    final vol = widget.isReturn ? booking.returnFlight : booking.outboundFlight;
    if (vol == null) {
      return const Scaffold(body: Center(child: Text('Vol introuvable')));
    }

    // BUG 11 FIX: capture vol ID and repo reference on first build
    if (!_initialized) {
      _volId    = vol.id;
      _seatRepo = ref.read(_seatRepoProvider);
      _initialized = true;
      // Démarrer le polling maintenant qu'on connaît le volId
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startPolling(vol.id);
      });
    }

    final nonBebePassengers =
        booking.passengers.where((p) => p.needsSeat).toList();

    if (nonBebePassengers.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _proceed(context, booking);
      });
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    final currentPassenger = nonBebePassengers[_currentPassengerIndex];
    final seatMapAsync     = ref.watch(_seatMapProvider(vol.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isReturn ? 'Sièges - Vol Retour' : 'Sièges - Vol Aller',
        ),
        actions: [
          // Indicateur de fraîcheur des données
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _LiveIndicator(lastRefresh: _lastRefresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de passager
          _PassengerSelector(
            passengers: nonBebePassengers,
            currentIndex: _currentPassengerIndex,
            selections: _selections,
            onSelect: (index) =>
                setState(() => _currentPassengerIndex = index),
          ),

          // Légende
          const _SeatLegend(),

          // Plan de la cabine
          Expanded(
            child: seatMapAsync.when(
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (seatMap) => _SeatMap(
                seatMap: seatMap,
                currentPassenger: currentPassenger,
                selections: _selections,
                classeVol: vol.classe,
                onSeatTap: (seat) => _onSeatTap(
                  seat,
                  currentPassenger,
                  vol.id,
                  nonBebePassengers,
                ),
              ),
            ),
          ),

          // Bouton continuer
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _SelectedSeatsBar(
                  passengers: nonBebePassengers,
                  selections: _selections,
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: _getContinueLabel(booking),
                  icon: Icons.arrow_forward,
                  onPressed: _allSeatsSelected(nonBebePassengers)
                      ? () => _proceed(context, booking)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSeatTap(
    SeatModel seat,
    PassengerInput currentPassenger,
    int volId,
    List<PassengerInput> passengers,
  ) async {
    if (!seat.isDisponible) return;

    // Désélectionner si déjà pris par ce passager
    if (_selections[currentPassenger.id]?.id == seat.id) {
      final repo = ref.read(_seatRepoProvider);
      await repo.unlockSeat(volId, seat.id);
      setState(() => _selections.remove(currentPassenger.id));
      _updateBooking(currentPassenger, null);
      return;
    }

    // Vérifier que le siège n'est pas pris par un autre passager
    if (_selections.values.any((s) => s.id == seat.id)) return;

    // Libérer l'ancien siège si existant
    final oldSeat = _selections[currentPassenger.id];
    if (oldSeat != null) {
      await ref.read(_seatRepoProvider).unlockSeat(volId, oldSeat.id);
    }

    // Bloquer le nouveau siège (protection race condition)
    final repo   = ref.read(_seatRepoProvider);
    final result = await repo.lockSeat(volId, seat.id);

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Ce siège vient d\'être pris. Veuillez en choisir un autre.'),
            backgroundColor: AppColors.error,
          ),
        );
        // Rafraîchir la carte immédiatement
        ref.invalidate(_seatMapProvider(volId));
      },
      (lockedSeat) {
        setState(() {
          _selections[currentPassenger.id] = seat;
          final nextIndex = _findNextUnselectedIndex(
            passengers,
            _currentPassengerIndex,
          );
          if (nextIndex != null) _currentPassengerIndex = nextIndex;
        });
        _updateBooking(currentPassenger, seat.id);
      },
    );
  }

  void _updateBooking(PassengerInput passenger, int? seatId) {
    final notifier = ref.read(bookingProvider.notifier);
    if (widget.isReturn) {
      if (seatId != null) {
        notifier.selectReturnSeat(passenger.id, seatId);
      }
    } else {
      if (seatId != null) {
        notifier.selectOutboundSeat(passenger.id, seatId);
      } else {
        notifier.clearOutboundSeat(passenger.id);
      }
    }
  }

  bool _allSeatsSelected(List<PassengerInput> passengers) {
    return passengers.every((p) => _selections.containsKey(p.id));
  }

  int? _findNextUnselectedIndex(
      List<PassengerInput> passengers, int current) {
    for (int i = current + 1; i < passengers.length; i++) {
      if (!_selections.containsKey(passengers[i].id)) return i;
    }
    for (int i = 0; i < current; i++) {
      if (!_selections.containsKey(passengers[i].id)) return i;
    }
    return null;
  }

  String _getContinueLabel(booking) {
    if (!widget.isReturn && booking.isRoundTrip) return 'Sièges retour';
    return 'Continuer';
  }

  void _proceed(BuildContext context, booking) {
    if (!widget.isReturn && booking.isRoundTrip) {
      context.push(AppRoutes.bookingSeatReturn);
    } else {
      context.push(AppRoutes.bookingExtras);
    }
  }
}

// ── Indicateur live ───────────────────────────────────────────────────────────

/// Petit indicateur "En direct" avec un dot vert pulsant.
class _LiveIndicator extends StatefulWidget {
  final DateTime? lastRefresh;

  const _LiveIndicator({this.lastRefresh});

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success
                  .withOpacity(0.4 + _controller.value * 0.6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success
                      .withOpacity(0.3 * _controller.value),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'En direct',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Carte des sièges ──────────────────────────────────────────────────────────

class _SeatMap extends StatelessWidget {
  final SeatMapResponse seatMap;
  final PassengerInput currentPassenger;
  final Map<String, SeatModel> selections;
  final void Function(SeatModel) onSeatTap;
  final String classeVol;

  const _SeatMap({
    required this.seatMap,
    required this.currentPassenger,
    required this.selections,
    required this.onSeatTap,
    required this.classeVol,
  });

  @override
  Widget build(BuildContext context) {
    const classeLabels = {
      'premiere':   'Première Classe',
      'affaires':   'Classe Affaires',
      'economique': 'Classe Économique',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        for (final entry in classeLabels.entries) ...[
          if (entry.key == classeVol &&
              seatMap.sieges.containsKey(entry.key)) ...[
            _ClasseHeader(label: entry.value, classe: entry.key),
            _ClasseSection(
              rangees: seatMap.sieges[entry.key]!,
              classe: entry.key,
              currentPassenger: currentPassenger,
              selections: selections,
              onSeatTap: onSeatTap,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _ClasseHeader extends StatelessWidget {
  final String label;
  final String classe;

  const _ClasseHeader({required this.label, required this.classe});

  Color get color => switch (classe) {
        'premiere' => const Color(0xFFFFD700),
        'affaires' => const Color(0xFF1E88E5),
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ClasseSection extends StatelessWidget {
  final Map<int, List<SeatModel>> rangees;
  final String classe;
  final PassengerInput currentPassenger;
  final Map<String, SeatModel> selections;
  final void Function(SeatModel) onSeatTap;

  const _ClasseSection({
    required this.rangees,
    required this.classe,
    required this.currentPassenger,
    required this.selections,
    required this.onSeatTap,
  });

  List<String> get colonnesGauche => switch (classe) {
        'premiere' => ['A', 'B'],
        'affaires' => ['A', 'B'],
        _ => ['A', 'B', 'C'],
      };

  List<String> get colonnesDroite => switch (classe) {
        'premiere' => [],
        'affaires' => ['C', 'D'],
        _ => ['D', 'E', 'F'],
      };

  @override
  Widget build(BuildContext context) {
    final sortedRangees = rangees.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: [
        _ColumnHeaders(gauche: colonnesGauche, droite: colonnesDroite),
        const SizedBox(height: 4),
        for (final entry in sortedRangees)
          _SeatRow(
            rangee: entry.key,
            seats: entry.value,
            gauche: colonnesGauche,
            droite: colonnesDroite,
            currentPax: currentPassenger,
            selections: selections,
            onTap: onSeatTap,
          ),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  final List<String> gauche;
  final List<String> droite;

  const _ColumnHeaders({required this.gauche, required this.droite});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 32),
        ...gauche.map((c) => _buildCol(c)),
        const SizedBox(width: 24),
        ...droite.map((c) => _buildCol(c)),
      ],
    );
  }

  Widget _buildCol(String col) => Expanded(
        child: Center(
          child: Text(
            col,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
}

class _SeatRow extends StatelessWidget {
  final int rangee;
  final List<SeatModel> seats;
  final List<String> gauche;
  final List<String> droite;
  final PassengerInput currentPax;
  final Map<String, SeatModel> selections;
  final void Function(SeatModel) onTap;

  const _SeatRow({
    required this.rangee,
    required this.seats,
    required this.gauche,
    required this.droite,
    required this.currentPax,
    required this.selections,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final seatByCol = {for (final s in seats) s.colonne: s};

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rangee',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          ...gauche.map((col) {
            final seat = seatByCol[col];
            if (seat == null) return const Expanded(child: SizedBox());
            return Expanded(
                child: _Seat(
              seat: seat,
              currentPax: currentPax,
              selections: selections,
              onTap: () => onTap(seat),
            ));
          }),
          const SizedBox(width: 24),
          ...droite.map((col) {
            final seat = seatByCol[col];
            if (seat == null) return const Expanded(child: SizedBox());
            return Expanded(
                child: _Seat(
              seat: seat,
              currentPax: currentPax,
              selections: selections,
              onTap: () => onTap(seat),
            ));
          }),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  final SeatModel seat;
  final PassengerInput currentPax;
  final Map<String, SeatModel> selections;
  final VoidCallback onTap;

  const _Seat({
    required this.seat,
    required this.currentPax,
    required this.selections,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelectedByCurrentPax = selections[currentPax.id]?.id == seat.id;
    final isSelectedByOtherPax   = selections.entries
        .any((e) => e.key != currentPax.id && e.value.id == seat.id);

    Color bgColor;
    Color textColor = Colors.white;

    if (seat.isReserve) {
      bgColor   = const Color(0xFFE0E0E0);
      textColor = AppColors.textSecondary;
    } else if (seat.isBloque) {
      bgColor   = const Color(0xFFFFCC80);
      textColor = Colors.orange.shade900;
    } else if (isSelectedByCurrentPax) {
      bgColor = AppColors.primary;
    } else if (isSelectedByOtherPax) {
      bgColor = AppColors.accent;
    } else {
      bgColor = AppColors.success;
    }

    return GestureDetector(
      onTap: (seat.isDisponible || isSelectedByCurrentPax) ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                seat.colonne,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  const _SeatLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _LegendItem(color: AppColors.success,         label: 'Libre'),
          _LegendItem(color: AppColors.primary,         label: 'Votre choix'),
          _LegendItem(color: AppColors.accent,          label: 'Autre pax'),
          _LegendItem(color: Color(0xFFFFCC80),         label: 'En cours'),
          _LegendItem(color: Color(0xFFE0E0E0),         label: 'Pris'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PassengerSelector extends StatelessWidget {
  final List<PassengerInput> passengers;
  final int currentIndex;
  final Map<String, SeatModel> selections;
  final ValueChanged<int> onSelect;

  const _PassengerSelector({
    required this.passengers,
    required this.currentIndex,
    required this.selections,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: passengers.length,
        itemBuilder: (context, i) {
          final p        = passengers[i];
          final selected = i == currentIndex;
          final done     = selections.containsKey(p.id);

          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : done
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.background,
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusFull),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : done
                          ? AppColors.success
                          : AppColors.shimmerBase,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done)
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: selected ? Colors.white : AppColors.success,
                    ),
                  if (done) const SizedBox(width: 4),
                  Text(
                    p.prenom ?? p.typeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedSeatsBar extends StatelessWidget {
  final List<PassengerInput> passengers;
  final Map<String, SeatModel> selections;

  const _SelectedSeatsBar(
      {required this.passengers, required this.selections});

  @override
  Widget build(BuildContext context) {
    final selected = selections.length;
    final total    = passengers.length;

    return Row(
      children: [
        const Icon(Icons.event_seat, color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$selected / $total siège${selected > 1 ? 's' : ''} '
          'sélectionné${selected > 1 ? 's' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (selected < total)
          Text(
            '${total - selected} restant${total - selected > 1 ? 's' : ''}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
      ],
    );
  }
}
