import 'package:flutter_test/flutter_test.dart';
import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/models/pengiriman.dart';

void main() {
  group('BarangItem data integrity', () {
    test('zero dimensions and weight are valid and calculate to zero', () {
      final item = BarangItem(
        id: 'b1',
        nama: 'Barang',
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

    test('calculation uses quantity without changing the stored inputs', () {
      final item = BarangItem(
        id: 'b2',
        nama: 'Paket',
        jumlah: 3,
        panjang: 50,
        lebar: 40,
        tinggi: 30,
        berat: 2.5,
      );

      expect(item.volume, closeTo(36, 1e-9));
      expect(item.kubikasi, closeTo(0.18, 1e-9));
      expect(item.totalBerat, closeTo(7.5, 1e-9));
      expect(item.panjang, 50);
      expect(item.lebar, 40);
      expect(item.tinggi, 30);
      expect(item.berat, 2.5);
      expect(item.jumlah, 3);
    });

    test('copyWith preserves photo path unless explicitly cleared', () {
      final item = BarangItem(
        id: 'b3',
        nama: 'Foto',
        jumlah: 1,
        panjang: 10,
        lebar: 10,
        tinggi: 10,
        photoPath: '/photos/item.jpg',
      );

      expect(item.copyWith(nama: 'Foto Baru').photoPath, '/photos/item.jpg');
      expect(item.copyWith(clearPhoto: true).photoPath, isNull);
    });
  });

  group('Pengiriman data integrity', () {
    test('serialization round-trip preserves sender, phone, destination and items', () {
      final original = Pengiriman(
        id: 'p1',
        pengirim: 'PT Contoh',
        noTelepon: '081234567890',
        tanggal: DateTime(2026, 9, 8, 10, 30),
        nomorResi: 'RESI-001',
        kotaKabupaten: 'Malang',
        kecamatan: 'Lowokwaru',
        barang: [
          BarangItem(
            id: 'b4',
            nama: 'Kardus',
            jumlah: 2,
            panjang: 20,
            lebar: 30,
            tinggi: 40,
            berat: 1.25,
            photoPath: '/photos/kardus.jpg',
          ),
        ],
      );

      final restored = Pengiriman.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.pengirim, original.pengirim);
      expect(restored.noTelepon, original.noTelepon);
      expect(restored.tanggal, original.tanggal);
      expect(restored.nomorResi, original.nomorResi);
      expect(restored.kotaKabupaten, original.kotaKabupaten);
      expect(restored.kecamatan, original.kecamatan);
      expect(restored.barang, hasLength(1));
      expect(restored.barang.single.id, 'b4');
      expect(restored.barang.single.photoPath, '/photos/kardus.jpg');
      expect(restored.totalKubikasi, closeTo(0.048, 1e-9));
      expect(restored.totalBerat, closeTo(2.5, 1e-9));
    });

    test('legacy shipment data without newer optional fields remains readable', () {
      final restored = Pengiriman.fromJson({
        'id': 'legacy-1',
        'pengirim': 'Pengirim Lama',
        'tanggal': '2026-09-08T00:00:00.000',
        'nomorResi': 'OLD-001',
        'barang': [
          {
            'id': 'legacy-b1',
            'nama': 'Barang Lama',
            'jumlah': 1,
            'panjang': 10,
            'lebar': 20,
            'tinggi': 30,
          },
        ],
      });

      expect(restored.pengirim, 'Pengirim Lama');
      expect(restored.noTelepon, isEmpty);
      expect(restored.kotaKabupaten, isEmpty);
      expect(restored.kecamatan, isEmpty);
      expect(restored.barang, hasLength(1));
      expect(restored.barang.single.berat, 0);
    });
  });
}
