import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/notification/notification_provider.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState   = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    final userName = authState.when(
      initial:         () => '',
      loading:         () => '',
      authenticated:   (user) => user.name,
      unauthenticated: () => '',
      guest:           () => '',
      error:           (_) => '',
    );
    final isGuest = authState.maybeWhen(
      guest: () => true,
      orElse: () => false,
    );
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    final String initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'V';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Avatar à gauche ──────────────────────────────────────────────
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: isGuest
              ? const Icon(
                  Icons.person_outline,
                  size: 22,
                  color: AppColors.primary,
                )
              : Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
        ),

        const SizedBox(width: 12),

        // ── Texte de salutation ──────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGuest ? 'Bienvenue,' : 'Bon retour,',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                isGuest
                    ? 'Mode invité !'
                    : (userName.isNotEmpty ? '$userName !' : 'Voyageur !'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),

        // ── Cloche notifications à droite ────────────────────────────────
        if (isAuthenticated)
          _NotificationBell(
            unreadCount: unreadCount,
            onTap: () => context.push(AppRoutes.notifications),
          ),
      ],
    );
  }
}

// ── Widget cloche avec badge animé ────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.textPrimary,
              size: 26,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
