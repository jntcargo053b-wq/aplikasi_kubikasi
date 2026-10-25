import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets(
    'form shipment shows goods before sender and receipt, and saved sender can be selected',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showPengirimanFormSheet(context),
                  child: const Text('Buka formulir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka formulir'));
      await tester.pumpAndSettle();

      final goods = tester.getTopLeft(find.text('Daftar Barang')).dy;
      final sender = tester.getTopLeft(find.text('Nama Pengirim')).dy;
      final destination = tester.getTopLeft(find.text('Kota/Kab. Tujuan')).dy;
      final receipt = tester.getTopLeft(find.text('Nomor Resi')).dy;

      expect(goods, lessThan(sender));
      expect(sender, lessThan(destination));
      expect(destination, lessThan(receipt));

      final chooseCustomer = find.byTooltip('Pilih pelanggan tersimpan');
      expect(chooseCustomer, findsOneWidget);
      await tester.tap(chooseCustomer);
      await tester.pumpAndSettle();

      expect(find.text('Pelanggan Contoh'), findsOneWidget);
      await tester.tap(find.text('Pelanggan Contoh').last);
      await tester.pumpAndSettle();

      final senderField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Nama Pengirim',
        ),
      );
      expect(senderField.controller?.text, 'Pelanggan Contoh');

      final phoneField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'No. Telepon',
        ),
      );
      expect(phoneField.controller?.text, '081234567890');
    },
  );
}
