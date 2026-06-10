// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guide_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GuideModelImpl _$$GuideModelImplFromJson(Map<String, dynamic> json) =>
    _$GuideModelImpl(
      id: (json['id'] as num).toInt(),
      nom: json['nom'] as String,
      destinationId: (json['destination_id'] as num).toInt(),
      langues: (json['langues'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      experienceAnnees: (json['experience_annees'] as num?)?.toInt() ?? 0,
      // FIX: Laravel decimal:2 → String JSON. double.parse() gère les deux.
      tarifJour: double.parse((json['tarif_jour'] ?? '0').toString()),
      description: json['description'] as String?,
      image: json['image'] as String?,
      disponible: json['disponible'] as bool? ?? true,
    );

Map<String, dynamic> _$$GuideModelImplToJson(_$GuideModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'destination_id': instance.destinationId,
      'langues': instance.langues,
      'experience_annees': instance.experienceAnnees,
      'tarif_jour': instance.tarifJour,
      'description': instance.description,
      'image': instance.image,
      'disponible': instance.disponible,
    };