import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/models/pengiriman.dart';
import 'package:volume_calculator/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('multiple goods, photo references and totals survive storage round-trip', () async {
    final storage = StorageService();
    final shipment = Pengiriman(
      id: 'shipment-roundtrip',
      pengirim: 'Pelanggan Uji',
      noTelepon: '081234567890',
      tanggal: DateTime(2026, 10, 25, 10),
      nomorResi: 'RESI-LAMA-001',
      kotaKabupaten: 'Malang',
      kecamatan: 'Lowokwaru',
      barang: [
        BarangItem(
          id: 'item-box',
          nama: 'Kardus',
          jumlah: 2,
          panjang: 100,
          lebar: 50,
          tinggi: 40,
          berat: 3,
          photoPath: '/app-documents/kardus.jpg',
        ),
        BarangItem(
          id: 'item-paket',
          nama: 'Paket',
          jumlah: 1,
          panjang: 50,
          lebar: 40,
          tinggi: 20,
          berat: 1.5,
          photoPath: '/app-documents/paket.jpg',
        ),
      ],
    );

    await storage.savePengiriman([shipment]);
    final loaded = await storage.loadPengiriman();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, shipment.id);
    expect(loaded.single.barang.map((item) => item.id).toList(),
        ['item-box', 'item-paket']);
    expect(loaded.single.barang.map((item) => item.photoPath).toList(), [
      '/app-documents/kardus.jpg',
      '/app-documents/paket.jpg',
    ]);
    expect(loaded.single.totalJumlah, 3);
    expect(loaded.single.totalBerat, 7.5);
    expect(loaded.single.totalKubikasi, closeTo(0.44, 1e-10));
    expect(loaded.single.totalVolume, closeTo(88.0, 1e-10));

    // Editing the receipt must update the same shipment, not drop its goods.
    final edited = Pengiriman(
      id: loaded.single.id,
      pengirim: loaded.single.pengirim,
      noTelepon: loaded.single.noTelepon,
      tanggal: loaded.single.tanggal,
      nomorResi: 'RESI-BARU-002',
      kotaKabupaten: loaded.single.kotaKabupaten,
      kecamatan: loaded.single.kecamatan,
      barang: loaded.single.barang.map((item) => item.copyWith()).toList(),
    );
    await storage.savePengiriman([edited]);

    final afterEdit = (await storage.loadPengiriman()).single;
    expect(afterEdit.id, shipment.id);
    expect(afterEdit.nomorResi, 'RESI-BARU-002');
    expect(afterEdit.barang, hasLength(2));
    expect(afterEdit.barang.map((item) => item.id).toList(),
        ['item-box', 'item-paket']);
    expect(afterEdit.barang.first.photoPath, '/app-documents/kardus.jpg');
    expect(afterEdit.totalJumlah, 3);
    expect(afterEdit.totalBerat, 7.5);
    expect(afterEdit.totalKubikasi, closeTo(0.44, 1e-10));
  });

  test('malformed persisted shipment data is not silently overwritten', () async {
    const original = '[{"id":"damaged","pengirim":"Pelanggan","barang":[null]}]';
    SharedPreferences.setMockInitialValues({
      'daftar_pengiriman_v2': original,
    });
    final storage = StorageService();

    await expectLater(storage.loadPengiriman(), throwsFormatException);
    expect(await storage.readRawShipmentData(), original);
  });
}
