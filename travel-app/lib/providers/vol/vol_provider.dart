import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/datasources/remote/vol_remote_datasource.dart';
import 'package:voyageur/data/repositories/vol_repository.dart';
import 'package:voyageur/domain/entities/vol_entity.dart';
import 'package:voyageur/domain/usecases/vol/search_vols_usecase.dart';
import 'package:voyageur/domain/usecases/vol/get_vol_details_usecase.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';

final volRepositoryProvider = Provider<VolRepository>((ref) {
  return VolRepository(
    remoteDatasource: VolRemoteDatasource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});

final searchVolsUseCaseProvider = Provider<SearchVolsUsecase>((ref) {
  return SearchVolsUsecase(repository: ref.watch(volRepositoryProvider));
});

final getVolDetailsUseCaseProvider = Provider<GetVolDetailsUsecase>((ref) {
  return GetVolDetailsUsecase(repository: ref.watch(volRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// VolsNotifier — avec auto-refresh toutes les 30 secondes
// ─────────────────────────────────────────────────────────────────────────────

class VolsNotifier extends AsyncNotifier<List<VolEntity>> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _lastFilters;

  @override
  Future<List<VolEntity>> build() async {
    // Annuler le timer précédent si le provider est reconstruit
    ref.onDispose(() => _refreshTimer?.cancel());

    // Lancer le premier fetch
    final result = await ref.watch(searchVolsUseCaseProvider)();
    final vols = result.fold(
      (l) => throw Exception(_messageFromError(l)),
      (r) => r,
    );

    // Démarrer l'auto-refresh toutes les 30 secondes
    _startAutoRefresh();

    return vols;
  }

  // ── API publique ─────────────────────────────────────────────────────────

  Future<void> search({Map<String, dynamic>? filters}) async {
    _lastFilters = filters;
    state = const AsyncLoading();
    final usecase = ref.read(searchVolsUseCaseProvider);
    final result  = await usecase(filters: filters);
    result.fold(
      (l) => state = AsyncError(
          Exception(_messageFromError(l)), StackTrace.current),
      (r) => state = AsyncData(r),
    );
  }

  /// Rafraîchit silencieusement (sans passer par AsyncLoading) pour éviter
  /// le flash de chargement lors des mises à jour périodiques.
  Future<void> silentRefresh() async {
    final usecase = ref.read(searchVolsUseCaseProvider);
    final result  = await usecase(filters: _lastFilters);
    result.fold(
      (_) {}, // Ignorer les erreurs réseau en arrière-plan
      (r) => state = AsyncData(r),
    );
  }

  // ── Auto-refresh ─────────────────────────────────────────────────────────

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => silentRefresh(),
    );
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void restartAutoRefresh() {
    _startAutoRefresh();
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  static String _messageFromError(AppError error) => error.when(
        network:     (m) => m,
        unauthorized: () => 'Non autorisé',
        notFound:    (r) => 'Ressource introuvable : $r',
        serverError: (m) => m,
        validation:  (e) =>
            e.values.isNotEmpty ? e.values.first.first : 'Erreur de validation',
        unknown:     (e) => e.toString(),
      );
}

final volsProvider =
    AsyncNotifierProvider<VolsNotifier, List<VolEntity>>(VolsNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Détail d'un vol — avec auto-refresh toutes les 30 secondes
// ─────────────────────────────────────────────────────────────────────────────

/// Provider de détail avec auto-invalidation toutes les 30 s pour maintenir
/// [places_disponibles] à jour pendant que l'utilisateur consulte la page.
final volDetailProvider =
    FutureProvider.family<VolEntity, int>((ref, id) async {
  // Auto-refresh : invalider ce provider toutes les 30 s
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  final usecase = ref.watch(getVolDetailsUseCaseProvider);
  final result  = await usecase(id);
  return result.fold(
    (l) => throw Exception(VolsNotifier._messageFromError(l)),
    (r) => r,
  );
});
