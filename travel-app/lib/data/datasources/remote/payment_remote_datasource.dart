import 'package:dio/dio.dart';
import 'package:voyageur/core/network/api_client.dart';
import 'package:voyageur/core/network/api_endpoints.dart';

/// Remote datasource للمدفوعات — يتصل بـ PaymentController.php.
class PaymentRemoteDatasource {
  final ApiClient _apiClient;

  PaymentRemoteDatasource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// معالجة الدفع.
  /// [reservationId] — معرّف الحجز
  /// [methode] — 'carte_doree' | 'cib' | 'virement' | 'stripe'
  /// [token] — رمز الدفع الصادر من المزوّد
  Future<Response> processPayment({
    required int reservationId,
    required String methode,
    required String token,
  }) {
    return _apiClient.post(
      ApiEndpoints.payments,
      data: {
        'reservation_id': reservationId,
        'methode': methode,
        'token': token,
      },
    );
  }

  /// جلب تفاصيل عملية دفع محددة.
  Future<Response> getPayment(int paymentId) {
    return _apiClient.get(ApiEndpoints.paymentDetail(paymentId));
  }
}
