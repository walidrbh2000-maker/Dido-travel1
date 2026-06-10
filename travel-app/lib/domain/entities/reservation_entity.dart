import 'package:voyageur/data/models/reservation_model.dart';

/// Domain entity — يحتوي على منطق الأعمال الخاص بالحجز.
/// لا يعتمد على أي مكتبات خارجية (freezed / json_serializable).
class ReservationEntity {
  final int id;
  final int userId;
  final int volId;
  final int? hotelId;
  final int? guideId;

  /// 'aller_simple' | 'aller_retour'
  final String typeTrajet;
  final int? volRetourId;

  final DateTime dateDebut;
  final DateTime dateFin;
  final int nombrePersonnes;
  final double prixTotal;

  /// 'en_attente' | 'confirmee' | 'payee' | 'annulee'
  final String statut;
  final String reference;
  final DateTime? createdAt;

  const ReservationEntity({
    required this.id,
    required this.userId,
    required this.volId,
    this.hotelId,
    this.guideId,
    this.typeTrajet = 'aller_simple',
    this.volRetourId,
    required this.dateDebut,
    required this.dateFin,
    required this.nombrePersonnes,
    required this.prixTotal,
    required this.statut,
    required this.reference,
    this.createdAt,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  /// الحجز غير ملغى.
  bool get isActive => statut != 'annulee';

  /// الحجز مدفوع أو مؤكد بعد الدفع.
  bool get isPaid => statut == 'payee' || statut == 'confirmee';

  /// رحلة ذهاب وإياب.
  bool get isRoundTrip => typeTrajet == 'aller_retour';

  /// الحجز في انتظار الدفع.
  bool get isPending => statut == 'en_attente';

  /// الحجز ملغى.
  bool get isCancelled => statut == 'annulee';

  /// هل يشمل الحجز فندقاً؟
  bool get hasHotel => hotelId != null;

  /// التسمية المقروءة للحالة (بالفرنسية — متوافق مع بقية الكود).
  String get statutLabel {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'confirmee':
        return 'Confirmée';
      case 'payee':
        return 'Payée';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }

  // ── Factory: تحويل من Model إلى Entity ───────────────────────────────────

  factory ReservationEntity.fromModel(ReservationModel model) {
    return ReservationEntity(
      id: model.id,
      userId: model.userId,
      volId: model.volId,
      hotelId: model.hotelId,
      guideId: model.guideId,
      typeTrajet: model.typeTrajet,
      volRetourId: model.volRetourId,
      // تحويل النصوص إلى DateTime — اللازم للـ ticket_widget
      dateDebut: DateTime.parse(model.dateDebut),
      dateFin: DateTime.parse(model.dateFin),
      nombrePersonnes: model.nombrePersonnes,
      prixTotal: model.prixTotal,
      statut: model.statut,
      reference: model.reference,
      createdAt:
          model.createdAt != null ? DateTime.tryParse(model.createdAt!) : null,
    );
  }

  // ── copyWith: ضروري للتحديث التفاؤلي في الـ Provider ────────────────────

  ReservationEntity copyWith({
    int? id,
    int? userId,
    int? volId,
    int? hotelId,
    int? guideId,
    String? typeTrajet,
    int? volRetourId,
    DateTime? dateDebut,
    DateTime? dateFin,
    int? nombrePersonnes,
    double? prixTotal,
    String? statut,
    String? reference,
    DateTime? createdAt,
  }) {
    return ReservationEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      volId: volId ?? this.volId,
      hotelId: hotelId ?? this.hotelId,
      guideId: guideId ?? this.guideId,
      typeTrajet: typeTrajet ?? this.typeTrajet,
      volRetourId: volRetourId ?? this.volRetourId,
      dateDebut: dateDebut ?? this.dateDebut,
      dateFin: dateFin ?? this.dateFin,
      nombrePersonnes: nombrePersonnes ?? this.nombrePersonnes,
      prixTotal: prixTotal ?? this.prixTotal,
      statut: statut ?? this.statut,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReservationEntity &&
          other.id == id &&
          other.statut == statut);

  @override
  int get hashCode => Object.hash(id, statut);

  @override
  String toString() =>
      'ReservationEntity(id: $id, ref: $reference, statut: $statut, '
      'typeTrajet: $typeTrajet)';
}
