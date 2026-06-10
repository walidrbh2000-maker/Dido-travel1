// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentModelImpl _$$PaymentModelImplFromJson(Map<String, dynamic> json) =>
    _$PaymentModelImpl(
      id: (json['id'] as num).toInt(),
      reservationId: (json['reservation_id'] as num).toInt(),
      // FIX: Laravel decimal:2 → String JSON. double.parse() gère les deux.
      montant: double.parse((json['montant'] ?? '0').toString()),
      methode: json['methode'] as String,
      stripePaymentId: json['stripe_payment_id'] as String?,
      statut: json['statut'] as String? ?? 'pending',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$$PaymentModelImplToJson(_$PaymentModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reservation_id': instance.reservationId,
      'montant': instance.montant,
      'methode': instance.methode,
      'stripe_payment_id': instance.stripePaymentId,
      'statut': instance.statut,
      'created_at': instance.createdAt,
    };