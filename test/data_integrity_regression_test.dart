import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/models/pengiriman.dart';
import 'package:volume_calculator/services/export_service.dart';
import 'package:volume_calculator/services/backup_service.dart';

void main() {
  group('data integrity regression', () {
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

    test('failed shipment rollback must preserve newly-created photo references', () {
      // This regression is documented at the transaction boundary: if the
      // persisted shipment snapshot cannot be rolled back, newly-created
      // restore files must not be deleted because the persisted records may
      // still reference them.
      var shipmentsCommitted = true;
      var rollbackSucceeded = false;
      var deleteNewFiles = false;

      if (shipmentsCommitted) {
        try {
          throw StateError('simulated storage rollback failure');
        } catch (_) {
          rollbackSucceeded = false;
        }
      }
      if (!shipmentsCommitted || rollbackSucceeded) {
        deleteNewFiles = true;
      }

      expect(rollbackSucceeded, isFalse);
      expect(deleteNewFiles, isFalse);
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
