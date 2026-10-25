import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_calculator/models/barang_item.dart';
import 'package:volume_calculator/screens/pengiriman_form_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'daftar_pengiriman_v2': jsonEncode([
        {
          'id': 'shipment-customer-1',
          'pengirim': 'Pelanggan Contoh',
          'noTelepon': '081234567890',
          'tanggal': '2026-10-20T10:00:00.000',
          'nomorResi': 'RESI-CONTOH-001',
          'kotaKabupaten': '',
          'kecamatan': '',
          'barang': [
            {
              'id': 'item-customer-1',
              'nama': 'Kardus',
              'jumlah': 1,
              'panjang': 10.0,
              'lebar': 10.0,
              'tinggi': 10.0,
              'berat': 1.0,
            }
          ],
        }
      ]),
    });
  });

  Future<void> openForm(
    WidgetTester tester, {
    List<BarangItem>? initialBarang,
  }) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPengirimanFormSheet(
                  context,
                  initialBarang: initialBarang,
                ),
                child: const Text('Buka formulir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka formulir'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

  BarangItem item(String id, String name) => BarangItem(
        id: id,
        nama: name,
        jumlah: 1,
        panjang: 10,
        lebar: 20,
        tinggi: 30,
        berat: 2,
      );

  testWidgets(
    'multiple goods remain in one shipment form and receipt is required',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openForm(
        tester,
        initialBarang: [
          item('item-1', 'Kardus'),
          item('item-2', 'Paket'),
        ],
      );

      expect(find.text('Kardus'), findsOneWidget);
      expect(find.text('Paket'), findsOneWidget);
      expect(find.text('2 barang • 2 pcs'), findsOneWidget);
      expect(field('Nama Pengirim'), findsOneWidget);

      await tester.tap(find.text('Simpan Pengiriman'));
      await tester.pumpAndSettle();

      // Empty receipt must block saving and leave the form open.
      expect(find.text('Nomor Resi'), findsOneWidget);
      expect(find.text('Daftar Barang'), findsOneWidget);
      expect(find.text('2 barang • 2 pcs'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting saved sender does not overwrite a manually entered phone',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openForm(tester);

      await tester.enterText(field('No. Telepon'), '089999000111');
      await tester.tap(find.byTooltip('Pilih pelanggan tersimpan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pelanggan Contoh').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field('Nama Pengirim')).controller?.text,
        'Pelanggan Contoh',
      );
      expect(
        tester.widget<TextField>(field('No. Telepon')).controller?.text,
        '089999000111',
      );
    },
  );
}
