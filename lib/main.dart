import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Kubikasi',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class Barang {
  final String namaPengirim;
  final String namaBarang;
  final int jumlah;
  final double panjang, lebar, tinggi;

  const Barang({
    required this.namaPengirim,
    required this.namaBarang,
    required this.jumlah,
    required this.panjang,
    required this.lebar,
    required this.tinggi,
  });

  double get vol5000Raw => (panjang * lebar * tinggi) / 5000;
  double get kubikasiRaw => (panjang * lebar * tinggi) / 1000000;
  String get vol5000Display => vol5000Raw.toStringAsFixed(2).replaceAll('.', ',');
  String get kubikasiDisplay => kubikasiRaw.toStringAsFixed(2).replaceAll('.', ',');
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  final List<Barang> items = const [
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'LEMARI', jumlah: 1, panjang: 182, lebar: 54, tinggi: 168),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'SISI BED', jumlah: 1, panjang: 192, lebar: 18, tinggi: 5),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'KAKI BED', jumlah: 1, panjang: 127, lebar: 5, tinggi: 50),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'KEPALA BED', jumlah: 1, panjang: 127, lebar: 24, tinggi: 80),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'BUFET', jumlah: 1, panjang: 63, lebar: 33, tinggi: 175),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'TOALET', jumlah: 1, panjang: 120, lebar: 38, tinggi: 170),
    Barang(namaPengirim: 'BAJANG RATU', namaBarang: 'LEMARI PUTIH', jumlah: 1, panjang: 150, lebar: 39, tinggi: 138),
  ];

  @override
  Widget build(BuildContext context) {
    double totalVol = 0, totalKubik = 0;
    for (var item in items) {
      totalVol += item.vol5000Raw;
      totalKubik += item.kubikasiRaw;
    }
    String totalVolDisplay = totalVol.toStringAsFixed(2).replaceAll('.', ',');
    String totalKubikDisplay = totalKubik.toStringAsFixed(2).replaceAll('.', ',');

    return Scaffold(
      appBar: AppBar(title: const Text('Perhitungan VOL & Kubikasi'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                  border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                  columns: const [
                    DataColumn(label: Text('PENGIRIM', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('NAMA BARANG', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('L', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('T', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('VOL 5000', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    DataColumn(label: Text('KUBIKASI', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  ],
                  rows: [
                    ...items.map((item) => DataRow(cells: [
                          DataCell(Text(item.namaPengirim)),
                          DataCell(Text(item.namaBarang)),
                          DataCell(Text(item.panjang.toString())),
                          DataCell(Text(item.lebar.toString())),
                          DataCell(Text(item.tinggi.toString())),
                          DataCell(Text(item.vol5000Display)),
                          DataCell(Text(item.kubikasiDisplay)),
                        ])),
                    DataRow(
                      color: WidgetStateProperty.all(Colors.yellow.shade100),
                      cells: [
                        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(Text(totalVolDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red))),
                        DataCell(Text(totalKubikDisplay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.blue.shade50,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      const Text('Total VOL 5000', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(totalVolDisplay, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ]),
                    Container(height: 40, width: 1, color: Colors.grey.shade400),
                    Column(children: [
                      const Text('Total KUBIKASI (m³)', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(totalKubikDisplay, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    ]),
                  ],
                ),
              ),
            ),
            const Text('Data sesuai dengan file Excel', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
