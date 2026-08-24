import 'package:flutter_test/flutter_test.dart';
import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/models/pengiriman.dart';

void main() {
  test('kubikasi and shipment totals are correct', () {
    final item = BarangItem(
      id: '1',
      nama: 'BOX',
      jumlah: 2,
      panjang: 100,
      lebar: 50,
      tinggi: 40,
      berat: 3,
    );
    final shipment = Pengiriman(
      id: 's1',
      pengirim: 'PT TEST',
      tanggal: DateTime(2026, 8, 23),
      nomorResi: 'TEST123',
      barang: [item],
    );

    expect(item.volume, 80.0);
    expect(item.kubikasi, 0.4);
    expect(shipment.totalJumlah, 2);
    expect(shipment.totalBerat, 6.0);
    expect(shipment.totalKubikasi, 0.4);
  });
}
