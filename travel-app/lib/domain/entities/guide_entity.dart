import 'package:voyageur/data/models/guide_model.dart';

/// Domain entity للمرشد السياحي — بدون أي تبعيات خارجية.
class GuideEntity {
  final int id;
  final String nom;
  final int destinationId;
  final List<String> langues;
  final int experienceAnnees;
  final double tarifJour;
  final String? description;
  final String? image;
  final bool disponible;

  const GuideEntity({
    required this.id,
    required this.nom,
    required this.destinationId,
    required this.langues,
    this.experienceAnnees = 0,
    required this.tarifJour,
    this.description,
    this.image,
    this.disponible = true,
  });

  // ── Factory ───────────────────────────────────────────────────────────────

  factory GuideEntity.fromModel(GuideModel model) {
    return GuideEntity(
      id: model.id,
      nom: model.nom,
      destinationId: model.destinationId,
      langues: List<String>.from(model.langues),
      experienceAnnees: model.experienceAnnees,
      tarifJour: model.tarifJour,
      description: model.description,
      image: model.image,
      disponible: model.disponible,
    );
  }

  // ── Computed getters ──────────────────────────────────────────────────────

  /// عرض الخبرة بشكل مقروء.
  String get experienceLabel {
    if (experienceAnnees == 0) return 'Débutant';
    if (experienceAnnees == 1) return '1 an d\'expérience';
    return '$experienceAnnees ans d\'expérience';
  }

  /// قائمة اللغات كنص.
  String get languesLabel => langues.join(' • ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuideEntity && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'GuideEntity(id: $id, nom: $nom, tarif: $tarifJour)';
}
