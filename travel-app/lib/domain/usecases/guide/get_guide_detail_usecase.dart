import 'package:dartz/dartz.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/repositories/guide_repository.dart';
import 'package:voyageur/domain/entities/guide_entity.dart';

/// Use-case: جلب تفاصيل مرشد واحد.
class GetGuideDetailUsecase {
  final GuideRepository _repository;

  GetGuideDetailUsecase({required GuideRepository repository})
      : _repository = repository;

  Future<Either<AppError, GuideEntity>> call(int id) =>
      _repository.getGuideDetail(id);
}
