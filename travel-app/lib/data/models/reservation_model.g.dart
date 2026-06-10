// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reservation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReservationModelImpl _$$ReservationModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ReservationModelImpl(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      volId: (json['vol_id'] as num).toInt(),
      hotelId: (json['hotel_id'] as num?)?.toInt(),
      guideId: (json['guide_id'] as num?)?.toInt(),
      typeTrajet: json['type_trajet'] as String? ?? 'aller_simple',
      volRetourId: (json['vol_retour_id'] as num?)?.toInt(),
      dateDebut: json['date_debut'] as String,
      dateFin: json['date_fin'] as String,
      nombrePersonnes: (json['nombre_personnes'] as num).toInt(),
      // FIX: Laravel decimal:2 → String JSON. double.parse() gère les deux.
      prixTotal: double.parse((json['prix_total'] ?? '0').toString()),
      statut: json['statut'] as String,
      reference: json['reference'] as String,
      createdAt: json['created_at'] as String?,
      vol: json['vol'] == null
          ? null
          : VolModel.fromJson(json['vol'] as Map<String, dynamic>),
      hotel: json['hotel'] == null
          ? null
          : ReservationHotelInfo.fromJson(
              json['hotel'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ReservationModelImplToJson(
        _$ReservationModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'vol_id': instance.volId,
      'hotel_id': instance.hotelId,
      'guide_id': instance.guideId,
      'type_trajet': instance.typeTrajet,
      'vol_retour_id': instance.volRetourId,
      'date_debut': instance.dateDebut,
      'date_fin': instance.dateFin,
      'nombre_personnes': instance.nombrePersonnes,
      'prix_total': instance.prixTotal,
      'statut': instance.statut,
      'reference': instance.reference,
      'created_at': instance.createdAt,
      'vol': instance.vol?.toJson(),
      'hotel': instance.hotel?.toJson(),
    };

_$ReservationHotelInfoImpl _$$ReservationHotelInfoImplFromJson(
        Map<String, dynamic> json) =>
    _$ReservationHotelInfoImpl(
      id: (json['id'] as num).toInt(),
      nom: json['nom'] as String,
      etoiles: (json['etoiles'] as num?)?.toInt() ?? 3,
      image: json['image'] as String?,
    );

Map<String, dynamic> _$$ReservationHotelInfoImplToJson(
        _$ReservationHotelInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nom': instance.nom,
      'etoiles': instance.etoiles,
      'image': instance.image,
    };
