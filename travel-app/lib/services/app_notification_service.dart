import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Canal Android utilisé pour les notifications Voyageur.
const _androidChannelId   = 'voyageur_main';
const _androidChannelName = 'Voyageur Notifications';
const _androidChannelDesc = 'Réservations, vols et alertes Voyageur';

/// Handler exécuté dans un **isolate séparé** lorsque l'app est en arrière-plan
/// ou terminée. DOIT être une fonction top-level (non membre d'une classe).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase Core est initialisé automatiquement dans l'isolate de background.
  // On affiche simplement la notification locale — pas d'accès à Riverpod ici.
  debugPrint('[FCM Background] title=${message.notification?.title}');
  await AppNotificationService._showLocalNotification(message);
}

/// Service singleton gérant :
/// - l'initialisation de firebase_messaging
/// - l'affichage de notifications locales (foreground)
/// - la redirection à la navigation via [onNotificationTap]
class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FirebaseMessaging          _fcm   = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// Stream pour notifier le provider Riverpod d'une mise à jour du badge.
  final StreamController<int> _badgeController =
      StreamController<int>.broadcast();
  Stream<int> get badgeStream => _badgeController.stream;

  /// Callback appelé quand l'utilisateur tape sur une notification
  /// (foreground ou background). Fournit le payload data de la notification.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  // ─────────────────────────────────────────────────────────────────────────
  // Initialisation
  // ─────────────────────────────────────────────────────────────────────────

  /// À appeler dans main() APRÈS Firebase.initializeApp().
  Future<void> initialize() async {
    // 1. Handler background (isolate séparé)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Canal Android
    await _initLocalNotifications();

    // 3. Permissions iOS / Android 13+
    await _requestPermissions();

    // 4. Message reçu en foreground → afficher une notification locale
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Tap sur notification quand l'app est en background (mais non terminée)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Tap sur notification quand l'app était terminée (cold start)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial);
    }

    // 7. Écouter les refresh de token FCM
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      // Le provider re-enregistrera le token via NotificationRepository
      _tokenRefreshController.add(newToken);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token
  // ─────────────────────────────────────────────────────────────────────────

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  /// Stream émis chaque fois que le token FCM est rafraîchi.
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  /// Retourne le token FCM courant (peut être null si pas de permission).
  Future<String?> getToken() => _fcm.getToken();

  /// Retourne la plateforme courante en string pour l'API.
  String get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'web';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Badge
  // ─────────────────────────────────────────────────────────────────────────

  void updateBadgeCount(int count) {
    _badgeController.add(count);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Privé
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission:  false, // demandé séparément via FCM
      requestBadgePermission:  false,
      requestSoundPermission:  false,
    );

    await _local.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS:     iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // Tap sur notification locale (foreground)
        if (details.payload != null) {
          _dispatchTap(details.payload!);
        }
      },
    );

    // Créer le canal Android (obligatoire Android 8+)
    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description:  _androidChannelDesc,
      importance:   Importance.high,
      playSound:    true,
      enableVibration: true,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // iOS : afficher les alertes même en foreground
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert:         true,
      announcement:  false,
      badge:         true,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
      sound:         true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM Foreground] title=${message.notification?.title}');
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM Tap] data=${message.data}');
    if (onNotificationTap != null && message.data.isNotEmpty) {
      onNotificationTap!(message.data);
    }
  }

  /// Affiche une notification locale à partir d'un [RemoteMessage].
  /// Méthode statique pour pouvoir être appelée depuis le handler background.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final plugin = FlutterLocalNotificationsPlugin();

    // Canal Android déjà créé par initialize() — pas besoin de le recréer.
    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDesc,
      importance:         Importance.high,
      priority:           Priority.high,
      playSound:          true,
      icon:               '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Sérialiser le data payload comme payload string de la notification locale
    // pour pouvoir le récupérer dans onDidReceiveNotificationResponse.
    final payloadEntries = message.data.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    await plugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payloadEntries,
    );
  }

  /// Parse le payload string "key=value&key2=value2" → Map.
  void _dispatchTap(String payload) {
    final data = Map<String, dynamic>.fromEntries(
      payload.split('&').map((kv) {
        final parts = kv.split('=');
        return MapEntry(
          parts.first,
          parts.length > 1 ? parts.sublist(1).join('=') : '',
        );
      }),
    );
    onNotificationTap?.call(data);
  }

  void dispose() {
    _badgeController.close();
    _tokenRefreshController.close();
  }
}
