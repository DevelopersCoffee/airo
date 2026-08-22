import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notebook_l10n.dart';

const String notebookUiLocaleKey = 'mind_notebook_ui_locale';

final notebookUiLocaleProvider =
    StateNotifierProvider<NotebookUiLocaleNotifier, String>(
      (ref) => NotebookUiLocaleNotifier(),
    );

class NotebookUiLocaleNotifier extends StateNotifier<String> {
  NotebookUiLocaleNotifier() : super('en') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotebookL10n.of(prefs.getString(notebookUiLocaleKey)).locale;
  }

  Future<void> select(String locale) async {
    final resolved = NotebookL10n.of(locale).locale;
    state = resolved;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(notebookUiLocaleKey, resolved);
  }
}

Future<String> loadNotebookUiLocale() async {
  final prefs = await SharedPreferences.getInstance();
  return NotebookL10n.of(prefs.getString(notebookUiLocaleKey)).locale;
}
