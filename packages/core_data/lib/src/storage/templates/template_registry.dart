import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/services.dart';

class TemplateRegistry {
  TemplateRegistry._(this._templates);

  static const bundledAssetPaths = <String>[
    'packages/core_data/lib/src/storage/templates/real_estate_under_construction.json',
    'packages/core_data/lib/src/storage/templates/university_admission.json',
    'packages/core_data/lib/src/storage/templates/medical_surgery.json',
    'packages/core_data/lib/src/storage/templates/insurance_claim.json',
    'packages/core_data/lib/src/storage/templates/car_purchase.json',
  ];

  final List<LifeTrackTemplate> _templates;

  factory TemplateRegistry.fromTemplates(List<LifeTrackTemplate> templates) {
    return TemplateRegistry._(List.unmodifiable(templates));
  }

  static Future<TemplateRegistry> loadBundled({AssetBundle? bundle}) async {
    final assetBundle = bundle ?? rootBundle;
    final templates = <LifeTrackTemplate>[];

    for (final assetPath in bundledAssetPaths) {
      final rawJson = await assetBundle.loadString(assetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw ParseError(
          'Template asset must decode to a JSON object: $assetPath',
        );
      }
      final result = validate(decoded);
      if (result case Ok(value: final template)) {
        templates.add(template);
      } else if (result case Err(error: final error, stack: final stack)) {
        throw ParseError(
          'Bundled template failed validation: $assetPath',
          originalError: error,
          originalStack: stack,
        );
      }
    }

    return TemplateRegistry._(List.unmodifiable(templates));
  }

  List<LifeTrackTemplate> getAll() => List.unmodifiable(_templates);

  List<LifeTrackTemplate> getByCategory(LifeTrackCategory category) =>
      _templates
          .where((template) => template.category == category)
          .toList(growable: false);

  LifeTrackTemplate? getById(String templateId) {
    for (final template in _templates) {
      if (template.templateId == templateId) return template;
    }
    return null;
  }

  static Result<LifeTrackTemplate> validate(Map<String, dynamic> json) {
    try {
      final template = LifeTrackTemplate.fromJson(json);
      final fieldErrors = <String, String>{};

      if (template.templateId.trim().isEmpty) {
        fieldErrors['template_id'] = 'Template ID is required.';
      }
      if (template.title.trim().isEmpty) {
        fieldErrors['title'] = 'Title is required.';
      }
      if (template.description.trim().isEmpty) {
        fieldErrors['description'] = 'Description is required.';
      }
      if (template.version.trim().isEmpty) {
        fieldErrors['version'] = 'Version is required.';
      }
      if (template.milestones.isEmpty) {
        fieldErrors['milestones'] = 'At least one milestone is required.';
      }

      for (
        var milestoneIndex = 0;
        milestoneIndex < template.milestones.length;
        milestoneIndex++
      ) {
        final milestone = template.milestones[milestoneIndex];
        if (milestone.name.trim().isEmpty) {
          fieldErrors['milestones[$milestoneIndex].name'] =
              'Milestone name is required.';
        }
        if (milestone.objective.trim().isEmpty) {
          fieldErrors['milestones[$milestoneIndex].objective'] =
              'Milestone objective is required.';
        }
        if (milestone.tasks.isEmpty) {
          fieldErrors['milestones[$milestoneIndex].tasks'] =
              'At least one task is required.';
        }

        for (
          var taskIndex = 0;
          taskIndex < milestone.tasks.length;
          taskIndex++
        ) {
          final task = milestone.tasks[taskIndex];
          if (task.summary.trim().isEmpty) {
            fieldErrors['milestones[$milestoneIndex].tasks[$taskIndex].summary'] =
                'Task summary is required.';
          }
        }
      }

      if (fieldErrors.isNotEmpty) {
        return Err(
          ValidationError(
            'Invalid LifeTrack template payload',
            fieldErrors: fieldErrors,
          ),
          StackTrace.current,
        );
      }

      return Ok(template);
    } catch (error, stack) {
      return Err(
        ParseError(
          'Failed to parse LifeTrack template payload',
          originalError: error,
          originalStack: stack,
        ),
        stack,
      );
    }
  }
}
