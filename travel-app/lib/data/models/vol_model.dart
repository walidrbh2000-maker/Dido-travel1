import 'package:freezed_annotation/freezed_annotation.dart';

part 'vol_model.freezed.dart';
part 'vol_model.g.dart';

@freezed
class VolModel with _$VolModel {
  const factory VolModel({
    required int id,
    required String compagnie,
    required String numeroVol,
    // BUG 6 FIX: explicit JSON key so it always maps to the top-level field
    @JsonKey(name: 'destination_id') required int destinationId,
    DestinationInfo? destination,
    // ✅ ville_depart — champ ajouté par migration ; nullable pour compatibilité
    // ascendante avec d'éventuelles réponses sans ce champ.
    @JsonKey(name: 'ville_depart') String? villeDepart,
    required String dateDepart,
    required String dateArrivee,
    required double prix,
    required int placesDisponibles,
    @Default('economique') String classe,
    @Default('programme') String statut,
  }) = _VolModel;

  factory VolModel.fromJson(Map<String, dynamic> json) =>
      _$VolModelFromJson(json);
}

@freezed
class DestinationInfo with _$DestinationInfo {
  const factory DestinationInfo({
    required int id,
    required String name,
    required String country,
  }) = _DestinationInfo;

  factory DestinationInfo.fromJson(Map<String, dynamic> json) =>
      _$DestinationInfoFromJson(json);
}
