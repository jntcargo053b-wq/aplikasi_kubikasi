import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pengiriman.dart';
import '../models/barang_item.dart';

class StorageService {
  static const _shipmentKey = 'daftar_pengiriman_v2';
  static const _legacyKey = 'daftar_barang_v1';

  Future<List<Pengiriman>> loadPengiriman() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shipmentKey);
    if (raw == null) {
      // Legacy data has no receipt number and is not a completed shipment.
      return [];
    }

    if (raw.trim().isEmpty) {
      throw const FormatException(
        'Data pengiriman tersimpan kosong dan tidak dapat dibaca. '
        'Data tidak diubah untuk mencegah kehilangan data.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException(
        'Data pengiriman tersimpan rusak (JSON tidak valid). '
        'Data tidak diubah. Pulihkan dari backup sebelum melanjutkan.',
      );
    }

    if (decoded is! List) {
      throw const FormatException(
        'Format data pengiriman tidak valid. Pulihkan dari backup sebelum melanjutkan.',
      );
    }

    final result = <Pengiriman>[];
    for (var index = 0; index < decoded.length; index++) {
      final rawItem = decoded[index];
      if (rawItem is! Map) {
        throw FormatException(
          'Record pengiriman ke-${index + 1} tidak valid. '
          'Data tidak diubah untuk mencegah kehilangan data.',
        );
      }

      final Pengiriman item;
      try {
        item = Pengiriman.fromJson(Map<String, dynamic>.from(rawItem));
      } catch (_) {
        throw FormatException(
          'Record pengiriman ke-${index + 1} tidak dapat dibaca. '
          'Pulihkan dari backup sebelum melanjutkan.',
        );
      }

      // Pengiriman.fromJson historically skipped malformed barang entries.
      // Compare raw and parsed counts so a damaged item cannot disappear
      // silently while the rest of the shipment is accepted.
      final rawBarang = rawItem['barang'];
      if (rawBarang is! List || item.barang.length != rawBarang.length) {
        throw FormatException(
          'Daftar barang pada pengiriman ke-\${index + 1} tidak utuh. '
          'Data tidak diubah untuk mencegah kehilangan data.',
        );
      }

      if (item.pengirim.trim().isEmpty ||
          item.nomorResi.trim().isEmpty ||
          item.barang.isEmpty) {
        throw FormatException(
          'Record pengiriman ke-${index + 1} tidak lengkap. '
          'Data tidak diubah untuk mencegah kehilangan data.',
        );
      }
      result.add(item);
    }
    return result;
  }

  /// Captures the exact persisted value so a failed restore can roll back
  /// even when the current shipment JSON is unreadable.
  Future<String?> readRawShipmentData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_shipmentKey);
  }

  /// Restores the exact previous value after a failed transactional restore.
  Future<void> restoreRawShipmentData(String? raw) async {
    final prefs = await SharedPreferences.getInstance();
    final restored = raw == null
        ? await prefs.remove(_shipmentKey)
        : await prefs.setString(_shipmentKey, raw);
    if (!restored) {
      throw StateError('Gagal memulihkan data pengiriman sebelumnya.');
    }
  }

  Future<void> savePengiriman(List<Pengiriman> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    final saved = await prefs.setString(_shipmentKey, encoded);
    if (!saved) {
      throw StateError('Gagal menyimpan data pengiriman ke penyimpanan aplikasi.');
    }
  }

  Future<List<BarangItem>> loadLegacyItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => BarangItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
