import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../anya_route_names.dart';
import '../providers/anya_providers.dart';

class ImportPdfScreen extends ConsumerStatefulWidget {
  const ImportPdfScreen({super.key});

  @override
  ConsumerState<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends ConsumerState<ImportPdfScreen> {
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(anyaSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Import diet plan')),
      body: ListView(
        padding: AiroSpacing.paddingMd,
        children: [
          Text(
            'Text PDFs extract automatically. Scanned hospital PDFs often have no text layer — paste the plan instead. OCR is not in this slice.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AiroSpacing.lg),
          AppButton(
            label: session.busy ? 'Reading PDF…' : 'Choose PDF',
            isLoading: session.busy,
            onPressed: session.busy ? null : _pick,
          ),
          const SizedBox(height: AiroSpacing.lg),
          Text(
            'Or paste plan text',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AiroSpacing.sm),
          TextField(
            controller: _paste,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'DAY 7\n10:00 AM\nveg poha 1k',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AiroSpacing.md),
          AppButton(
            label: 'Import pasted text',
            variant: AppButtonVariant.secondary,
            onPressed: session.busy ? null : _pasteText,
          ),
          if (session.emptyExtract) ...[
            const SizedBox(height: AiroSpacing.lg),
            const EmptyStateWidget(
              icon: Icons.document_scanner_outlined,
              title: 'No extractable text',
              message:
                  'This looks like a scanned PDF. Paste the diet-plan text above instead of waiting on OCR.',
            ),
          ],
          if (session.errorMessage != null) ...[
            const SizedBox(height: AiroSpacing.md),
            Text(session.errorMessage!),
          ],
        ],
      ),
    );
  }

  Future<void> _openReviewIfReady() async {
    if (!mounted) return;
    final session = ref.read(anyaSessionProvider);
    if (session.pendingProgram != null) {
      context.pushNamed(AnyaRouteNames.importReview);
    }
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await ref
        .read(anyaSessionProvider.notifier)
        .importPdf(fileName: file.name, bytes: bytes);
    await _openReviewIfReady();
  }

  Future<void> _pasteText() async {
    await ref
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Pasted plan', text: _paste.text);
    await _openReviewIfReady();
  }
}
