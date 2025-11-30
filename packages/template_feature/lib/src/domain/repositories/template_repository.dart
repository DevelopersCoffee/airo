import 'package:core_domain/core_domain.dart';

import '../entities/template_entity.dart';

/// Repository interface for template entities
abstract class TemplateRepository extends Repository<TemplateEntity> {
  /// Custom method example - find by name
  Future<Result<List<TemplateEntity>>> findByName(String name);
}

