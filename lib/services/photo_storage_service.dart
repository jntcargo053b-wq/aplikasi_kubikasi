import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

/// Owns photos copied by the app into its documents directory.
///
/// Cleanup is restricted to files inside the app's documents directory and
/// never removes a file that is still referenced by persisted shipments.
class PhotoStorageService {
  static Future<bool> delete(String? photoPath) async {
    if (photoPath == null || photoPath.trim().isEmpty) return false;

    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = _normalize(docs.path);
      final target = _normalize(photoPath);

      if (!_isInsideDocuments(target, root)) return false;

      final shipments = await StorageService().loadPengiriman();
      final referenced = _referencedPaths(shipments);
      return _deleteIfUnreferenced(
        photoPath: photoPath,
        normalizedPath: target,
        root: root,
        referenced: referenced,
      );
    } catch (_) {
      return false;
    }
  }

  /// Deletes a batch using one persisted-data read instead of one read per file.
  static Future<void> deleteAll(Iterable<String?> paths) async {
    final unique = paths
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    if (unique.isEmpty) return;

    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = _normalize(docs.path);
      final shipments = await StorageService().loadPengiriman();
      final referenced = _referencedPaths(shipments);

      for (final path in unique) {
        final normalized = _normalize(path);
        if (!_isInsideDocuments(normalized, root)) continue;
        await _deleteIfUnreferenced(
          photoPath: path,
          normalizedPath: normalized,
          root: root,
          referenced: referenced,
        );
      }
    } catch (_) {
      // Cleanup must never break the user's normal save/delete flow.
    }
  }

  static Set<String> _referencedPaths(Iterable<Pengiriman> shipments) => shipments
      .expand((shipment) => shipment.barang)
      .map((item) => item.photoPath)
      .whereType<String>()
      .map(_normalize)
      .toSet();

  static Future<bool> _deleteIfUnreferenced({
    required String photoPath,
    required String normalizedPath,
    required String root,
    required Set<String> referenced,
  }) async {
    if (!_isInsideDocuments(normalizedPath, root) ||
        referenced.contains(normalizedPath)) {
      return false;
    }

    try {
      final file = File(photoPath);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isInsideDocuments(String target, String root) =>
      target == root || target.startsWith('$root/');

  static String _normalize(String path) {
    var value = path.replaceAll('\\', '/');
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
