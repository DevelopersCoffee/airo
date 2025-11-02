import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Attachment button for Quest chat - similar to ChatGPT
class AttachmentButton extends StatefulWidget {
  final Function(String fileName, String filePath) onFileSelected;

  const AttachmentButton({
    super.key,
    required this.onFileSelected,
  });

  @override
  State<AttachmentButton> createState() => _AttachmentButtonState();
}

class _AttachmentButtonState extends State<AttachmentButton> {
  bool _isLoading = false;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'doc',
          'docx',
          'txt',
          'xlsx',
          'xls',
          'pptx',
          'ppt',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        widget.onFileSelected(file.name, file.path ?? '');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isLoading ? null : _pickFile,
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.attach_file),
      tooltip: 'Attach file',
    );
  }
}

