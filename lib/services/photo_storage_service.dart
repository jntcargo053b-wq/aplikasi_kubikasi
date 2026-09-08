import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

/// Owns photos copied by the app into its documents directory.
///
/// Deletion is intentionally restricted to files inside the app's documents
/// directory and to files that are no longer referenced by persisted data.
/// This makes cleanup safe even when legacy data contains the same photo path
/// in more than one item.
class PhotoStorageService {
  static Future<bool> delete(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) return false;

    try {
      final file = File(photoPath);
      final docs = await getApplicationDocumentsDirectory();
      final root = _normalize(docs.path);
      final target = _normalize(file.path);

      if (!(target == root || target.startsWith('$root/'))) return false;

      // Never remove a photo that is still referenced by persisted shipments.
      // This also protects shared/duplicated legacy photo paths.
      final shipments = await StorageService().loadPengiriman();
      final stillReferenced = shipments
          .expand((shipment) => shipment.barang)
          .map((item) => item.photoPath)
          .whereType<String>()
          .map(_normalize)
          .contains(target);
      if (stillReferenced) return false;

      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      // Cleanup must never break the user's normal save/delete flow.
      return false;
    }
  }

  static Future<void> deleteAll(Iterable<String?> paths) async {
    final unique = paths
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();

    for (final path in unique) {
      await delete(path);
    }
  }

  static String _normalize(String path) {
    var value = path.replaceAll('\\', '/');
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
