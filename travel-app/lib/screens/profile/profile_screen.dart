import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_colors.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/core/theme/theme_provider.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/auth/guest_provider.dart';
import 'package:voyageur/providers/user/user_profile_provider.dart';
import 'package:voyageur/screens/auth/guest_prompt_sheet.dart';
import 'package:voyageur/screens/profile/widgets/language_selector.dart';
import 'package:voyageur/screens/profile/widgets/profile_header.dart';
import 'package:voyageur/screens/profile/widgets/settings_tile.dart';
import 'package:voyageur/shared_widgets/loaders/app_loading_indicator.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);

    if (isGuest) return const _GuestProfileView();

    final userAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => const Center(child: Text('Erreur de chargement')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Non connecté'));
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                ProfileHeader(name: user.name, email: user.email),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      SettingsTile(
                        icon: Icons.person_outline,
                        title: 'Modifier le profil',
                        subtitle: 'Nom, email, téléphone',
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      SettingsTile(
                        icon: Icons.bookmark_outline,
                        title: 'Mes réservations',
                        subtitle: 'Historique et suivi',
                        onTap: () => context.go(AppRoutes.reservations),
                      ),
                      const SettingsTile(
                        icon: Icons.payment_outlined,
                        title: 'Moyens de paiement',
                        subtitle: 'Cartes et portefeuilles',
                      ),
                      const SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        subtitle: 'Alertes et rappels',
                      ),
                      const SettingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Confidentialité',
                        subtitle: 'Données et sécurité',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // ── Apparence & langue ────────────────────────────────
                      _AppearanceCard(),
                      const SizedBox(height: AppSpacing.lg),
                      const LanguageSelector(),
                      const SizedBox(height: AppSpacing.lg),
                      const SettingsTile(
                        icon: Icons.help_outline,
                        title: 'Aide et support',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SettingsTile(
                        icon: Icons.logout,
                        title: 'Déconnexion',
                        iconColor: AppColors.error,
                        onTap: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go(AppRoutes.login);
                        },
                        trailing: const SizedBox.shrink(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Vue invité ─────────────────────────────────────────────────────────────────
//
// Philosophie : l'invité a choisi d'explorer librement.
// On lui donne accès immédiat aux paramètres (langue, thème) pour
// qu'il personnalise son expérience — sans mur de connexion.
// L'invitation à créer un compte existe mais reste discrète.

class _GuestProfileView extends ConsumerWidget {
  const _GuestProfileView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── En-tête compact ───────────────────────────────────────────────
          SliverToBoxAdapter(child: _GuestHeader()),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── 1. Apparence — accessible sans compte ─────────────────
                _SectionLabel(label: 'Apparence'),
                const SizedBox(height: AppSpacing.sm),
                _AppearanceCard(),
                const SizedBox(height: AppSpacing.lg),

                // ── 2. Langue — accessible sans compte ────────────────────
                _SectionLabel(label: 'Langue'),
                const SizedBox(height: AppSpacing.sm),
                const LanguageSelector(),
                const SizedBox(height: AppSpacing.xl),

                // ── 3. CTA login — secondaire, non intrusif ───────────────
                _GuestJoinCard(),
                const SizedBox(height: AppSpacing.lg),

                // ── 4. Aide ───────────────────────────────────────────────
                const SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Aide et support',
                ),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête invité compact ────────────────────────────────────────────────────

class _GuestHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.borderRadiusXl),
          bottomRight: Radius.circular(AppSpacing.borderRadiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.person_outline, size: 28, color: Colors.white),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Texte
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode invité',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
                  ),
                  child: const Text(
                    'Exploration libre',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── CTA invitation — discret ──────────────────────────────────────────────────

class _GuestJoinCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
                child: const Icon(Icons.lock_open_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Text(
                  'Débloquer toutes les fonctionnalités',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Réservez des vols, gérez vos séjours et retrouvez tout votre historique en créant un compte gratuit.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => GuestPromptSheet.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.borderRadiusMd),
                      ),
                    ),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).exitGuestMode();
                      context.go(AppRoutes.register);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.borderRadiusMd),
                      ),
                    ),
                    child: const Text(
                      "S'inscrire",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Carte Apparence (Dark mode toggle) ───────────────────────────────────────

class _AppearanceCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider.notifier).isDark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.mdsm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Mode sombre',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeColor: AppColors.primary,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

// ── Label de section ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
