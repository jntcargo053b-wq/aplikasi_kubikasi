import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../models/report_settings.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'photo_storage_service.dart';

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
    final integrity = <String, String>{};

    final photoPaths = items
        .expand((e) => e.barang)
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toSet();
    final docs = await getApplicationDocumentsDirectory();

    for (final path in photoPaths) {
      if (!_isInsideDocuments(path, docs.path)) {
        throw FormatException(
          'Foto pengiriman berada di luar penyimpanan aplikasi dan tidak dapat dibackup: $path',
        );
      }
      final file = File(path);
      if (!await file.exists()) {
        throw FormatException(
          'Foto yang direferensikan pengiriman tidak ditemukan: $path',
        );
      }
      final bytes = await file.readAsBytes();
      files[path] = base64Encode(bytes);
      integrity['photo:$path'] = sha256.convert(bytes).toString();
    }

    String? logoData;
    final logoPath = settings.logoPath;
    if (logoPath != null && logoPath.trim().isNotEmpty) {
      // Report logos are app-owned files too. Never read an arbitrary path
      // outside the app documents directory while creating a backup.
      if (!_isInsideDocuments(logoPath, docs.path)) {
        throw FormatException(
          'Logo header laporan berada di luar penyimpanan aplikasi dan tidak dapat dibackup: $logoPath',
        );
      }
      final file = File(logoPath);
      if (!await file.exists()) {
        throw FormatException(
          'Logo header laporan yang direferensikan tidak ditemukan: $logoPath',
        );
      }
      final bytes = await file.readAsBytes();
      logoData = base64Encode(bytes);
      integrity['logo'] = sha256.convert(bytes).toString();
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
      'integrity': integrity,
    };

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

    final rawCounts = decoded['counts'];
    if (rawCounts is! Map) {
      throw const FormatException('Metadata jumlah data pada backup tidak valid.');
    }

    int readCount(String key) {
      final value = rawCounts[key];
      if (value is! num || value < 0 || value % 1 != 0) {
        throw FormatException('Jumlah $key pada backup tidak valid.');
      }
      return value.toInt();
    }

    final expectedShipmentCount = readCount('shipments');
    final expectedItemCount = readCount('items');
    final expectedPhotoCount = readCount('photos');

    final rawShipments = decoded['shipments'];
    if (rawShipments is! List) {
      throw const FormatException('Data pengiriman pada backup tidak valid.');
    }
    if (rawShipments.length != expectedShipmentCount) {
      throw const FormatException(
        'Jumlah pengiriman pada backup tidak sesuai metadata.',
      );
    }
    final rawPhotos = decoded['photos'];
    if (rawPhotos is! Map) {
      throw const FormatException('Data foto pada backup tidak valid.');
    }
    final photoData = <String, String>{};
    final integrity = decoded['integrity'];
    if (integrity is! Map) {
      throw const FormatException('Metadata integritas backup tidak valid.');
    }
    for (final entry in rawPhotos.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Data foto pada backup tidak valid.');
      }
      final path = entry.key as String;
      final encoded = entry.value as String;
      try {
        final bytes = base64Decode(encoded);
        final expected = integrity['photo:$path']?.toString();
        if (expected == null || expected.isEmpty) {
          throw const FormatException(
            'Checksum foto pada backup tidak ditemukan.',
          );
        }
        if (expected != sha256.convert(bytes).toString()) {
          throw const FormatException(
            'Checksum foto tidak cocok. Backup mungkin rusak.',
          );
        }
        photoData[path] = encoded;
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('Data foto pada backup tidak valid.');
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

    if (shipments.length != expectedShipmentCount) {
      throw const FormatException(
        'Data pengiriman pada backup mengandung record yang tidak valid.',
      );
    }

    // Every persisted photo reference must have a corresponding payload.
    // Restoring a backup with silently missing photos would otherwise clear
    // valid photo references and make the restore appear successful.
    for (final shipment in shipments) {
      for (final item in shipment.barang) {
        final path = item.photoPath;
        if (path != null &&
            path.trim().isNotEmpty &&
            !photoData.containsKey(path)) {
          throw FormatException(
            'Foto pengiriman tidak ditemukan di dalam backup: $path',
          );
        }
      }
    }

    if (photoData.length != expectedPhotoCount) {
      throw const FormatException(
        'Jumlah foto pada backup tidak sesuai metadata.',
      );
    }

    final actualItemCount =
        shipments.fold<int>(0, (sum, shipment) => sum + shipment.barang.length);
    if (actualItemCount != expectedItemCount) {
      throw const FormatException(
        'Jumlah item pada backup tidak sesuai metadata.',
      );
    }

    final rawLogoData = decoded['logoData'];
    if (rawLogoData != null && rawLogoData is! String) {
      throw const FormatException('Data logo pada backup tidak valid.');
    }
    final logoData = rawLogoData as String?;
    if (logoData != null && logoData.isNotEmpty) {
      try {
        final expected = integrity['logo']?.toString();
        if (expected == null || expected.isEmpty) {
          throw const FormatException(
            'Checksum logo pada backup tidak ditemukan.',
          );
        }
        final actual = sha256.convert(base64Decode(logoData)).toString();
        if (actual != expected) {
          throw const FormatException(
            'Checksum logo tidak cocok. Backup mungkin rusak.',
          );
        }
      } catch (e) {
        if (e is FormatException) rethrow;
        throw const FormatException('Data logo pada backup tidak valid.');
      }
    }

    final rawSettings = decoded['reportSettings'];
    final settings = parseBackupReportSettings(rawSettings);

    return BackupData(
      shipments: shipments,
      settings: settings,
      photoData: photoData,
      logoData: logoData,
      createdAt: DateTime.tryParse(decoded['createdAt'] as String? ?? ''),
    );
  }

  Future<RestoreResult> restore(
    BackupData data, {
    required bool merge,
  }) async {
    final existing = await _storage.loadPengiriman();
    if (!merge) {
      validateFullRestoreShipments(data.shipments);
    }
    final selected = merge
        ? selectShipmentsForMerge(existing, data.shipments)
        : List<Pengiriman>.of(data.shipments);

    // An empty backup is valid, but a restore must never turn it into an
    // implicit "delete everything" operation. Treat it as a safe no-op.
    if (!merge && data.shipments.isEmpty) {
      final settings = await _settings.loadReportSettings();
      return RestoreResult(
        restoredShipments: 0,
        restoredItems: 0,
        restoredPhotos: 0,
        skippedDuplicates: 0,
        settings: settings,
      );
    }

    // A merge whose incoming records all collide with existing ID/resi values
    // is also a no-op. Avoid rewriting storage or report settings when nothing
    // will actually be added.
    if (merge && selected.isEmpty) {
      final settings = await _settings.loadReportSettings();
      return RestoreResult(
        restoredShipments: 0,
        restoredItems: 0,
        restoredPhotos: 0,
        skippedDuplicates: data.shipments.length,
        settings: settings,
      );
    }

    final pathMap = <String, String>{};
    final createdPhotoPaths = <String>[];
    String? createdLogoPath;
    var shipmentsCommitted = false;

    // Snapshot the settings before restore so a later settings failure can
    // roll the complete restore back to the pre-restore state.
    final previousSettings = await _settings.loadReportSettings();
    final previousPhotoPaths = existing
        .expand((e) => e.barang)
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toSet();
    final previousLogoPath = previousSettings.logoPath;

    try {
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
              createdPhotoPaths.add(newPath);
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
            noTelepon: shipment.noTelepon,
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
      shipmentsCommitted = true;

      var settings = await _settings.loadReportSettings();
      if (!merge || settings.isEmpty) {
        String? logoPath;
        if (data.logoData != null && data.logoData!.isNotEmpty) {
          logoPath = await _writeLogo(data.logoData!);
          createdLogoPath = logoPath;
        }
        settings = ReportSettings(
          companyName: data.settings.companyName,
          headerNote: data.settings.headerNote,
          reportTitle: data.settings.reportTitle,
          logoPath: logoPath,
        );
        await _settings.saveReportSettings(settings);
      }

      // Replacing a full backup can orphan the previous shipment photos and
      // report logo. Clean them only after the new state is committed.
      if (!merge) {
        final currentPhotoPaths = target
            .expand((e) => e.barang)
            .map((b) => b.photoPath)
            .whereType<String>()
            .where((p) => p.trim().isNotEmpty)
            .toSet();
        await PhotoStorageService.deleteAll(
          previousPhotoPaths.difference(currentPhotoPaths),
        );
        if (previousLogoPath != null &&
            previousLogoPath.trim().isNotEmpty &&
            previousLogoPath != settings.logoPath) {
          await PhotoStorageService.delete(previousLogoPath);
        }
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
    } catch (_) {
      // Restore is treated as one logical transaction. If shipment data was
      // already persisted but report settings later failed, restore the
      // original shipment snapshot before removing newly-created files.
      //
      // If the shipment rollback itself fails, do NOT delete the newly-created
      // photos: the persisted shipment data may still reference them. Keeping
      // those files is safer than leaving persisted records pointing at files
      // that no longer exist.
      var shipmentRollbackSucceeded = !shipmentsCommitted;
      if (shipmentsCommitted) {
        try {
          await _storage.savePengiriman(existing);
          shipmentRollbackSucceeded = true;
        } catch (_) {
          // Preserve the original error. The persisted state may still be the
          // restored state, so its newly-created photos must remain intact.
        }
      }

      if (shipmentRollbackSucceeded) {
        await PhotoStorageService.deleteAll(createdPhotoPaths);
        if (createdLogoPath != null) {
          await PhotoStorageService.delete(createdLogoPath);
        }
      }

      try {
        await _settings.saveReportSettings(previousSettings);
      } catch (_) {
        // Preserve the original restore error.
      }
      rethrow;
    }
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

  bool _isInsideDocuments(String path, String documentsPath) {
    final normalizedPath = _normalizePath(path);
    final normalizedDocuments = _normalizePath(documentsPath);
    return normalizedPath == normalizedDocuments ||
        normalizedPath.startsWith('$normalizedDocuments/');
  }

  String _normalizePath(String path) {
    var value = path.trim().replaceAll('\\', '/');
    while (value.contains('//')) {
      value = value.replaceAll('//', '/');
    }
    if (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    return {'.jpg', '.jpeg', '.png', '.webp'}.contains(ext) ? ext : '.jpg';
  }
}

/// Parses and validates report settings from a backup payload.
///
/// The backup format is versioned, so silently replacing malformed settings
/// with defaults could make a restore appear successful while losing the
/// user's report configuration.
ReportSettings parseBackupReportSettings(Object? rawSettings) {
  if (rawSettings is! Map) {
    throw const FormatException('Pengaturan laporan pada backup tidak valid.');
  }
  final json = Map<String, dynamic>.from(rawSettings);
  for (final key in const ['companyName', 'headerNote', 'logoPath', 'reportTitle']) {
    final value = json[key];
    if (value != null && value is! String) {
      throw FormatException('Nilai pengaturan laporan tidak valid: $key');
    }
  }
  return ReportSettings.fromJson(json);
}


/// Validates that a full replacement restore does not silently lose records
/// because the backup itself contains duplicate shipment IDs or receipt
/// numbers. Merge restores intentionally use [selectShipmentsForMerge].
void validateFullRestoreShipments(List<Pengiriman> shipments) {
  final usedIds = <String>{};
  final usedResi = <String>{};

  for (final shipment in shipments) {
    if (!usedIds.add(shipment.id)) {
      throw FormatException(
        'Backup mengandung ID pengiriman duplikat: ${shipment.id}',
      );
    }

    final resi = shipment.nomorResi.trim().toLowerCase();
    if (resi.isNotEmpty && !usedResi.add(resi)) {
      throw FormatException(
        'Backup mengandung nomor resi duplikat: ${shipment.nomorResi}',
      );
    }
  }
}

/// Selects incoming shipments that do not collide with IDs or receipt numbers
/// already accepted during the merge. This also filters duplicate records
/// inside the backup itself, preserving the same uniqueness invariant as the
/// normal shipment form.
List<Pengiriman> selectShipmentsForMerge(
  List<Pengiriman> existing,
  List<Pengiriman> incoming,
) {
  final usedIds = existing.map((e) => e.id).toSet();
  final usedResi = existing
      .map((e) => e.nomorResi.trim().toLowerCase())
      .where((resi) => resi.isNotEmpty)
      .toSet();
  final selected = <Pengiriman>[];

  for (final shipment in incoming) {
    final id = shipment.id;
    final resi = shipment.nomorResi.trim().toLowerCase();
    if (usedIds.contains(id) ||
        (resi.isNotEmpty && usedResi.contains(resi))) {
      continue;
    }
    usedIds.add(id);
    if (resi.isNotEmpty) usedResi.add(resi);
    selected.add(shipment);
  }

  return selected;
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
