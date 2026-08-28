import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Owns the company logo copied into the app documents directory.
/// Source files selected from the gallery are never deleted by this service.
class ReportLogoStorageService {
  static Future<String> prepareTargetPath(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('File logo tidak ditemukan.');
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/report_header');
    await dir.create(recursive: true);

    final dot = sourcePath.lastIndexOf('.');
    final extension = dot >= 0 ? sourcePath.substring(dot).toLowerCase() : '';
    final safeExtension = extension == '.png' ? '.png' : '.jpg';
    return '${dir.path}/company_logo_${DateTime.now().microsecondsSinceEpoch}$safeExtension';
  }

  static Future<String> copyIntoAppStorage(String sourcePath) async {
    final targetPath = await prepareTargetPath(sourcePath);
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  static Future<bool> delete(String? path) async {
    if (path == null || path.trim().isEmpty) return false;
    try {
      final file = File(path);
      final docs = await getApplicationDocumentsDirectory();
      final root = _normalize('${docs.path}/report_header');
      final target = _normalize(file.path);
      if (!(target == root || target.startsWith('$root/'))) return false;
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _normalize(String path) =>
      path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
}
