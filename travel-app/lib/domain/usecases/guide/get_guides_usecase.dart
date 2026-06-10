import 'package:dartz/dartz.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/repositories/guide_repository.dart';
import 'package:voyageur/domain/entities/guide_entity.dart';

/// Use-case: جلب قائمة المرشدين مع فلترة اختيارية.
class GetGuidesUsecase {
  final GuideRepository _repository;

  GetGuidesUsecase({required GuideRepository repository})
      : _repository = repository;

  Future<Either<AppError, List<GuideEntity>>> call({
    Map<String, dynamic>? filters,
  }) =>
      _repository.getGuides(filters: filters);
}
