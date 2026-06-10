import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyageur/core/constants/app_spacing.dart';
import 'package:voyageur/core/router/app_routes.dart';
import 'package:voyageur/domain/entities/guide_entity.dart';
import 'package:voyageur/providers/guide/guide_provider.dart';
import 'package:voyageur/screens/guides/widgets/guide_card.dart';
import 'package:voyageur/shared_widgets/errors/empty_state_widget.dart';
import 'package:voyageur/shared_widgets/errors/error_widget.dart';
import 'package:voyageur/shared_widgets/shimmer/list_shimmer.dart';

// ── NOTE ────────────────────────────────────────────────────────────────────
// GuidesListNotifier et guidesListProvider ont été déplacés vers
// lib/providers/guide/guide_provider.dart pour respecter la Clean Architecture.
// L'écran consomme maintenant uniquement guidesProvider.
// ────────────────────────────────────────────────────────────────────────────

class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidesAsync = ref.watch(guidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guides locaux'),
        actions: [
          // Bouton de rafraîchissement manuel
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(guidesProvider),
          ),
        ],
      ),
      body: guidesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: ListShimmer(itemCount: 5),
        ),
        error: (e, _) => AppErrorWidget(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(guidesProvider),
        ),
        data: (guides) {
          if (guides.isEmpty) {
            return const EmptyStateWidget(
              message: 'Aucun guide disponible pour le moment',
              icon: Icons.explore_outlined,
            );
          }
          return _GuidesList(guides: guides);
        },
      ),
    );
  }
}

/// Widget interne pour la liste — amélioré avec SliverList pour les performances.
class _GuidesList extends StatelessWidget {
  final List<GuideEntity> guides;

  const _GuidesList({required this.guides});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: guides.length,
      // Pas de séparateur excessif — GuideCard gère son propre espacement
      itemBuilder: (context, index) {
        final guide = guides[index];
        return GuideCard(
          id: guide.id,
          nom: guide.nom,
          langues: guide.langues,
          experienceAnnees: guide.experienceAnnees,
          tarifJour: guide.tarifJour,
          image: guide.image,
          // push() → retour vers la liste (comportement identique à l'original)
          onTap: () => context.push(
            AppRoutes.guideDetailPath(guide.id),
          ),
        );
      },
    );
  }
}
