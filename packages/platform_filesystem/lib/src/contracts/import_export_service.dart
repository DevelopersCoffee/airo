import 'dart:io';
import '../files/file_types.dart';

abstract interface class ImportExportService {
  Future<File> exportData(ExportFile exportFile, dynamic data);
  Future<dynamic> importData(File file);
}
