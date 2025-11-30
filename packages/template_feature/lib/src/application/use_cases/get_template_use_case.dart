import 'package:core_domain/core_domain.dart';

import '../../domain/entities/template_entity.dart';
import '../../domain/repositories/template_repository.dart';

/// Use case for getting a template entity by ID
class GetTemplateUseCase implements UseCase<String, TemplateEntity> {
  const GetTemplateUseCase(this._repository);

  final TemplateRepository _repository;

  @override
  Future<Result<TemplateEntity>> call(String id) => _repository.findById(id);
}

/// Use case for listing all template entities
class ListTemplatesUseCase implements NoInputUseCase<List<TemplateEntity>> {
  const ListTemplatesUseCase(this._repository);

  final TemplateRepository _repository;

  @override
  Future<Result<List<TemplateEntity>>> call() => _repository.findAll();
}

