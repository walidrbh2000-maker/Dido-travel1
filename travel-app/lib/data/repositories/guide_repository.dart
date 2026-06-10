import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/datasources/remote/guide_remote_datasource.dart';
import 'package:voyageur/data/models/guide_model.dart';
import 'package:voyageur/domain/entities/guide_entity.dart';

/// Repository للمرشدين — يعكس نمط HotelRepository بدقة.
/// يتولى: الاستدعاء ← تحويل Model→Entity ← معالجة الأخطاء.
class GuideRepository {
  final GuideRemoteDatasource _remoteDatasource;

  GuideRepository({required GuideRemoteDatasource remoteDatasource})
      : _remoteDatasource = remoteDatasource;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<Either<AppError, List<GuideEntity>>> getGuides({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final response = await _remoteDatasource.getGuides(
        queryParameters: filters,
      );
      final data = response.data;
      // يدعم paginated response { data: [...] } وكذلك array مباشر
      final list = (data is Map ? (data['data'] ?? data['guides'] ?? []) : data) as List;
      final guides = list
          .map(
            (e) => GuideEntity.fromModel(
              GuideModel.fromJson(e as Map<String, dynamic>),
            ),
          )
          .toList();
      return Right(guides);
    } on DioException catch (e) {
      return Left(_handleDioException(e));
    } catch (e, st) {
      // ignore: avoid_print
      print('[GuideRepository.getGuides] Unexpected error: $e\n$st');
      return Left(AppError.unknown(e));
    }
  }

  Future<Either<AppError, GuideEntity>> getGuideDetail(int id) async {
    try {
      final response = await _remoteDatasource.getGuideDetail(id);
      // يدعم response مباشر أو مُغلّف بـ { guide: {...} }
      final json = (response.data is Map &&
              response.data.containsKey('guide'))
          ? response.data['guide'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      final entity = GuideEntity.fromModel(GuideModel.fromJson(json));
      return Right(entity);
    } on DioException catch (e) {
      return Left(_handleDioException(e, resource: 'Guide #$id'));
    } catch (e, st) {
      // ignore: avoid_print
      print('[GuideRepository.getGuideDetail] Unexpected error: $e\n$st');
      return Left(AppError.unknown(e));
    }
  }

  // ── Error handling ────────────────────────────────────────────────────────

  AppError _handleDioException(DioException e, {String resource = 'Guide'}) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    switch (statusCode) {
      case 401:
      case 403:
        return const AppError.unauthorized();
      case 404:
        return AppError.notFound(resource);
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
                'Erreur serveur ($statusCode)')
            : 'Erreur serveur ($statusCode)';
        return AppError.serverError(message);
    }
  }
}
