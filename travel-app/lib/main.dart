import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/app.dart';
import 'package:voyageur/services/app_notification_service.dart';

/// Le handler background DOIT être enregistré avant Firebase.initializeApp()
/// et DOIT être une fonction top-level annotée @pragma('vm:entry-point').
/// Il est défini dans app_notification_service.dart.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialiser Firebase
  await Firebase.initializeApp();

  // 2. Déclarer le handler background FCM (isolate séparé)
  //    Doit être fait le plus tôt possible, avant tout autre listener.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Initialiser le service de notifications (canaux Android, permissions…)
  await AppNotificationService.instance.initialize();

  runApp(const ProviderScope(child: VoyageurApp()));
}
