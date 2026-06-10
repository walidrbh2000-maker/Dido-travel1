/// Domain entity لعملية الدفع.
class PaymentEntity {
  final int id;
  final int reservationId;

  /// 'carte_doree' | 'cib' | 'virement' | 'stripe'
  final String methode;
  final double montant;

  /// 'success' | 'failed' | 'pending'
  final String statut;
  final DateTime? createdAt;

  const PaymentEntity({
    required this.id,
    required this.reservationId,
    required this.methode,
    required this.montant,
    required this.statut,
    this.createdAt,
  });

  bool get isSuccessful => statut == 'success';

  factory PaymentEntity.fromJson(Map<String, dynamic> json) {
    return PaymentEntity(
      id: (json['id'] as num).toInt(),
      reservationId: (json['reservation_id'] as num).toInt(),
      methode: json['methode'] as String? ?? '',
      montant: double.parse((json['montant'] ?? '0').toString()),
      statut: json['statut'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'PaymentEntity(id: $id, reservationId: $reservationId, statut: $statut)';
}
