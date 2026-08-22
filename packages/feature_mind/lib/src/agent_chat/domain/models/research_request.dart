import 'package:flutter/foundation.dart';

/// How far a Deep Research job is allowed to go.
///
/// This is a budget policy, not a prompt adjective. The engine stops on
/// evidence sufficiency or when the matching [ResearchBudget] is spent.
enum ResearchMode { quick, standard, deep, exhaustive }

/// Which search providers a job may use. The model does not pick this.
enum SearchPolicy {
  localOnly,
  privacyFirst,
  balanced,
  maximumQuality,
  academic,
}

@immutable
class ResearchBudget {
  const ResearchBudget({
    required this.maxSearches,
    required this.maxSources,
    required this.maxIterations,
    required this.maxParallelTasks,
    required this.maxTokens,
    required this.maxDuration,
  });

  factory ResearchBudget.forMode(ResearchMode mode) {
    switch (mode) {
      case ResearchMode.quick:
        return const ResearchBudget(
          maxSearches: 5,
          maxSources: 8,
          maxIterations: 1,
          maxParallelTasks: 2,
          maxTokens: 4096,
          maxDuration: Duration(seconds: 30),
        );
      case ResearchMode.standard:
        return const ResearchBudget(
          maxSearches: 15,
          maxSources: 20,
          maxIterations: 3,
          maxParallelTasks: 4,
          maxTokens: 12288,
          maxDuration: Duration(minutes: 2),
        );
      case ResearchMode.deep:
        return const ResearchBudget(
          maxSearches: 40,
          maxSources: 48,
          maxIterations: 8,
          maxParallelTasks: 6,
          maxTokens: 32768,
          maxDuration: Duration(minutes: 8),
        );
      case ResearchMode.exhaustive:
        return const ResearchBudget(
          maxSearches: 100,
          maxSources: 120,
          maxIterations: 16,
          maxParallelTasks: 8,
          maxTokens: 65536,
          maxDuration: Duration(minutes: 20),
        );
    }
  }

  final int maxSearches;
  final int maxSources;
  final int maxIterations;
  final int maxParallelTasks;
  final int maxTokens;
  final Duration maxDuration;
}

/// Typed research goal. Flutter and Rust share this shape; the model does
/// not own the workflow.
@immutable
class ResearchRequest {
  const ResearchRequest({
    required this.question,
    this.mode = ResearchMode.deep,
    this.policy = SearchPolicy.balanced,
    this.freshness,
    this.outputFormat = 'technical_report',
  });

  final String question;
  final ResearchMode mode;
  final SearchPolicy policy;
  final Duration? freshness;
  final String outputFormat;

  ResearchBudget get budget => ResearchBudget.forMode(mode);
}
