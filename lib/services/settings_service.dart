import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_settings.dart';

class SettingsService {
  static const _reportSettingsKey = 'report_header_settings_v1';

  Future<ReportSettings> loadReportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reportSettingsKey);
    if (raw == null || raw.isEmpty) return const ReportSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ReportSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ReportSettings();
  }

  /// Reads the exact stored settings value for transactional rollback.
  /// Unlike [loadReportSettings], this preserves malformed legacy/corrupt JSON.
  Future<String?> readRawReportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reportSettingsKey);
  }

  /// Restores the exact previous settings value after a failed operation.
  Future<void> restoreRawReportSettings(String? raw) async {
    final prefs = await SharedPreferences.getInstance();
    final restored = raw == null
        ? await prefs.remove(_reportSettingsKey)
        : await prefs.setString(_reportSettingsKey, raw);
    if (!restored) {
      throw StateError('Gagal memulihkan pengaturan laporan sebelumnya.');
    }
  }

  Future<void> saveReportSettings(ReportSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _reportSettingsKey,
      jsonEncode(settings.toJson()),
    );
    if (!saved) {
      throw StateError('Gagal menyimpan pengaturan laporan ke penyimpanan aplikasi.');
    }
  }
}
