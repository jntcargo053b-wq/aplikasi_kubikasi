import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/barang_item.dart';

class StorageService {
  static const _key = 'daftar_barang_v1';

  Future<List<BarangItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    final result = <BarangItem>[];
    for (final e in list) {
      try {
        result.add(BarangItem.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        // Lewati satu entri yang korup/tidak kompatibel daripada bikin
        // seluruh daftar barang gagal dimuat.
      }
    }
    return result;
  }

  Future<void> save(List<BarangItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
