import 'package:dartz/dartz.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/core/error/error_handler.dart';
import 'package:voyageur/data/datasources/remote/notification_remote_datasource.dart';
import 'package:voyageur/data/models/app_notification_model.dart';

class NotificationRepository {
  final NotificationRemoteDatasource _datasource;

  NotificationRepository({required NotificationRemoteDatasource datasource})
      : _datasource = datasource;

  Future<Either<AppError, void>> registerFcmToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    try {
      await _datasource.registerFcmToken(
        token:    token,
        platform: platform,
        deviceId: deviceId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, void>> removeFcmToken(String token) async {
    try {
      await _datasource.removeFcmToken(token);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, NotificationsPage>> getNotifications({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _datasource.getNotifications(
        page:    page,
        perPage: perPage,
      );
      final page0 = NotificationsPage.fromJson(
        response.data as Map<String, dynamic>,
      );
      return Right(page0);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, int>> getUnreadCount() async {
    try {
      final response = await _datasource.getUnreadCount();
      final count = (response.data['count'] as num).toInt();
      return Right(count);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, void>> markRead(int notificationId) async {
    try {
      await _datasource.markRead(notificationId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, void>> markAllRead() async {
    try {
      await _datasource.markAllRead();
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  Future<Either<AppError, void>> deleteNotification(int id) async {
    try {
      await _datasource.deleteNotification(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
