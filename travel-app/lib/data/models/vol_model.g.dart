// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vol_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VolModelImpl _$$VolModelImplFromJson(Map<String, dynamic> json) =>
    _$VolModelImpl(
      id: (json['id'] as num).toInt(),
      compagnie: json['compagnie'] as String,
      numeroVol: json['numero_vol'] as String,
      // FIX: destination_id peut venir soit de destination.id soit directement.
      destinationId: json['destination'] != null
          ? ((json['destination'] as Map<String, dynamic>)['id'] as num?)
                  ?.toInt() ??
              0
          : (json['destination_id'] as num?)?.toInt() ?? 0,
      destination: json['destination'] == null
          ? null
          : DestinationInfo.fromJson(
              json['destination'] as Map<String, dynamic>),
      // ✅ ville_depart — nullable ; null si champ absent (anciens enregistrements)
      villeDepart: json['ville_depart'] as String?,
      dateDepart: json['date_depart'] as String,
      dateArrivee: json['date_arrivee'] as String,
      // FIX: Laravel decimal:2 cast sérialise en String ("4500.00").
      // double.parse() accepte String ET num via .toString().
      prix: double.parse((json['prix'] ?? '0').toString()),
      placesDisponibles: (json['places_disponibles'] as num).toInt(),
      classe: json['classe'] as String? ?? 'economique',
      statut: json['statut'] as String? ?? 'programme',
    );

Map<String, dynamic> _$$VolModelImplToJson(_$VolModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'compagnie': instance.compagnie,
      'numero_vol': instance.numeroVol,
      'destination_id': instance.destinationId,
      'destination': instance.destination,
      // ✅ ville_depart sérialisé avec sa clé snake_case
      'ville_depart': instance.villeDepart,
      'date_depart': instance.dateDepart,
      'date_arrivee': instance.dateArrivee,
      'prix': instance.prix,
      'places_disponibles': instance.placesDisponibles,
      'classe': instance.classe,
      'statut': instance.statut,
    };

_$DestinationInfoImpl _$$DestinationInfoImplFromJson(
        Map<String, dynamic> json) =>
    _$DestinationInfoImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      country: json['country'] as String,
    );

Map<String, dynamic> _$$DestinationInfoImplToJson(
        _$DestinationInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'country': instance.country,
    };
