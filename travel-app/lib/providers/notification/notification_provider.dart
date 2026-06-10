import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/data/datasources/remote/notification_remote_datasource.dart';
import 'package:voyageur/data/models/app_notification_model.dart';
import 'package:voyageur/data/repositories/notification_repository.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/auth/auth_state.dart';
import 'package:voyageur/services/app_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers d'infrastructure
// ─────────────────────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    datasource: NotificationRemoteDatasource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Badge (nombre de non-lues)
// ─────────────────────────────────────────────────────────────────────────────

/// Provider du badge (non-lues). Écoute le stream FCM + rafraîchi après
/// chaque action (mark-read, mark-all-read, delete).
final unreadCountProvider = StateProvider<int>((ref) => 0);

/// Rafraîchit le badge depuis l'API et met à jour [unreadCountProvider].
Future<void> refreshUnreadCount(WidgetRef ref) async {
  // Ne pas appeler l'API si non authentifié
  final auth = ref.read(authProvider);
  if (auth is! AuthAuthenticated) return;

  final repo = ref.read(notificationRepositoryProvider);
  final result = await repo.getUnreadCount();
  result.fold(
    (_) {}, // silencieux — badge non critique
    (count) {
      ref.read(unreadCountProvider.notifier).state = count;
      AppNotificationService.instance.updateBadgeCount(count);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Liste des notifications
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsState {
  final List<AppNotificationModel> items;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const NotificationsState({
    this.items      = const [],
    this.isLoading  = false,
    this.hasMore    = true,
    this.currentPage = 1,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotificationModel>? items,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return NotificationsState(
      items:       items       ?? this.items,
      isLoading:   isLoading   ?? this.isLoading,
      hasMore:     hasMore     ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error:       error       ?? this.error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  final Ref _ref;

  NotificationsNotifier(this._repo, this._ref)
      : super(const NotificationsState());

  // ── Chargement ──────────────────────────────────────────────────────────

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!state.hasMore && !refresh) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _repo.getNotifications(page: page);

    result.fold(
      (error) => state = state.copyWith(isLoading: false, error: error.toString()),
      (page0) {
        final newItems = refresh
            ? page0.items
            : [...state.items, ...page0.items];

        state = state.copyWith(
          items:       newItems,
          isLoading:   false,
          hasMore:     page0.hasNextPage,
          currentPage: page0.currentPage + 1,
        );

        // المزامنة وتجاوز التحذير لكون الدالة تحتاج WidgetRef
        refreshUnreadCount(_ref as dynamic);
      },
    );
  }

  Future<void> loadMore() => load(refresh: false);
  Future<void> refresh()  => load(refresh: true);

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> markRead(int id) async {
    final result = await _repo.markRead(id);
    result.fold((_) {}, (_) {
      state = state.copyWith(
        items: state.items.map((n) {
          if (n.id == id) return n.copyWith(isRead: true);
          return n;
        }).toList(),
      );
      _decrementBadge();
    });
  }

  Future<void> markAllRead() async {
    final result = await _repo.markAllRead();
    result.fold((_) {}, (_) {
      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
      );
      _ref.read(unreadCountProvider.notifier).state = 0;
      AppNotificationService.instance.updateBadgeCount(0);
    });
  }

  Future<void> delete(int id) async {
    final wasUnread = state.items
        .firstWhere((n) => n.id == id, orElse: () => _placeholder)
        .isRead ==
        false;

    final result = await _repo.deleteNotification(id);
    result.fold((_) {}, (_) {
      state = state.copyWith(
        items: state.items.where((n) => n.id != id).toList(),
      );
      if (wasUnread) _decrementBadge();
    });
  }

  void _decrementBadge() {
    final current = _ref.read(unreadCountProvider);
    if (current > 0) {
      final next = current - 1;
      _ref.read(unreadCountProvider.notifier).state = next;
      AppNotificationService.instance.updateBadgeCount(next);
    }
  }

  /// Placeholder pour le firstWhere sans résultat (évite le crash).
  static final _placeholder = AppNotificationModel(
    id:        -1,
    userId:    -1,
    type:      '',
    title:     '',
    body:      '',
    createdAt: DateTime(2000),
    readAt:    DateTime(2000), // marqué lu → décrement ignoré
  );
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(
    ref.watch(notificationRepositoryProvider),
    ref,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// FCM token registration
// ─────────────────────────────────────────────────────────────────────────────

/// Provider qui enregistre le token FCM lorsque l'utilisateur est authentifié.
/// À watcher dans le widget racine (app.dart) via ref.listen sur authProvider.
Future<void> registerFcmTokenIfAuthenticated(WidgetRef ref) async {
  final auth = ref.read(authProvider);
  if (auth is! AuthAuthenticated) return;

  final token = await AppNotificationService.instance.getToken();
  if (token == null) return;

  final repo = ref.read(notificationRepositoryProvider);
  await repo.registerFcmToken(
    token:    token,
    platform: AppNotificationService.instance.platform,
  );

  // Écouter les refresh de token
  AppNotificationService.instance.tokenRefreshStream.listen((newToken) async {
    await repo.registerFcmToken(
      token:    newToken,
      platform: AppNotificationService.instance.platform,
    );
  });
}