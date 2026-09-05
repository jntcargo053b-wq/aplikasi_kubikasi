import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/pengiriman.dart';
import '../models/report_settings.dart';
import 'settings_service.dart';
import 'storage_service.dart';

/// Portable, offline backup for shipment data, report settings, and app-owned
/// photos. The backup is a single UTF-8 JSON file with a .ncbak extension.
class BackupService {
  static const format = 'nextcube-backup';
  static const version = 1;

  final StorageService _storage;
  final SettingsService _settings;

  BackupService({StorageService? storage, SettingsService? settings})
      : _storage = storage ?? StorageService(),
        _settings = settings ?? SettingsService();

  Future<File> createBackup() async {
    final items = await _storage.loadPengiriman();
    final settings = await _settings.loadReportSettings();
    final files = <String, String>{};

    final photoPaths = items
        .expand((e) => e.barang)
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toSet();
    for (final path in photoPaths) {
      final file = File(path);
      if (await file.exists()) {
        files[path] = base64Encode(await file.readAsBytes());
      }
    }

    final logoPath = settings.logoPath;
    String? logoData;
    if (logoPath != null && logoPath.trim().isNotEmpty) {
      final file = File(logoPath);
      if (await file.exists()) logoData = base64Encode(await file.readAsBytes());
    }

    final payload = <String, dynamic>{
      'format': format,
      'version': version,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'counts': {
        'shipments': items.length,
        'items': items.fold<int>(0, (sum, e) => sum + e.barang.length),
        'photos': files.length,
      },
      'shipments': items.map((e) => e.toJson()).toList(),
      'reportSettings': settings.toJson(),
      'photos': files.map((key, value) => MapEntry(key, value)),
      'logoData': logoData,
    };

    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now();
    final name = 'nextcube_backup_${stamp.year.toString().padLeft(4, '0')}'
        '${stamp.month.toString().padLeft(2, '0')}'
        '${stamp.day.toString().padLeft(2, '0')}_'
        '${stamp.hour.toString().padLeft(2, '0')}'
        '${stamp.minute.toString().padLeft(2, '0')}.ncbak';
    final file = File('${docs.path}/$name');
    await file.writeAsString(jsonEncode(payload), flush: true);
    return file;
  }

  Future<BackupData> readBackup(File file) async {
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Format backup tidak valid.');
    if (decoded['format'] != format) {
      throw const FormatException('File bukan backup Nextcube yang valid.');
    }
    final backupVersion = (decoded['version'] as num?)?.toInt();
    if (backupVersion != version) {
      throw FormatException('Versi backup tidak didukung: ${decoded['version']}');
    }

    final rawShipments = decoded['shipments'];
    if (rawShipments is! List) {
      throw const FormatException('Data pengiriman pada backup tidak valid.');
    }
    final rawPhotos = decoded['photos'];
    final photoData = <String, String>{};
    if (rawPhotos is Map) {
      for (final entry in rawPhotos.entries) {
        if (entry.key is String && entry.value is String) {
          photoData[entry.key as String] = entry.value as String;
        }
      }
    }

    final shipments = <Pengiriman>[];
    for (final rawShipment in rawShipments) {
      if (rawShipment is! Map) continue;
      try {
        final shipment = Pengiriman.fromJson(
          Map<String, dynamic>.from(rawShipment),
        );
        if (shipment.pengirim.trim().isEmpty ||
            shipment.nomorResi.trim().isEmpty ||
            shipment.barang.isEmpty) {
          continue;
        }
        shipments.add(shipment);
      } catch (_) {}
    }

    final rawSettings = decoded['reportSettings'];
    final settings = rawSettings is Map
        ? ReportSettings.fromJson(Map<String, dynamic>.from(rawSettings))
        : const ReportSettings();
    final logoData = decoded['logoData'] as String?;

    return BackupData(
      shipments: shipments,
      settings: settings,
      photoData: photoData,
      logoData: logoData,
      createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? ''),
    );
  }
}

class BackupData {
  final List<Pengiriman> shipments;
  final ReportSettings settings;
  final Map<String, String> photoData;
  final String? logoData;
  final DateTime? createdAt;

  const BackupData({
    required this.shipments,
    required this.settings,
    required this.photoData,
    required this.logoData,
    required this.createdAt,
  });
}
