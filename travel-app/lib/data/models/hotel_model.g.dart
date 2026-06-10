// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'hotel_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$HotelModelImpl _$$HotelModelImplFromJson(Map<String, dynamic> json) =>
    _$HotelModelImpl(
      id: (json['id'] as num).toInt(),
      nom: json['nom'] as String,
      destinationId: (json['destination_id'] as num).toInt(),
      destination: json['destination'] == null
          ? null
          : DestinationInfo.fromJson(
              json['destination'] as Map<String, dynamic>),
      etoiles: (json['etoiles'] as num?)?.toInt() ?? 3,
      // FIX: Laravel decimal:2 → String JSON. double.parse() gère les deux.
      prixNuit: double.parse((json['prix_nuit'] ?? '0').toString()),
      adresse: json['adresse'] as String,
      description: json['description'] as String?,
      image: json['image'] as String?,
      disponible: json['disponible'] as bool? ?? true,
    );

Map<String, dynamic> _$$HotelModelImplToJson(_$HotelModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'destination_id': instance.destinationId,
      'destination': instance.destination,
      'etoiles': instance.etoiles,
      'prix_nuit': instance.prixNuit,
      'adresse': instance.adresse,
      'description': instance.description,
      'image': instance.image,
      'disponible': instance.disponible,
    };