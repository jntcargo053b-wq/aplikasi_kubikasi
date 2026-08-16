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
    return list
        .map((e) => BarangItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<BarangItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
