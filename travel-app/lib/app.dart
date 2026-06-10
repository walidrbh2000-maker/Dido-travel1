import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:voyageur/core/localization/app_localizations.dart';
import 'package:voyageur/core/localization/locale_provider.dart';
import 'package:voyageur/core/router/app_router.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/theme/app_theme.dart';
import 'package:voyageur/core/theme/theme_provider.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/auth/auth_state.dart';
import 'package:voyageur/providers/notification/notification_provider.dart';
import 'package:voyageur/services/app_notification_service.dart';

class VoyageurApp extends ConsumerStatefulWidget {
  const VoyageurApp({super.key});

  @override
  ConsumerState<VoyageurApp> createState() => _VoyageurAppState();
}

class _VoyageurAppState extends ConsumerState<VoyageurApp> {
  @override
  void initState() {
    super.initState();

    // Enregistrer le callback de tap sur notification → navigation
    AppNotificationService.instance.onNotificationTap = _handleNotificationTap;

    // Écouter le stream du badge pour mettre à jour le provider
    AppNotificationService.instance.badgeStream.listen((count) {
      if (mounted) {
        ref.read(unreadCountProvider.notifier).state = count;
      }
    });
  }

  /// Route vers le bon écran selon le type de notification.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final router = ref.read(routerProvider);
    final type   = data['type'] as String?;

    switch (type) {
      case 'reservation_confirmed':
      case 'reservation_cancelled':
      case 'reservation_created':
        final reservationId = int.tryParse(data['reservation_id'] ?? '');
        if (reservationId != null) {
          router.push(AppRoutes.reservationDetailPath(reservationId));
        }
        break;

      case 'flight_status':
        final volId = int.tryParse(data['vol_id'] ?? '');
        if (volId != null) {
          router.push(AppRoutes.volDetailPath(volId));
        }
        break;

      case 'seat_lock_expiring':
        final volId = int.tryParse(data['vol_id'] ?? '');
        if (volId != null) {
          router.push(AppRoutes.volDetailPath(volId));
        }
        break;

      default:
        // Ouvrir l'écran notifications comme fallback
        router.push(AppRoutes.notifications);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router    = ref.watch(routerProvider);
    final locale    = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Enregistrer le token FCM dès que l'utilisateur est authentifié
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        registerFcmTokenIfAuthenticated(ref);
        refreshUnreadCount(ref);
      }
    });

    return MaterialApp.router(
      title: 'Voyageur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: AppLocalizations.localeResolution,
      routerConfig: router,
    );
  }
}
