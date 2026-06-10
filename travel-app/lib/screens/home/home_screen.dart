import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/auth/auth_state.dart';
import 'package:voyageur/providers/destination/destination_provider.dart';
import 'package:voyageur/providers/notification/notification_provider.dart';
import 'package:voyageur/providers/vol/vol_provider.dart';
import 'package:voyageur/screens/home/widgets/greeting_header.dart';
import 'package:voyageur/screens/home/widgets/search_bar_home.dart';
import 'package:voyageur/screens/home/widgets/featured_destinations.dart';
import 'package:voyageur/screens/home/widgets/popular_vols.dart';
import 'package:voyageur/screens/home/widgets/promo_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinationsAsync = ref.watch(destinationsProvider);
    final volsAsync         = ref.watch(volsProvider);
    final authState         = ref.watch(authProvider);
    final isAuthenticated   = authState is AuthAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── Pas d'AppBar : la cloche est intégrée dans GreetingHeader ─────
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(destinationsProvider);
            ref.invalidate(volsProvider);
            if (isAuthenticated) {
              await refreshUnreadCount(ref);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header : avatar | salutation | cloche
                const GreetingHeader(),
                const SizedBox(height: AppSpacing.lg),
                const SearchBarHome(),
                const SizedBox(height: AppSpacing.xl),
                destinationsAsync.when(
                  loading: () => const FeaturedDestinations(
                    destinations: [],
                    isLoading: true,
                  ),
                  error: (_, __) => const FeaturedDestinations(
                    destinations: [],
                  ),
                  data: (destinations) => FeaturedDestinations(
                    destinations: destinations,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const PromoBanner(),
                const SizedBox(height: AppSpacing.xl),
                volsAsync.when(
                  loading: () => const PopularVols(vols: [], isLoading: true),
                  error: (_, __) => const PopularVols(vols: []),
                  data: (vols) => PopularVols(vols: vols),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
