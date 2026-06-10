import 'package:dartz/dartz.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/repositories/payment_repository.dart';
import 'package:voyageur/domain/entities/payment_entity.dart';

/// Use-case: معالجة الدفع.
class ProcessPaymentUsecase {
  final PaymentRepository _repository;

  ProcessPaymentUsecase({required PaymentRepository repository})
      : _repository = repository;

  Future<Either<AppError, PaymentEntity>> call({
    required int reservationId,
    required String methode,
    required String token,
  }) =>
      _repository.processPayment(
        reservationId: reservationId,
        methode: methode,
        token: token,
      );
}
