import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_constants.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/storage/secure_storage.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/screens/splash/widgets/animated_logo.dart';

/// Splash purement décorativ — aucun choix utilisateur ici.
/// L'unique responsabilité : vérifier le token et rediriger.
///
/// Entrées "mode invité" disponibles sur :
///   • OnboardingScreen (dernière page)
///   • LoginScreen (lien en bas)
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(
      Duration(seconds: AppConstants.splashDurationSeconds),
    );
    if (!mounted) return;

    final secureStorage = SecureStorage();
    final hasToken = await secureStorage.hasToken();
    final hasSeenOnboarding = await secureStorage.hasSeenOnboarding();

    if (!mounted) return;

    if (hasToken) {
      ref.read(authProvider.notifier).checkAuth();
      context.go(AppRoutes.home);
    } else if (!hasSeenOnboarding) {
      context.go(AppRoutes.onboarding);
    } else {
      // Retour utilisateur sans session → écran de connexion.
      // Le LoginScreen propose déjà "Continuer en mode invité".
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A5F), Color(0xFF2E5A8F)],
          ),
        ),
        child: Center(child: AnimatedLogo()),
      ),
    );
  }
}
