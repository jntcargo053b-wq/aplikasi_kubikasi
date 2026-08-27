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

  Future<void> saveReportSettings(ReportSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reportSettingsKey, jsonEncode(settings.toJson()));
  }
}
