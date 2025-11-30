import 'package:flutter_test/flutter_test.dart';
import 'package:template_feature/template_feature.dart';

void main() {
  group('TemplateEntity', () {
    test('should create entity with required fields', () {
      const entity = TemplateEntity(
        id: '123',
        name: 'Test Item',
      );

      expect(entity.id, '123');
      expect(entity.name, 'Test Item');
      expect(entity.description, isNull);
    });

    test('should create entity with all fields', () {
      final now = DateTime.now();
      final entity = TemplateEntity(
        id: '123',
        name: 'Test Item',
        description: 'A description',
        createdAt: now,
      );

      expect(entity.id, '123');
      expect(entity.name, 'Test Item');
      expect(entity.description, 'A description');
      expect(entity.createdAt, now);
    });

    test('copyWith should create new entity with updated fields', () {
      const original = TemplateEntity(
        id: '123',
        name: 'Original',
      );

      final updated = original.copyWith(
        name: 'Updated',
        description: 'New description',
      );

      expect(updated.id, '123');
      expect(updated.name, 'Updated');
      expect(updated.description, 'New description');
    });

    test('equality should be based on props', () {
      const entity1 = TemplateEntity(id: '123', name: 'Test');
      const entity2 = TemplateEntity(id: '123', name: 'Test');
      const entity3 = TemplateEntity(id: '456', name: 'Test');

      expect(entity1, equals(entity2));
      expect(entity1, isNot(equals(entity3)));
    });
  });
}

