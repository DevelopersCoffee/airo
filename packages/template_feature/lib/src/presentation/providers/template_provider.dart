import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/template_entity.dart';

/// State for the template feature
sealed class TemplateState {
  const TemplateState();
}

class TemplateInitial extends TemplateState {
  const TemplateInitial();
}

class TemplateLoading extends TemplateState {
  const TemplateLoading();
}

class TemplateLoaded extends TemplateState {
  const TemplateLoaded(this.items);
  final List<TemplateEntity> items;
}

class TemplateError extends TemplateState {
  const TemplateError(this.message);
  final String message;
}

/// Notifier for managing template state
class TemplateNotifier extends StateNotifier<TemplateState> {
  TemplateNotifier() : super(const TemplateInitial());

  Future<void> load() async {
    state = const TemplateLoading();

    // TODO: Inject use case and call it
    await Future<void>.delayed(const Duration(seconds: 1));

    // Mock data for demonstration
    state = const TemplateLoaded([
      TemplateEntity(id: '1', name: 'Item 1'),
      TemplateEntity(id: '2', name: 'Item 2'),
    ]);
  }

  void reset() {
    state = const TemplateInitial();
  }
}

/// Provider for template state
final templateProvider =
    StateNotifierProvider<TemplateNotifier, TemplateState>(
  (ref) => TemplateNotifier(),
);

