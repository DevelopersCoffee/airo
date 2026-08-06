import 'package:core_ai/core_ai.dart' show SafetyProfile;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user, reduced to the fields the assistant screens read.
///
/// The package deliberately does not know the host's user model: quotes need
/// an id to personalise on and a name to greet, and sign-out needs to know
/// whether the session came from Google.
class AssistantHostUser {
  const AssistantHostUser({
    required this.id,
    required this.username,
    this.isGoogleUser = false,
  });

  final String id;
  final String username;
  final bool isGoogleUser;
}

/// Result of handing a chat message to the host's finance ingestion.
///
/// `null` from [AssistantHostAdapter.ingestFinanceMessage] means "not a
/// finance message" — the chat screen then falls through to the normal
/// assistant reply path. A non-null value means the host consumed the
/// message and produced the transcript line the user should see.
class AssistantFinanceIngestion {
  const AssistantFinanceIngestion({
    required this.responseText,
    this.undoLabel,
    this.onUndo,
  });

  /// Transcript line to append as the assistant's reply.
  final String responseText;

  /// Snackbar body offering an undo, or `null` when nothing is undoable.
  final String? undoLabel;

  /// Reverses the ingestion. Returns a transcript line to append on success,
  /// or `null` when the undo failed and the transcript should not change.
  final Future<String?> Function()? onUndo;
}

/// Host-app services the assistant screens need but the package must not own.
///
/// Both shells (the super app and the standalone Airo Mind shell) provide the
/// same app-layer implementation; tests provide fakes. Each member below maps
/// to one call-site cluster inside the package — see
/// `.superpowers/sdd/2026-08-06-airo-mind-modular-app/task-4-report.md` for the
/// derivation.
abstract class AssistantHostAdapter {
  const AssistantHostAdapter();

  // --- Identity -----------------------------------------------------------

  /// Currently signed-in user, or `null` for a guest session.
  ///
  /// Read by the daily-quote provider (personalisation id), the quote card
  /// (greeting), and the profile screen (Google-session detection).
  AssistantHostUser? get currentUser;

  /// Ends the session and returns the shell to its login destination.
  ///
  /// One member rather than three: the profile screen's logout button is a
  /// single user intent, and which providers it unwinds (Google sign-out,
  /// local logout, route) is the host's business.
  Future<void> signOutAndReturnToLogin(BuildContext context);

  // --- Host-owned destinations -------------------------------------------

  /// Opens the shell's settings screen, which the package does not own.
  void openHostSettings(BuildContext context);

  /// Opens the host's HTTP status reference developer tool.
  void openHttpStatusReference(BuildContext context);

  /// Opens the host's dictionary demo developer tool.
  void openDictionaryDemo(BuildContext context);

  // --- Accessibility ------------------------------------------------------

  /// Reads [text] aloud. Returns `false` when the device has no usable TTS
  /// engine, so the caller can explain rather than fail.
  Future<bool> speakAloud(String text);

  // --- Dictionary ---------------------------------------------------------

  /// Wraps a subtree so selected words gain the host's dictionary actions.
  Widget wrapWithDictionarySelection({required Widget child});

  /// Shows the host's definition popup for a single word.
  void showWordDefinition(BuildContext context, String word);

  /// Renders selectable text with the host's dictionary lookup attached.
  Widget dictionaryAwareText(String text);

  // --- Developer tools ----------------------------------------------------

  /// Shows the host's bug-report dialog.
  Future<void> showBugReportDialog(BuildContext context);

  // --- AI preferences -----------------------------------------------------

  /// The host's AI model-preferences settings UI, embedded in the profile
  /// screen.
  ///
  /// A widget slot rather than a data seam: the settings model, its storage
  /// dashboard, and the model-manager screens it links to all live in the
  /// host, and mirroring that model into the package would duplicate roughly
  /// two hundred lines to gain nothing.
  Widget aiPreferencesSection();

  /// Safety posture to apply to assistant input and output.
  SafetyProfile get safetyProfile;

  /// Whether the assistant may fall back to a backup runtime automatically.
  bool get autoFallbackEnabled;

  /// Context window (tokens) the user configured for local runtimes.
  int get modelContextLength;

  /// Persists a new context window, used when a model health action asks the
  /// user to shrink it.
  Future<void> setModelContextLength(int tokens);

  /// Repairs a partially downloaded model package.
  Future<void> repairModelPackage(String packageId);

  // --- Platform -----------------------------------------------------------

  /// Whether the host runs on Android, where AICore/Gemini Nano probes are
  /// meaningful. Kept on the adapter rather than read from
  /// `defaultTargetPlatform` so widget tests keep the desktop behaviour they
  /// had before the extraction.
  bool get isAndroidHost;

  // --- Finance ------------------------------------------------------------

  /// Offers a chat message to the host's finance ingestion.
  ///
  /// Returns `null` when the message is not a finance transaction. One member
  /// for the whole cluster: parsing, ledger writes, cache invalidation, and
  /// undo are all finance-domain concerns the assistant must not import.
  Future<AssistantFinanceIngestion?> ingestFinanceMessage(String message);
}

/// The host adapter for the current shell.
///
/// Must be overridden by the shell that mounts the assistant. Throwing by
/// default keeps a missing override a loud startup failure instead of a
/// silently degraded assistant.
final assistantHostAdapterProvider = Provider<AssistantHostAdapter>(
  (ref) => throw UnimplementedError(
    'AssistantHostAdapter must be overridden by the owning shell',
  ),
);
