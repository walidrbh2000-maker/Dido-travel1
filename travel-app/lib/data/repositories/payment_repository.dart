import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/datasources/remote/payment_remote_datasource.dart';
import 'package:voyageur/domain/entities/payment_entity.dart';

/// Repository للمدفوعات — معالجة الأخطاء + تحويل البيانات.
class PaymentRepository {
  final PaymentRemoteDatasource _remoteDatasource;

  PaymentRepository({required PaymentRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  Future<Either<AppError, PaymentEntity>> processPayment({
    required int reservationId,
    required String methode,
    required String token,
  }) async {
    try {
      final response = await _remoteDatasource.processPayment(
        reservationId: reservationId,
        methode: methode,
        token: token,
      );
      final data = response.data;
      // يدعم { payment: {...} } أو كائن مباشر
      final paymentJson = (data is Map && data.containsKey('payment'))
          ? data['payment'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return Right(PaymentEntity.fromJson(paymentJson));
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } catch (e, st) {
      // ignore: avoid_print
      print('[PaymentRepository.processPayment] Unexpected error: $e\n$st');
      return Left(AppError.unknown(e));
    }
  }

  AppError _handleDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    switch (statusCode) {
      case 401:
      case 403:
        return const AppError.unauthorized();
      case 404:
        return const AppError.notFound('Paiement');
      case 422:
        final rawErrors = responseData is Map
            ? responseData['errors'] as Map<String, dynamic>?
            : null;
        final errors = rawErrors?.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        );
        return AppError.validation(errors ?? {});
      default:
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          return AppError.network(
            e.message ?? 'Pas de connexion Internet',
          );
        }
        final message = responseData is Map
            ? (responseData['message'] as String? ??
                'Erreur lors du paiement')
            : 'Erreur lors du paiement ($statusCode)';
        return AppError.serverError(message);
    }
  }
}
