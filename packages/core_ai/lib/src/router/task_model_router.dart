import '../models/offline_model_info.dart';
import 'ai_task.dart';

/// Thrown by [TaskModelRouter.resolve] for a task it cannot serve from
/// `ModelCatalog` at all -- see [AiTask.isCatalogResolvable]. Distinct from
/// returning null, which means "no *available* model happens to declare this
/// capability," a recoverable, per-call condition. This exception means the
/// task itself is out of scope for this router, every call, regardless of
/// what is installed.
class UnroutableTaskException implements Exception {
  UnroutableTaskException(this.task, this.message);

  final AiTask task;
  final String message;

  @override
  String toString() => 'UnroutableTaskException($task): $message';
}

/// Resolves an [AiTask] to the [OfflineModelInfo] that should serve it.
///
/// Selects among the caller-supplied [available] models -- installed models,
/// or a shell's candidate list -- rather than the whole `ModelCatalog`, since
/// only an installed model can actually serve a request. Two mechanisms
/// decide the winner, in order:
///
/// 1. An explicit per-task override in [taskOverrides] (a model id), if
///    configured and present in [available].
/// 2. Otherwise, the first model in [available] that declares the task's
///    [AiTask.requiredCapability]. [available]'s order is the caller's
///    preference order (most-recently-used, catalog declaration order,
///    whatever the caller means by "first") -- this does not re-rank it.
///
/// Task-to-model selection only. Where the request executes (on-device vs.
/// cloud) stays `AIRouter`/`AIRoutingStrategy`'s job.
class TaskModelRouter {
  const TaskModelRouter({this.taskOverrides = const {}});

  /// User- or shell-configured model id per task, e.g.
  /// `{AiTask.chat: 'gemma-4-e2b-it-litertlm'}`.
  final Map<AiTask, String> taskOverrides;

  /// Resolves [task] against [available].
  ///
  /// Returns null if none of [available] declares the required capability.
  /// Throws [UnroutableTaskException] for a task with no
  /// [AiTask.requiredCapability] ([AiTask.speechToText],
  /// [AiTask.textToSpeech]) -- those are never resolvable here, so returning
  /// null for them would look identical to the recoverable "nothing
  /// installed yet" case and hide that the caller asked the wrong router.
  OfflineModelInfo? resolve(AiTask task, List<OfflineModelInfo> available) {
    final requiredCapability = task.requiredCapability;
    if (requiredCapability == null) {
      throw UnroutableTaskException(
        task,
        '$task is served by feature_mind\'s speech engines, not '
        'ModelCatalog -- TaskModelRouter only resolves text/vision tasks.',
      );
    }

    final overrideId = taskOverrides[task];
    if (overrideId != null) {
      final override = available.where((m) => m.id == overrideId).firstOrNull;
      if (override != null) return override;
      // A configured override that isn't currently installed degrades to the
      // capability search below rather than failing the whole request.
    }

    return available
        .where((m) => m.capabilities.contains(requiredCapability))
        .firstOrNull;
  }
}
