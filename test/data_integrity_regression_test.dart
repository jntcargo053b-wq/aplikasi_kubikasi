import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/models/pengiriman.dart';
import 'package:volume_calculator/models/report_settings.dart';
import 'package:volume_calculator/services/export_service.dart';
import 'package:volume_calculator/services/backup_service.dart';
import 'package:volume_calculator/services/storage_service.dart';
import 'package:volume_calculator/services/settings_service.dart';
import 'package:volume_calculator/services/photo_storage_service.dart';


class _FailOnceSettingsService extends SettingsService {
  bool _shouldFail = true;

  @override
  Future<void> saveReportSettings(ReportSettings settings) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('Injected settings persistence failure for regression test.');
    }
    await super.saveReportSettings(settings);
  }
}

class _PersistThenFailSettingsRollbackService extends SettingsService {
  @override
  Future<void> saveReportSettings(ReportSettings settings) async {
    await super.saveReportSettings(settings);
    throw StateError('Injected post-write settings failure for regression test.');
  }

  @override
  Future<void> restoreRawReportSettings(String? raw) async {
    throw StateError('Injected settings rollback failure for regression test.');
  }
}

class _FailRollbackStorageService extends StorageService {
  var _saveCount = 0;

  @override
  Future<void> savePengiriman(List<Pengiriman> items) async {
    _saveCount++;
    if (_saveCount == 2) {
      throw StateError('Injected shipment rollback failure for regression test.');
    }
    await super.savePengiriman(items);
  }
}

BackupData _photoAndLogoBackupData() {
  final photoBytes = utf8.encode('restored-photo-bytes');
  final logoBytes = utf8.encode('restored-logo-bytes');
  final shipment = Pengiriman(
    id: 'restore-photo-logo-shipment',
    pengirim: 'Restore Test',
    tanggal: DateTime(2026, 10, 13),
    nomorResi: 'RESTORE-PHOTO-LOGO-001',
    barang: [
      BarangItem(
        id: 'restore-photo-logo-item',
        nama: 'Box',
        jumlah: 1,
        panjang: 10,
        lebar: 10,
        tinggi: 10,
        berat: 1,
        photoPath: '/backup/source-photo.jpg',
      ),
    ],
  );
  return BackupData(
    shipments: [shipment],
    settings: const ReportSettings(
      companyName: 'Restore Test',
      headerNote: 'Backup recovery test',
      reportTitle: 'RESTORE TEST',
      logoPath: '/backup/source-logo.png',
    ),
    photoData: {
      '/backup/source-photo.jpg': base64Encode(photoBytes),
    },
    logoData: base64Encode(logoBytes),
    createdAt: DateTime.utc(2026, 10, 13),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('data integrity regression', () {
    test('shipment storage rejects malformed JSON instead of returning empty data', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': '{broken-json',
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('shipment storage rejects invalid records instead of silently dropping them', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([
          {
            'id': 'valid-looking-but-incomplete',
            'pengirim': 'Sender',
            'nomorResi': '',
            'tanggal': '2026-09-24T00:00:00.000',
            'barang': [],
          },
        ]),
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('backup import rejects invalid shipment dates', () async {
      final file = File(
        '${Directory.systemTemp.path}/backup-invalid-shipment-date-test.json',
      );
      await file.writeAsString(jsonEncode({
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': null,
        'counts': {'shipments': 1, 'items': 1, 'photos': 0},
        'shipments': [
          {
            'id': 'backup-invalid-date',
            'pengirim': 'Sender',
            'nomorResi': 'INVALID-DATE',
            'tanggal': 'not-a-date',
            'barang': [
              {
                'id': 'item-1',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 10,
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
            ],
          },
        ],
        'reportSettings': const ReportSettings().toJson(),
        'photos': <String, String>{},
        'logoData': null,
        'integrity': <String, String>{},
      }));

      await expectLater(
        BackupService().readBackup(file),
        throwsA(isA<FormatException>()),
      );
      await file.delete();
    });

    test('backup import rejects malformed items instead of silently dropping them', () async {
      final file = File(
        '${Directory.systemTemp.path}/backup-malformed-item-test.json',
      );
      await file.writeAsString(jsonEncode({
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': null,
        'counts': {'shipments': 1, 'items': 2, 'photos': 0},
        'shipments': [
          {
            'id': 'backup-malformed-item',
            'pengirim': 'Sender',
            'nomorResi': 'DAMAGED-ITEM',
            'tanggal': '2026-09-24T00:00:00.000',
            'barang': [
              {
                'id': 'item-1',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 10,
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
              {'id': 'item-2', 'nama': 'Damaged box', 'jumlah': 'invalid'},
            ],
          },
        ],
        'reportSettings': const ReportSettings().toJson(),
        'photos': <String, String>{},
        'logoData': null,
        'integrity': <String, String>{},
      }));

      await expectLater(
        BackupService().readBackup(file),
        throwsA(isA<FormatException>()),
      );
      await file.delete();
    });

    test('shipment storage rejects an invalid date instead of substituting the current date', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([
          {
            'id': 'shipment-with-invalid-date',
            'pengirim': 'Sender',
            'nomorResi': 'INVALID-DATE',
            'tanggal': 'not-a-date',
            'barang': [
              {
                'id': 'item-1',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 10,
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
            ],
          },
        ]),
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('shipment storage rejects a missing date instead of substituting the current date', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([
          {
            'id': 'shipment-without-date',
            'pengirim': 'Sender',
            'nomorResi': 'MISSING-DATE',
            'barang': [
              {
                'id': 'item-1',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 10,
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
            ],
          },
        ]),
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('shipment storage rejects a shipment when one malformed item would be dropped', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([
          {
            'id': 'shipment-with-damaged-item',
            'pengirim': 'Sender',
            'nomorResi': 'RESI-DAMAGED-ITEM',
            'tanggal': '2026-09-24T00:00:00.000',
            'barang': [
              {
                'id': 'valid-item',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 10,
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
              {
                'id': 'damaged-item',
                'nama': 'Damaged box',
                'jumlah': 'not-a-number',
              },
            ],
          },
        ]),
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('shipment storage roundtrip preserves shipment fields and item photo', () async {
      final shipment = Pengiriman(
        id: 'storage-roundtrip-1',
        pengirim: 'Budi',
        noTelepon: '08123456789',
        tanggal: DateTime(2026, 10, 2, 14, 30),
        nomorResi: 'ROUNDTRIP001',
        kotaKabupaten: 'Kota Malang',
        kecamatan: 'Klojen',
        barang: [
          BarangItem(
            id: 'item-roundtrip-1',
            nama: 'Kardus',
            jumlah: 3,
            panjang: 40,
            lebar: 30,
            tinggi: 20,
            berat: 2.5,
            photoPath: '/documents/barang_roundtrip.jpg',
          ),
        ],
      );

      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.savePengiriman([shipment]);

      final restored = await storage.loadPengiriman();

      expect(restored, hasLength(1));
      final actual = restored.single;
      expect(actual.id, shipment.id);
      expect(actual.pengirim, shipment.pengirim);
      expect(actual.noTelepon, shipment.noTelepon);
      expect(actual.tanggal, shipment.tanggal);
      expect(actual.nomorResi, shipment.nomorResi);
      expect(actual.kotaKabupaten, shipment.kotaKabupaten);
      expect(actual.kecamatan, shipment.kecamatan);
      expect(actual.barang, hasLength(1));
      expect(actual.barang.single.id, 'item-roundtrip-1');
      expect(actual.barang.single.photoPath, shipment.barang.single.photoPath);
      expect(actual.barang.single.jumlah, 3);
    });

    test('shipment storage rejects malformed item numeric types before data can be silently defaulted', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([
          {
            'id': 'shipment-malformed-dimension',
            'pengirim': 'Sender',
            'nomorResi': 'RESI-MALFORMED-DIMENSION',
            'tanggal': '2026-10-02T00:00:00.000',
            'barang': [
              {
                'id': 'item-1',
                'nama': 'Box',
                'jumlah': 1,
                'panjang': 'not-a-number',
                'lebar': 10,
                'tinggi': 10,
                'berat': 1,
              },
            ],
          },
        ]),
      });

      await expectLater(
        StorageService().loadPengiriman(),
        throwsA(isA<FormatException>()),
      );
    });

    test('shipment storage returns empty list only when no current data exists', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await StorageService().loadPengiriman(), isEmpty);
    });
    test('full backup restore recovers when current shipment JSON is corrupted', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': '{broken-json',
      });
      final shipment = Pengiriman(
        id: 'restore-recovery-1',
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 27),
        nomorResi: 'RECOVER001',
        barang: [
          BarangItem(
            id: 'restore-item-1',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
          ),
        ],
      );
      const backup = BackupData(
        shipments: [],
        settings: ReportSettings(),
        photoData: {},
        logoData: null,
        createdAt: null,
      );
      final data = BackupData(
        shipments: [shipment],
        settings: backup.settings,
        photoData: backup.photoData,
        logoData: backup.logoData,
        createdAt: backup.createdAt,
      );

      final result = await BackupService().restore(data, merge: false);

      expect(result.restoredShipments, 1);
      expect((await StorageService().loadPengiriman()).single.nomorResi, 'RECOVER001');
    });

    test('merge refuses corrupted shipment storage and preserves raw data', () async {
      const corrupted = '{broken-json';
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': corrupted,
      });
      const data = BackupData(
        shipments: [],
        settings: ReportSettings(),
        photoData: {},
        logoData: null,
        createdAt: null,
      );

      await expectLater(
        BackupService().restore(data, merge: true),
        throwsA(isA<FormatException>()),
      );
      expect(await StorageService().readRawShipmentData(), corrupted);
    });

    test('zero dimensions and weight remain valid and formulas stay stable', () {
      final item = BarangItem(
        id: '1',
        nama: 'Box',
        jumlah: 2,
        panjang: 0,
        lebar: 10,
        tinggi: 20,
        berat: 0,
      );
      expect(item.volume, 0);
      expect(item.kubikasi, 0);
      expect(item.totalBerat, 0);
    });

    test('volume, kubikasi and total weight use quantity correctly', () {
      final item = BarangItem(
        id: '1',
        nama: 'Box',
        jumlah: 3,
        panjang: 100,
        lebar: 50,
        tinggi: 40,
        berat: 2.5,
      );
      // 100 x 50 x 40 / 5000 x 3 = 120 kg volumetric weight.
      expect(item.volume, closeTo(120, 0.000001));
      // 100 x 50 x 40 / 1,000,000 x 3 = 0.6 m³.
      expect(item.kubikasi, closeTo(0.6, 0.000001));
      // 2.5 x 3 = 7.5 kg.
      expect(item.totalBerat, closeTo(7.5, 0.000001));
    });

    test('copyWith preserves photo unless explicitly cleared', () {
      final item = BarangItem(
        id: '1',
        nama: 'Box',
        jumlah: 1,
        panjang: 10,
        lebar: 10,
        tinggi: 10,
        berat: 1,
        photoPath: '/docs/photo.jpg',
      );
      expect(item.copyWith(nama: 'Updated').photoPath, '/docs/photo.jpg');
      expect(item.copyWith(clearPhoto: true).photoPath, isNull);
    });

    test('shipment JSON roundtrip preserves sender phone destination resi and photos', () {
      final original = Pengiriman(
        id: 'shipment-1',
        pengirim: 'Budi',
        noTelepon: '08123456789',
        tanggal: DateTime(2026, 9, 8),
        nomorResi: 'RESI123',
        kotaKabupaten: 'Kota Malang',
        kecamatan: 'Klojen',
        barang: [
          BarangItem(
            id: 'item-1',
            nama: 'Box',
            jumlah: 2,
            panjang: 20,
            lebar: 10,
            tinggi: 5,
            berat: 1.5,
            photoPath: '/docs/photo.jpg',
          ),
        ],
      );
      final restored = Pengiriman.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, original.id);
      expect(restored.pengirim, original.pengirim);
      expect(restored.noTelepon, original.noTelepon);
      expect(restored.tanggal, original.tanggal);
      expect(restored.nomorResi, original.nomorResi);
      expect(restored.kotaKabupaten, original.kotaKabupaten);
      expect(restored.kecamatan, original.kecamatan);
      expect(restored.barang.single.photoPath, '/docs/photo.jpg');
    });

    test('legacy shipment JSON without new fields remains readable', () {
      final legacy = <String, dynamic>{
        'id': 'legacy-1',
        'pengirim': 'Lama',
        'tanggal': '2026-09-01T00:00:00.000',
        'nomorResi': 'OLD123',
        'barang': [
          {
            'id': 'item-1',
            'nama': 'Box',
            'jumlah': 1,
            'panjang': 10,
            'lebar': 10,
            'tinggi': 10,
            'berat': 1,
          },
        ],
      };
      final restored = Pengiriman.fromJson(legacy);
      expect(restored.pengirim, 'Lama');
      expect(restored.noTelepon, isEmpty);
      expect(restored.kotaKabupaten, isEmpty);
      expect(restored.kecamatan, isEmpty);
    });
    test('backup merge duplicate protection preserves first valid record', () {
      Pengiriman shipment(String id, String resi) => Pengiriman(
        id: id,
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 22),
        nomorResi: resi,
        barang: [
          BarangItem(
            id: 'item-$id',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
          ),
        ],
      );

      final selected = selectShipmentsForMerge(
        [shipment('existing', 'OLD')],
        [
          shipment('a', 'NEW'),
          shipment('b', 'new'),
          shipment('c', 'OTHER'),
          shipment('c', 'OTHER2'),
        ],
      );

      expect(selected.map((e) => e.id), ['a', 'c']);
      expect(selected.map((e) => e.nomorResi), ['NEW', 'OTHER']);
    });

    test('backup merge rejects duplicate IDs and receipt numbers within incoming data', () {
      Pengiriman shipment(String id, String resi) => Pengiriman(
        id: id,
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 22),
        nomorResi: resi,
        barang: [
          BarangItem(
            id: 'item-$id',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
          ),
        ],
      );

      final existing = [shipment('existing-id', 'EXISTING')];
      final incoming = [
        shipment('new-1', 'NEW001'),
        shipment('new-2', 'NEW001'),
        shipment('existing-id', 'NEW002'),
        shipment('new-3', 'EXISTING'),
        shipment('new-4', 'NEW004'),
      ];

      final selected = selectShipmentsForMerge(existing, incoming);

      expect(selected.map((e) => e.id), ['new-1', 'new-4']);
      expect(selected.map((e) => e.nomorResi), ['NEW001', 'NEW004']);
    });

    test('merge with all incoming records duplicated becomes a no-op selection', () {
      Pengiriman shipment(String id, String resi) => Pengiriman(
        id: id,
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 22),
        nomorResi: resi,
        barang: [
          BarangItem(
            id: 'item-$id',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
          ),
        ],
      );

      final existing = [
        shipment('id-1', 'RESI001'),
        shipment('id-2', 'RESI002'),
      ];
      final incoming = [
        shipment('id-1', 'NEW001'),
        shipment('new-2', 'resi002'),
      ];

      final selected = selectShipmentsForMerge(existing, incoming);

      expect(selected, isEmpty);
    });

    test('empty full backup is accepted by duplicate validation', () {
      expect(
        () => validateFullRestoreShipments(const <Pengiriman>[]),
        returnsNormally,
      );
    });

    test('backup filename timestamp precision includes sub-minute uniqueness', () {
      final stamp = DateTime(2026, 9, 24, 2, 31, 45, 123, 456);
      final name = formatBackupFilename(stamp);
      expect(name, endsWith('_023145_123456.ncbak'));
      expect(name, isNot(endsWith('_31.ncbak')));
    });

    test('backup read rejects corrupted photo payload and checksum mismatch', () async {
      final shipment = Pengiriman(
        id: 'backup-test-1',
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 24),
        nomorResi: 'RESI-BACKUP-1',
        barang: [
          BarangItem(
            id: 'item-1',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
            photoPath: '/app/photo.jpg',
          ),
        ],
      );
      final photoBytes = utf8.encode('photo-data');
      final encodedPhoto = base64Encode(photoBytes);
      final payload = <String, dynamic>{
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': '2026-09-24T00:00:00.000Z',
        'counts': {'shipments': 1, 'items': 1, 'photos': 1},
        'shipments': [shipment.toJson()],
        'reportSettings': {
          'companyName': '',
          'headerNote': '',
          'logoPath': null,
          'reportTitle': '',
        },
        'photos': {'/app/photo.jpg': encodedPhoto},
        'logoData': null,
        'integrity': {'photo:/app/photo.jpg': 'invalid-checksum'},
      };
      final file = File(
        '${Directory.systemTemp.path}/nextcube-backup-corrupt-test.ncbak',
      );
      await file.writeAsString(jsonEncode(payload), flush: true);
      try {
        await expectLater(
          BackupService().readBackup(file),
          throwsA(isA<FormatException>()),
        );
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('backup read rejects shipment photo reference missing from payload', () async {
      final shipment = Pengiriman(
        id: 'backup-test-2',
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 24),
        nomorResi: 'RESI-BACKUP-2',
        barang: [
          BarangItem(
            id: 'item-2',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
            photoPath: '/app/missing.jpg',
          ),
        ],
      );
      final payload = <String, dynamic>{
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': '2026-09-24T00:00:00.000Z',
        'counts': {'shipments': 1, 'items': 1, 'photos': 0},
        'shipments': [shipment.toJson()],
        'reportSettings': {
          'companyName': '',
          'headerNote': '',
          'logoPath': null,
          'reportTitle': '',
        },
        'photos': <String, String>{},
        'logoData': null,
        'integrity': <String, String>{},
      };
      final file = File(
        '${Directory.systemTemp.path}/nextcube-backup-missing-photo-test.ncbak',
      );
      await file.writeAsString(jsonEncode(payload), flush: true);
      try {
        await expectLater(
          BackupService().readBackup(file),
          throwsA(isA<FormatException>()),
        );
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('backup read rejects inconsistent logo reference and payload', () async {
      final payload = <String, dynamic>{
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': null,
        'counts': {'shipments': 0, 'items': 0, 'photos': 0},
        'shipments': <Map<String, dynamic>>[],
        'reportSettings': {
          'companyName': 'Nextcube',
          'headerNote': '',
          'logoPath': '/old/logo.jpg',
          'reportTitle': 'LAPORAN',
        },
        'photos': <String, String>{},
        'logoData': null,
        'integrity': <String, String>{},
      };
      final file = File(
        '${Directory.systemTemp.path}/nextcube-backup-logo-mismatch-test.ncbak',
      );
      await file.writeAsString(jsonEncode(payload), flush: true);
      try {
        await expectLater(
          BackupService().readBackup(file),
          throwsA(isA<FormatException>()),
        );
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
    test('backup read rejects missing logo reference, invalid payload type and bad checksum', () async {
      final logoBytes = utf8.encode('company-logo-test');
      final encodedLogo = base64Encode(logoBytes);

      Map<String, dynamic> payload({
        Object? logoPath,
        Object? logoData = 'logo-payload',
        String? checksum,
      }) => <String, dynamic>{
        'format': BackupService.format,
        'version': BackupService.version,
        'createdAt': null,
        'counts': {'shipments': 0, 'items': 0, 'photos': 0},
        'shipments': <Map<String, dynamic>>[],
        'reportSettings': {
          'companyName': 'Nextcube',
          'headerNote': '',
          'logoPath': logoPath,
          'reportTitle': ReportSettings.defaultTitle,
        },
        'photos': <String, String>{},
        'logoData': logoData,
        'integrity': <String, String>{
          if (checksum != null) 'logo': checksum,
        },
      };

      final cases = <({String name, Map<String, dynamic> payload})>[
        (
          name: 'without-reference',
          payload: payload(logoData: encodedLogo, checksum: sha256.convert(logoBytes).toString()),
        ),
        (
          name: 'wrong-type',
          payload: payload(logoPath: '/old/logo.jpg', logoData: 42),
        ),
        (
          name: 'bad-checksum',
          payload: payload(logoPath: '/old/logo.jpg', logoData: encodedLogo, checksum: 'invalid'),
        ),
      ];

      for (final entry in cases) {
        final file = File(
          '${Directory.systemTemp.path}/nextcube-backup-logo-${entry.name}-test.ncbak',
        );
        await file.writeAsString(jsonEncode(entry.payload), flush: true);
        try {
          await expectLater(
            BackupService().readBackup(file),
            throwsA(isA<FormatException>()),
            reason: entry.name,
          );
        } finally {
          if (await file.exists()) await file.delete();
        }
      }
    });

    test('backup creation timestamp validation accepts valid and legacy values', () {
      final parsed = parseBackupCreatedAt('2026-09-23T11:44:18.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.toUtc().year, 2026);

      expect(parseBackupCreatedAt(null), isNull);
      expect(parseBackupCreatedAt(''), isNull);
      expect(parseBackupCreatedAt('   '), isNull);

      expect(
        () => parseBackupCreatedAt('not-a-date'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseBackupCreatedAt(12345),
        throwsA(isA<FormatException>()),
      );
    });

    test('backup report settings validation rejects malformed values', () {
      final settings = parseBackupReportSettings({
        'companyName': 'Nextcube',
        'headerNote': 'Malang',
        'logoPath': null,
        'reportTitle': 'LAPORAN',
      });
      expect(settings.companyName, 'Nextcube');
      expect(settings.reportTitle, 'LAPORAN');

      expect(
        () => parseBackupReportSettings({
          'companyName': 123,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseBackupReportSettings('invalid'),
        throwsA(isA<FormatException>()),
      );
    });


    test('photo cleanup deletes only unreferenced app-owned files', () async {
      final docs = await Directory.systemTemp.createTemp('nextcube-photo-cleanup-docs-');
      final external = await Directory.systemTemp.createTemp('nextcube-photo-cleanup-external-');
      final referencedFile = File('${docs.path}/referenced.jpg');
      final orphanFile = File('${docs.path}/orphan.jpg');
      final externalFile = File('${external.path}/external.jpg');
      await referencedFile.writeAsString('referenced');
      await orphanFile.writeAsString('orphan');
      await externalFile.writeAsString('external');

      final shipment = Pengiriman(
        id: 'photo-cleanup-reference',
        pengirim: 'Sender',
        tanggal: DateTime(2026, 10, 13),
        nomorResi: 'PHOTO-CLEANUP-001',
        barang: [
          BarangItem(
            id: 'photo-cleanup-item',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
            photoPath: referencedFile.path,
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([shipment.toJson()]),
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        await PhotoStorageService.deleteAll([
          referencedFile.path,
          orphanFile.path,
          externalFile.path,
        ]);

        expect(await referencedFile.exists(), isTrue,
            reason: 'A photo referenced by persisted shipment data must remain.');
        expect(await orphanFile.exists(), isFalse,
            reason: 'An unreferenced photo owned by the app should be cleaned up.');
        expect(await externalFile.exists(), isTrue,
            reason: 'Cleanup must never delete a file outside app documents.');
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
        await external.delete(recursive: true);
      }
    });

    test('photo cleanup fails closed when persisted shipment data is corrupted', () async {
      final docs = await Directory.systemTemp.createTemp('nextcube-photo-cleanup-corrupt-');
      final orphanFile = File('${docs.path}/orphan.jpg');
      await orphanFile.writeAsString('orphan');
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': '{broken-json',
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        await PhotoStorageService.deleteAll([orphanFile.path]);
        expect(await orphanFile.exists(), isTrue,
            reason: 'Cleanup must preserve files when references cannot be read safely.');
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
      }
    });

    test('full restore writes photo and report logo bytes and remaps references', () async {
      SharedPreferences.setMockInitialValues({});
      final docs = await Directory.systemTemp.createTemp('nextcube-restore-success-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        final result = await BackupService().restore(
          _photoAndLogoBackupData(),
          merge: false,
        );
        final restored = (await StorageService().loadPengiriman()).single;
        final photoPath = restored.barang.single.photoPath;
        expect(photoPath, isNotNull);
        expect(photoPath, isNot('/backup/source-photo.jpg'));
        expect(await File(photoPath!).exists(), isTrue);
        expect(await File(photoPath).readAsBytes(), utf8.encode('restored-photo-bytes'));

        expect(result.restoredPhotos, 1);
        expect(result.restoredShipments, 1);
        expect(result.settings.companyName, 'Restore Test');
        final logoPath = result.settings.logoPath;
        expect(logoPath, isNotNull);
        expect(logoPath, isNot('/backup/source-logo.png'));
        expect(await File(logoPath!).exists(), isTrue);
        expect(await File(logoPath).readAsBytes(), utf8.encode('restored-logo-bytes'));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
      }
    });

    test('failed settings write rolls shipment state back and removes new photo and logo', () async {
      const corruptedSettings = '{broken-settings-json';
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([]),
        'report_header_settings_v1': corruptedSettings,
      });
      final docs = await Directory.systemTemp.createTemp('nextcube-restore-rollback-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        final service = BackupService(settings: _FailOnceSettingsService());
        await expectLater(
          service.restore(_photoAndLogoBackupData(), merge: false),
          throwsA(isA<StateError>()),
        );

        expect(await StorageService().loadPengiriman(), isEmpty);
        final files = docs.existsSync()
            ? docs.listSync(recursive: true).whereType<File>().toList()
            : <File>[];
        expect(files, isEmpty, reason: 'Rollback must remove files created by the failed restore.');
        expect(await SettingsService().loadReportSettings(), isEmpty);
        expect(
          (await SharedPreferences.getInstance())
              .getString('report_header_settings_v1'),
          corruptedSettings,
          reason: 'Failed restore must preserve the exact prior settings value.',
        );
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
      }
    });

    test('failed settings rollback preserves logo still referenced by persisted settings', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([]),
        'report_header_settings_v1': jsonEncode(ReportSettings().toJson()),
      });
      final docs = await Directory.systemTemp.createTemp('nextcube-restore-settings-rollback-failure-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        final service = BackupService(
          settings: _PersistThenFailSettingsRollbackService(),
        );
        await expectLater(
          service.restore(_photoAndLogoBackupData(), merge: false),
          throwsA(isA<StateError>()),
        );

        expect(await StorageService().loadPengiriman(), isEmpty,
            reason: 'Shipment rollback should still restore the previous shipment state.');
        final persistedSettings = await SettingsService().loadReportSettings();
        expect(persistedSettings.companyName, 'Restore Test');
        final logoPath = persistedSettings.logoPath;
        expect(logoPath, isNotNull);
        expect(await File(logoPath!).exists(), isTrue,
            reason: 'If settings rollback fails, a persisted logo reference must not become dangling.');
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
      }
    });

    test('failed shipment rollback preserves files still referenced by persisted restore', () async {
      SharedPreferences.setMockInitialValues({
        'daftar_pengiriman_v2': jsonEncode([]),
      });
      final docs = await Directory.systemTemp.createTemp('nextcube-restore-rollback-failure-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return docs.path;
        return null;
      });

      try {
        final service = BackupService(
          storage: _FailRollbackStorageService(),
          settings: _FailOnceSettingsService(),
        );
        await expectLater(
          service.restore(_photoAndLogoBackupData(), merge: false),
          throwsA(isA<StateError>()),
        );

        // The first shipment write succeeded, but the rollback write failed.
        // Therefore the stored restore still points at the new photo and that
        // photo must not be removed by failure cleanup.
        final persisted = (await StorageService().loadPengiriman()).single;
        final photoPath = persisted.barang.single.photoPath;
        expect(photoPath, isNotNull);
        expect(await File(photoPath!).exists(), isTrue);
        expect(await File(photoPath).readAsBytes(), utf8.encode('restored-photo-bytes'));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await docs.delete(recursive: true);
      }
    });

    test('full restore rejects duplicate shipment IDs and receipt numbers', () {
      Pengiriman shipment(String id, String resi) => Pengiriman(
        id: id,
        pengirim: 'Sender',
        tanggal: DateTime(2026, 9, 22),
        nomorResi: resi,
        barang: [
          BarangItem(
            id: 'item-$id',
            nama: 'Box',
            jumlah: 1,
            panjang: 10,
            lebar: 10,
            tinggi: 10,
            berat: 1,
          ),
        ],
      );

      expect(
        () => validateFullRestoreShipments([
          shipment('same-id', 'RESI001'),
          shipment('same-id', 'RESI002'),
        ]),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => validateFullRestoreShipments([
          shipment('id-1', 'RESI001'),
          shipment('id-2', 'resi001'),
        ]),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => validateFullRestoreShipments([
          shipment('id-1', 'RESI001'),
          shipment('id-2', 'RESI002'),
        ]),
        returnsNormally,
      );
    });

    test('combined report photo quota is distributed round-robin', () {
      final quotas = allocatePhotoQuotasRoundRobin(
        [const MapEntry('A', 50), const MapEntry('B', 10), const MapEntry('C', 10)],
        6,
      );
      expect(quotas, {'A': 2, 'B': 2, 'C': 2});
    });

    test('combined report photo cap distinguishes exact limit from truncation', () {
      final exact = allocatePhotoQuotasRoundRobin(
        [const MapEntry('A', 30), const MapEntry('B', 30)],
        60,
      );
      final over = allocatePhotoQuotasRoundRobin(
        [const MapEntry('A', 31), const MapEntry('B', 30)],
        60,
      );
      expect(exact, {'A': 30, 'B': 30});
      expect(over.values.fold<int>(0, (sum, value) => sum + value), 60);
      expect(over['A']! < 31 || over['B']! < 30, isTrue);
    });
  });
}
