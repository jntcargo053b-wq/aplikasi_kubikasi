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
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final result = <Pengiriman>[];
          for (final rawItem in decoded) {
            if (rawItem is! Map) continue;
            try {
              final item = Pengiriman.fromJson(
                Map<String, dynamic>.from(rawItem),
              );
              if (item.pengirim.trim().isNotEmpty &&
                  item.nomorResi.trim().isNotEmpty &&
                  item.barang.isNotEmpty) {
                result.add(item);
              }
            } catch (_) {}
          }
          return result;
        }
      } catch (_) {}
    }

    // Migrasi aman dari data lama. Data lama belum punya resi, jadi
    // tidak dianggap transaksi selesai dan tidak dipaksakan menjadi resi.
    return [];
  }

  Future<void> savePengiriman(List<Pengiriman> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _shipmentKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
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
