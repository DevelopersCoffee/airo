import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// Dialog to upload transaction files (receipts, invoices, etc.)
class TransactionUploadDialog extends StatefulWidget {
  final Function(String fileName, String filePath, String fileType)
      onFileSelected;

  const TransactionUploadDialog({
    super.key,
    required this.onFileSelected,
  });

  @override
  State<TransactionUploadDialog> createState() =>
      _TransactionUploadDialogState();
}

class _TransactionUploadDialogState extends State<TransactionUploadDialog> {
  String? _selectedFileName;
  String? _selectedFilePath;
  String? _selectedFileType;

  Future<void> _pickFile(String fileType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: _getFileType(fileType),
        allowedExtensions: _getAllowedExtensions(fileType),
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = file.path;
          _selectedFileType = fileType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  FileType _getFileType(String fileType) {
    switch (fileType) {
      case 'Image':
        return FileType.image;
      case 'PDF':
        return FileType.custom;
      case 'Document':
        return FileType.custom;
      default:
        return FileType.any;
    }
  }

  List<String> _getAllowedExtensions(String fileType) {
    switch (fileType) {
      case 'Image':
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      case 'PDF':
        return ['pdf'];
      case 'Document':
        return ['doc', 'docx', 'txt', 'xlsx', 'xls'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Transaction File'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select file type to upload:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            // Image upload button
            _buildFileTypeButton(
              icon: Icons.image,
              label: 'Image',
              onPressed: () => _pickFile('Image'),
            ),
            const SizedBox(height: 12),
            // PDF upload button
            _buildFileTypeButton(
              icon: Icons.picture_as_pdf,
              label: 'PDF',
              onPressed: () => _pickFile('PDF'),
            ),
            const SizedBox(height: 12),
            // Document upload button
            _buildFileTypeButton(
              icon: Icons.description,
              label: 'Document',
              onPressed: () => _pickFile('Document'),
            ),
            const SizedBox(height: 16),
            // Selected file display
            if (_selectedFileName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'File Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            _selectedFileName!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFileName != null
              ? () {
                  widget.onFileSelected(
                    _selectedFileName!,
                    _selectedFilePath!,
                    _selectedFileType!,
                  );
                  Navigator.pop(context);
                }
              : null,
          child: const Text('Upload'),
        ),
      ],
    );
  }

  Widget _buildFileTypeButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

