import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/datasources/remote/guide_remote_datasource.dart';
import 'package:voyageur/data/repositories/guide_repository.dart';
import 'package:voyageur/domain/entities/guide_entity.dart';
import 'package:voyageur/domain/usecases/guide/get_guide_detail_usecase.dart';
import 'package:voyageur/domain/usecases/guide/get_guides_usecase.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';

// ── Infrastructure providers ───────────────────────────────────────────────

final guideRepositoryProvider = Provider<GuideRepository>((ref) {
  return GuideRepository(
    remoteDatasource: GuideRemoteDatasource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});

final getGuidesUseCaseProvider = Provider<GetGuidesUsecase>((ref) {
  return GetGuidesUsecase(
    repository: ref.watch(guideRepositoryProvider),
  );
});

final getGuideDetailUseCaseProvider = Provider<GetGuideDetailUsecase>((ref) {
  return GetGuideDetailUsecase(
    repository: ref.watch(guideRepositoryProvider),
  );
});

// ── Global list provider (GuidesScreen) ───────────────────────────────────

/// Fetches all available guides without destination filtering.
/// Used by the [GuidesScreen] catalog view.
final guidesProvider =
    AsyncNotifierProvider<GuidesNotifier, List<GuideEntity>>(
  GuidesNotifier.new,
);

class GuidesNotifier extends AsyncNotifier<List<GuideEntity>> {
  @override
  Future<List<GuideEntity>> build() async {
    final usecase = ref.watch(getGuidesUseCaseProvider);
    final result = await usecase();
    return result.fold(
      (l) => throw Exception(_messageFromError(l)),
      (r) => r,
    );
  }

  /// Re-fetch with optional filters (e.g. language search on the catalog).
  ///
  /// Do NOT use this for destination-scoped lookups — use
  /// [guidesByDestinationProvider] instead to avoid polluting the global state.
  Future<void> search({Map<String, dynamic>? filters}) async {
    state = const AsyncLoading();
    final usecase = ref.read(getGuidesUseCaseProvider);
    final result = await usecase(filters: filters);
    result.fold(
      (l) => state = AsyncError(
        Exception(_messageFromError(l)),
        StackTrace.current,
      ),
      (r) => state = AsyncData(r),
    );
  }

  /// Converts an [AppError] into a human-readable message.
  /// Exposed as a static helper so it can be reused by family providers below.
  static String _messageFromError(AppError error) => error.when(
        network: (m) => m,
        unauthorized: () => 'Non autorisé',
        notFound: (r) => 'Ressource introuvable : $r',
        serverError: (m) => m,
        validation: (e) => e.values.isNotEmpty
            ? e.values.first.first
            : 'Erreur de validation',
        unknown: (e) => e.toString(),
      );
}

// ── Destination-scoped list provider (BookingAddExtrasScreen) ─────────────

/// Fetches guides filtered by [destinationId] — server-side.
///
/// Using [autoDispose] ensures the provider is cleaned up as soon as the
/// bottom sheet (or any other widget watching it) is removed from the tree,
/// keeping memory usage minimal across booking flows.
///
/// Usage:
/// ```dart
/// final guidesAsync = ref.watch(guidesByDestinationProvider(destinationId));
/// ```
final guidesByDestinationProvider =
    FutureProvider.autoDispose.family<List<GuideEntity>, int>(
  (ref, destinationId) async {
    final usecase = ref.watch(getGuidesUseCaseProvider);
    final result = await usecase(
      filters: {'destination_id': destinationId},
    );
    return result.fold(
      (l) => throw Exception(GuidesNotifier._messageFromError(l)),
      (r) => r,
    );
  },
);

// ── Detail provider ────────────────────────────────────────────────────────

/// Fetches a single guide's detail by [id].
///
/// Defined here (not in the screen) so that it follows the Clean Architecture
/// dependency direction: screen → provider → use-case → repository.
final guideDetailProvider =
    FutureProvider.autoDispose.family<GuideEntity, int>((ref, id) async {
  final usecase = ref.watch(getGuideDetailUseCaseProvider);
  final result = await usecase(id);
  return result.fold(
    (l) => throw Exception(GuidesNotifier._messageFromError(l)),
    (r) => r,
  );
});
