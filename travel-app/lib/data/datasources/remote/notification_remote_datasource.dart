import 'package:dio/dio.dart';
import 'package:voyageur/core/network/api_client.dart';

/// Datasource pour les endpoints de notifications Laravel.
class NotificationRemoteDatasource {
  final ApiClient _apiClient;

  NotificationRemoteDatasource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// POST /notifications/token
  Future<Response> registerFcmToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    return _apiClient.post(
      '/notifications/token',
      data: {
        'token':     token,
        'platform':  platform,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  /// DELETE /notifications/token
  Future<Response> removeFcmToken(String token) async {
    return _apiClient.delete(
      '/notifications/token',
      data: {'token': token},
    );
  }

  /// GET /notifications?page=&per_page=
  Future<Response> getNotifications({int page = 1, int perPage = 20}) async {
    return _apiClient.get(
      '/notifications',
      queryParameters: {'page': page, 'per_page': perPage},
    );
  }

  /// GET /notifications/unread-count
  Future<Response> getUnreadCount() async {
    return _apiClient.get('/notifications/unread-count');
  }

  /// PATCH /notifications/{id}/read
  Future<Response> markRead(int notificationId) async {
    return _apiClient.patch('/notifications/$notificationId/read');
  }

  /// POST /notifications/read-all
  Future<Response> markAllRead() async {
    return _apiClient.post('/notifications/read-all');
  }

  /// DELETE /notifications/{id}
  Future<Response> deleteNotification(int notificationId) async {
    return _apiClient.delete('/notifications/$notificationId');
  }
}