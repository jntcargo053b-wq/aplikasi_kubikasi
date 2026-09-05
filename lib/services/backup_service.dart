import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/barang_item.dart';
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

    String? logoData;
    final logoPath = settings.logoPath;
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
      'photos': files,
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
    if (decoded is! Map) {
      throw const FormatException('Format backup tidak valid.');
    }
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

    return BackupData(
      shipments: shipments,
      settings: settings,
      photoData: photoData,
      logoData: decoded['logoData'] as String?,
      createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? ''),
    );
  }

  Future<RestoreResult> restore(
    BackupData data, {
    required bool merge,
  }) async {
    final existing = await _storage.loadPengiriman();
    final existingIds = existing.map((e) => e.id).toSet();
    final selected = merge
        ? data.shipments.where((e) => !existingIds.contains(e.id)).toList()
        : List<Pengiriman>.of(data.shipments);

    final pathMap = <String, String>{};
    final restoredShipments = <Pengiriman>[];
    for (final shipment in selected) {
      final restoredBarang = <BarangItem>[];
      for (final item in shipment.barang) {
        final oldPath = item.photoPath;
        String? newPath;
        if (oldPath != null && data.photoData.containsKey(oldPath)) {
          newPath = pathMap[oldPath];
          if (newPath == null) {
            newPath = await _writePhoto(oldPath, data.photoData[oldPath]!);
            pathMap[oldPath] = newPath;
          }
        }
        restoredBarang.add(
          oldPath != null && newPath == null
              ? item.copyWith(clearPhoto: true)
              : item.copyWith(photoPath: newPath),
        );
      }
      restoredShipments.add(
        Pengiriman(
          id: shipment.id,
          pengirim: shipment.pengirim,
          tanggal: shipment.tanggal,
          nomorResi: shipment.nomorResi,
          kotaKabupaten: shipment.kotaKabupaten,
          kecamatan: shipment.kecamatan,
          barang: restoredBarang,
        ),
      );
    }

    final target = merge
        ? [...existing, ...restoredShipments]
        : restoredShipments;
    await _storage.savePengiriman(target);

    var settings = await _settings.loadReportSettings();
    if (!merge || settings.isEmpty) {
      String? logoPath;
      if (data.logoData != null && data.logoData!.isNotEmpty) {
        logoPath = await _writeLogo(data.logoData!);
      }
      settings = ReportSettings(
        companyName: data.settings.companyName,
        headerNote: data.settings.headerNote,
        logoPath: logoPath,
      );
      await _settings.saveReportSettings(settings);
    }

    return RestoreResult(
      restoredShipments: restoredShipments.length,
      restoredItems: restoredShipments.fold<int>(
        0,
        (sum, e) => sum + e.barang.length,
      ),
      restoredPhotos: pathMap.length,
      skippedDuplicates: merge ? data.shipments.length - selected.length : 0,
      settings: settings,
    );
  }

  Future<String> _writePhoto(String oldPath, String encoded) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/backup_photos');
    await dir.create(recursive: true);
    final extension = _extension(oldPath);
    final target = File(
      '${dir.path}/photo_${DateTime.now().microsecondsSinceEpoch}_'
      '${const Uuid().v4()}$extension',
    );
    await target.writeAsBytes(base64Decode(encoded), flush: true);
    return target.path;
  }

  Future<String> _writeLogo(String encoded) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/report_header');
    await dir.create(recursive: true);
    final target = File(
      '${dir.path}/company_logo_restore_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await target.writeAsBytes(base64Decode(encoded), flush: true);
    return target.path;
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return {'.jpg', '.jpeg', '.png', '.webp'}.contains(ext) ? ext : '.jpg';
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

class RestoreResult {
  final int restoredShipments;
  final int restoredItems;
  final int restoredPhotos;
  final int skippedDuplicates;
  final ReportSettings settings;

  const RestoreResult({
    required this.restoredShipments,
    required this.restoredItems,
    required this.restoredPhotos,
    required this.skippedDuplicates,
    required this.settings,
  });
}
