import 'package:flutter_riverpod/flutter_riverpod.dart';

class VolSearchParams {
  final int? destinationId;       // ✅ ID numérique — compris par le backend
  final String? destinationName;  // Affiché dans le champ UI uniquement
  final String? villeDepart;      // ✅ Ville de départ — transmise au backend
  final DateTime? dateDepart;
  final int? passagers;
  final String? classe;
  final double? prixMax;

  const VolSearchParams({
    this.destinationId,
    this.destinationName,
    this.villeDepart,
    this.dateDepart,
    this.passagers,
    this.classe,
    this.prixMax,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    // ✅ Utilise destination_id (int) comme le backend l'attend
    if (destinationId != null) params['destination_id'] = destinationId;

    // ✅ Ville de départ — filtrée côté backend si présente
    if (villeDepart != null && villeDepart!.trim().isNotEmpty) {
      params['ville_depart'] = villeDepart!.trim();
    }

    if (dateDepart != null) {
      params['date_depart'] =
          '${dateDepart!.year}-${dateDepart!.month.toString().padLeft(2, '0')}-${dateDepart!.day.toString().padLeft(2, '0')}';
    }
    if (passagers != null) params['passagers'] = passagers;
    if (classe != null) params['classe'] = classe;
    if (prixMax != null) params['prix_max'] = prixMax;
    return params;
  }
}

final volSearchProvider =
    StateProvider<VolSearchParams>((ref) => const VolSearchParams());
