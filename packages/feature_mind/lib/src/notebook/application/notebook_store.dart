import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../notes/domain/notes_operation_log.dart';
import '../../notes/notes_capability.dart';

/// Same path [MindRuntimeNotesScreen] already uses, so ingest and the UI
/// fold the same log.
Future<String> notebookLogPath() async {
  final base = await getApplicationSupportDirectory();
  return p.join(base.path, 'airo_mind', 'notes.log');
}

Future<NotesCapability> openNotebookCapability() async {
  final log = await NotesOperationLog.open(await notebookLogPath());
  return NotesCapability.rustPreferred(log);
}
