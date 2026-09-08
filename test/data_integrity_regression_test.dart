import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../lib/models/barang_item.dart';
import '../lib/models/pengiriman.dart';

void main() {
  group('data integrity regression', () {
    test('zero dimensions and weight remain valid and formulas stay stable', () {
      const item = BarangItem(
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
      const item = BarangItem(
        id: '1',
        nama: 'Box',
        jumlah: 3,
        panjang: 100,
        lebar: 50,
        tinggi: 40,
        berat: 2.5,
      );
      expect(item.volume, closeTo(12, 0.000001));
      expect(item.kubikasi, closeTo(0.6, 0.000001));
      expect(item.totalBerat, closeTo(7.5, 0.000001));
    });

    test('copyWith preserves photo unless explicitly cleared', () {
      const item = BarangItem(
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
        barang: const [
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
  });
}
