import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/pengiriman.dart';
import '../models/report_settings.dart';

/// Layanan untuk membuat dan membagikan laporan pengiriman
/// dalam format PDF maupun Excel (.xlsx), baik per-resi maupun gabungan.
class ExportService {
  final _tanggalFmt = DateFormat('dd/MM/yyyy');
  final _waktuFmt = DateFormat('dd/MM/yyyy HH:mm');

  static const int _maxEmbeddedPhotos = 60;
  static const int _reportPhotoMaxDimension = 1400;
  static const int _reportPhotoJpegQuality = 82;

  String _fmtNum(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+\$'), '').replaceFirst(RegExp(r'\.\$'), '');
  }

  String _sanitize(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return cleaned.isEmpty ? 'pengiriman' : cleaned;
  }

  Future<Directory> _tempDir() async {
    final dir = await getTemporaryDirectory();
    final reportDir = Directory('${dir.path}/reports');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }
    return reportDir;
  }

  Future<File> generatePdf(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async =>
      (await _buildPdf(p, settings)).file;

  /// Header export: logo, nama perusahaan, alamat perusahaan, judul laporan.
  /// Judul laporan mengikuti pengaturan header dan memiliki fallback aman.
  Future<pw.MemoryImage?> _loadReportLogo(ReportSettings settings) async {
    final path = settings.logoPath?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  List<pw.Widget> _headerLines(ReportSettings settings, String defaultTitle, pw.MemoryImage? logo) {
    final company = settings.companyName.trim();
    final address = settings.headerNote.trim();
    final configuredTitle = settings.reportTitle.trim();
    final reportTitle = configuredTitle.isNotEmpty ? configuredTitle : defaultTitle;
    final companyStyle = pw.TextStyle(
      fontSize: company.isNotEmpty ? 16 : 18,
      fontWeight: pw.FontWeight.bold,
    );
    final addressStyle = const pw.TextStyle(
      fontSize: 9,
      color: PdfColor.fromInt(0xFF64748B),
    );
    final reportTitleStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromInt(0xFF475569),
    );

    final content = <pw.Widget>[];
    if (company.isNotEmpty) content.add(pw.Text(company, style: companyStyle));
    if (address.isNotEmpty) {
      content.add(pw.SizedBox(height: 2));
      content.add(pw.Text(address, style: addressStyle));
    }
    content.add(pw.SizedBox(height: 2));
    content.add(pw.Text(reportTitle, style: reportTitleStyle));

    if (logo == null) return content;
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 52,
            height: 52,
            margin: const pw.EdgeInsets.only(right: 10),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ],
      ),
    ];
  }

  pw.Widget _reportFooter(pw.Context context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Halaman ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B))),
      );

  pw.Widget _photoCard(_PhotoData photo, int number) => pw.Container(
        width: 250,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(height: 145, width: double.infinity, child: pw.Image(photo.image, fit: pw.BoxFit.contain)),
            pw.SizedBox(height: 5),
            pw.Text('Dokumentasi $number', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(photo.itemName, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      );

  pw.Widget _photoSection({
    required List<_PhotoData> photos,
    required String title,
    required String resi,
    required String pengirim,
    required String noTelepon,
    required String kotaKabupaten,
    required String kecamatan,
    required DateTime tanggal,
  }) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text('Resi: $resi', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Pengirim: $pengirim', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('No. Telepon: $noTelepon', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Kota/Kab. Tujuan: $kotaKabupaten', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Kecamatan Tujuan: $kecamatan', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Tanggal: ${_tanggalFmt.format(tanggal)}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.7),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [for (var i = 0; i < photos.length; i++) _photoCard(photos[i], i + 1)],
          ),
        ],
      );

  Future<({File file, bool hasPhotos})> _buildPdf(Pengiriman p, ReportSettings settings) async {
    final doc = pw.Document();
    final logo = await _loadReportLogo(settings);
    final loaded = await _loadPhotos(p, limit: _maxEmbeddedPhotos);
    final photos = loaded.photos;
    final headers = ['No', 'Nama Barang', 'Jml', 'P×L×T (cm)', 'Berat (kg)', 'Volume', 'Kubikasi (m³)'];
    final rows = [
      for (var i = 0; i < p.barang.length; i++)
        [
          '${i + 1}', p.barang[i].nama, p.barang[i].jumlah.toString(),
          '${_fmtNum(p.barang[i].panjang)}×${_fmtNum(p.barang[i].lebar)}×${_fmtNum(p.barang[i].tinggi)}',
          p.barang[i].totalBerat.toStringAsFixed(2), p.barang[i].volume.toStringAsFixed(2), p.barang[i].kubikasi.toStringAsFixed(3),
        ],
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: _reportFooter,
      header: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        ..._headerLines(settings, 'Laporan Kubikasi Pengiriman', logo),
        pw.SizedBox(height: 4), pw.Divider(thickness: 1),
      ]),
      build: (context) => [
        pw.SizedBox(height: 4),
        _infoRow('Nomor Resi', p.nomorResi), _infoRow('Pengirim', p.pengirim),
        _infoRow('No. Telepon', p.noTelepon),
        _infoRow('Tanggal', _tanggalFmt.format(p.tanggal)), _infoRow('Kota/Kab. Tujuan', p.kotaKabupaten), _infoRow('Kecamatan Tujuan', p.kecamatan), _infoRow('Jumlah Jenis Barang', '${p.barang.length}'),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers, data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: const {0: pw.FixedColumnWidth(24), 1: pw.FlexColumnWidth(2.2), 2: pw.FlexColumnWidth(0.8), 3: pw.FlexColumnWidth(1.6), 4: pw.FlexColumnWidth(1.1), 5: pw.FlexColumnWidth(1.1), 6: pw.FlexColumnWidth(1.2)},
          border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 1), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RINGKASAN TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)), pw.SizedBox(height: 6),
            _totalRow('Total Jumlah Barang', '${p.totalJumlah}'), _totalRow('Total Berat', '${p.totalBerat.toStringAsFixed(2)} kg'),
            _totalRow('Total Volume', p.totalVolume.toStringAsFixed(2)), _totalRow('Total Kubikasi', '${p.totalKubikasi.toStringAsFixed(3)} m³'),
          ]),
        ),
        pw.SizedBox(height: 18),
        pw.Text('Dicetak: ${_waktuFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B))),
      ],
    ));

    if (photos.isNotEmpty) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: _reportFooter,
        header: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          ..._headerLines(settings, 'Laporan Kubikasi Pengiriman', logo),
          pw.SizedBox(height: 4), pw.Divider(thickness: 1),
        ]),
        build: (context) => [
          _photoSection(photos: photos, title: 'DOKUMENTASI FOTO', resi: p.nomorResi, pengirim: p.pengirim, noTelepon: p.noTelepon, kotaKabupaten: p.kotaKabupaten, kecamatan: p.kecamatan, tanggal: p.tanggal),
          if (loaded.truncated) pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text('Catatan: hanya $_maxEmbeddedPhotos foto pertama yang disertakan agar ukuran file tetap aman.', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: const PdfColor.fromInt(0xFF64748B))),
          ),
        ],
      ));
    }

    final dir = await _tempDir();
    final file = File('${dir.path}/Laporan_${_sanitize(p.nomorResi)}.pdf');
    await file.writeAsBytes(await doc.save());
    return (file: file, hasPhotos: photos.isNotEmpty);
  }

  Future<File> generateCombinedPdf(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async =>
      (await _buildCombinedPdf(items, settings)).file;

  Future<({File file, bool hasPhotos})> _buildCombinedPdf(List<Pengiriman> items, ReportSettings settings) async {
    if (items.isEmpty) throw ArgumentError('Tidak ada pengiriman untuk dibagikan.');
    final doc = pw.Document();
    final logo = await _loadReportLogo(settings);
    final sorted = List<Pengiriman>.from(items);
    final totalJumlah = sorted.fold<int>(0, (s, p) => s + p.totalJumlah);
    final totalBerat = sorted.fold<double>(0, (s, p) => s + p.totalBerat);
    final totalVolume = sorted.fold<double>(0, (s, p) => s + p.totalVolume);
    final totalKubikasi = sorted.fold<double>(0, (s, p) => s + p.totalKubikasi);
    final photoQuotas = await _allocatePhotoQuotas(sorted, _maxEmbeddedPhotos);
    final combinedPhotos = <String, List<_PhotoData>>{};
    var anyTruncated = false;
    var totalEmbedded = 0;
    for (final shipment in sorted) {
      final loaded = await _loadPhotos(shipment, limit: photoQuotas[shipment.id] ?? 0);
      combinedPhotos[shipment.id] = loaded.photos;
      totalEmbedded += loaded.photos.length;
      if (loaded.truncated) anyTruncated = true;
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), footer: _reportFooter,
      header: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        ..._headerLines(settings, 'Rekap Laporan Kubikasi Pengiriman', logo), pw.SizedBox(height: 4),
        pw.Text('Jumlah pengiriman: ${sorted.length}', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))), pw.Divider(thickness: 1),
      ]),
      build: (context) => [
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: const ['No', 'Tanggal', 'Resi', 'Pengirim', 'No. Telepon', 'Kota/Kab. Tujuan', 'Kecamatan Tujuan', 'Barang', 'Berat (kg)', 'Kubikasi (m³)'],
          data: [for (var i = 0; i < sorted.length; i++) ['${i + 1}', _tanggalFmt.format(sorted[i].tanggal), sorted[i].nomorResi, sorted[i].pengirim, sorted[i].noTelepon, sorted[i].kotaKabupaten, sorted[i].kecamatan, '${sorted[i].totalJumlah}', sorted[i].totalBerat.toStringAsFixed(2), sorted[i].totalKubikasi.toStringAsFixed(3)]],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), cellStyle: const pw.TextStyle(fontSize: 7.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)), border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 1), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('TOTAL GABUNGAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)), pw.SizedBox(height: 6),
            _totalRow('Total Pengiriman', '${sorted.length}'), _totalRow('Total Jumlah Barang', '$totalJumlah'),
            _totalRow('Total Berat', '${totalBerat.toStringAsFixed(2)} kg'), _totalRow('Total Volume', totalVolume.toStringAsFixed(2)),
            _totalRow('Total Kubikasi', '${totalKubikasi.toStringAsFixed(3)} m³'),
          ]),
        ),
      ],
    ));

    for (final shipment in sorted) {
      final photos = combinedPhotos[shipment.id] ?? const <_PhotoData>[];
      if (photos.isEmpty) continue;
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), footer: _reportFooter,
        header: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          ..._headerLines(settings, 'Rekap Laporan Kubikasi Pengiriman', logo), pw.SizedBox(height: 4), pw.Divider(thickness: 1),
        ]),
        build: (context) => [
          _photoSection(photos: photos, title: 'DOKUMENTASI FOTO', resi: shipment.nomorResi, pengirim: shipment.pengirim, noTelepon: shipment.noTelepon, kotaKabupaten: shipment.kotaKabupaten, kecamatan: shipment.kecamatan, tanggal: shipment.tanggal),
        ],
      ));
    }

    if (anyTruncated || totalEmbedded >= _maxEmbeddedPhotos) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Text('Catatan: dokumentasi foto dibatasi maksimal $_maxEmbeddedPhotos foto pada laporan gabungan.', style: const pw.TextStyle(fontSize: 9)),
      ));
    }

    final dir = await _tempDir();
    final file = File('${dir.path}/Rekap_Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return (file: file, hasPhotos: totalEmbedded > 0);
  }

  Future<File> generateExcel(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Laporan'];
    var row = 0;
    final company = settings.companyName.trim();
    final address = settings.headerNote.trim();
    final configuredTitle = settings.reportTitle.trim();
    final reportTitle = configuredTitle.isNotEmpty ? configuredTitle : 'Laporan Kubikasi Pengiriman';
    if (company.isNotEmpty) sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(company);
    if (address.isNotEmpty) sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(address);
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(reportTitle);
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('Nomor Resi: ${p.nomorResi}');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('Pengirim: ${p.pengirim}');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('No. Telepon: ${p.noTelepon}');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('Tanggal: ${_tanggalFmt.format(p.tanggal)}');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('Kota/Kab. Tujuan: ${p.kotaKabupaten}');
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue('Kecamatan Tujuan: ${p.kecamatan}');
    row++;
    final headers = ['No', 'Nama Barang', 'Jumlah', 'Panjang (cm)', 'Lebar (cm)', 'Tinggi (cm)', 'Berat/unit (kg)', 'Total Berat (kg)', 'Volume', 'Kubikasi (m³)'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).value = xls.TextCellValue(headers[i]);
    }
    row++;
    for (var i = 0; i < p.barang.length; i++) {
      final b = p.barang[i];
      final values = [i + 1, b.nama, b.jumlah, b.panjang, b.lebar, b.tinggi, b.berat, b.totalBerat, b.volume, b.kubikasi];
      for (var j = 0; j < values.length; j++) {
        final value = values[j];
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        if (value is int) {
          cell.value = xls.IntCellValue(value);
        } else if (value is double) {
          cell.value = xls.DoubleCellValue(value);
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
      }
      row++;
    }
    row++;
    final totals = [
      'TOTAL JUMLAH BARANG: ${p.totalJumlah}',
      'TOTAL BERAT: ${p.totalBerat.toStringAsFixed(2)} kg',
      'TOTAL VOLUME: ${p.totalVolume.toStringAsFixed(2)}',
      'TOTAL KUBIKASI: ${p.totalKubikasi.toStringAsFixed(3)} m³',
    ];
    for (final t in totals) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(t);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel.');
    final dir = await _tempDir();
    final file = File('${dir.path}/Laporan_${_sanitize(p.nomorResi)}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> generateCombinedExcel(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    if (items.isEmpty) throw ArgumentError('Tidak ada pengiriman untuk dibagikan.');
    final excel = xls.Excel.createExcel();
    final sheet = excel['Rekap'];
    var row = 0;
    final company = settings.companyName.trim();
    final address = settings.headerNote.trim();
    final configuredTitle = settings.reportTitle.trim();
    final reportTitle = configuredTitle.isNotEmpty ? configuredTitle : 'Rekap Laporan Kubikasi Pengiriman';
    if (company.isNotEmpty) sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(company);
    if (address.isNotEmpty) sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(address);
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(reportTitle);
    row++;
    final headers = ['No', 'Tanggal', 'Resi', 'Pengirim', 'No. Telepon', 'Kota/Kab. Tujuan', 'Kecamatan Tujuan', 'Jumlah Barang', 'Berat (kg)', 'Volume', 'Kubikasi (m³)'];
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).value = xls.TextCellValue(headers[i]);
    }
    row++;
    var totalJumlah = 0;
    var totalBerat = 0.0;
    var totalVolume = 0.0;
    var totalKubikasi = 0.0;
    for (var i = 0; i < items.length; i++) {
      final p = items[i];
      final values = [i + 1, _tanggalFmt.format(p.tanggal), p.nomorResi, p.pengirim, p.noTelepon, p.kotaKabupaten, p.kecamatan, p.totalJumlah, p.totalBerat, p.totalVolume, p.totalKubikasi];
      for (var j = 0; j < values.length; j++) {
        final value = values[j];
        final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: j, rowIndex: row));
        if (value is int) {
          cell.value = xls.IntCellValue(value);
        } else if (value is double) {
          cell.value = xls.DoubleCellValue(value);
        } else {
          cell.value = xls.TextCellValue(value.toString());
        }
      }
      row++;
      totalJumlah += p.totalJumlah;
      totalBerat += p.totalBerat;
      totalVolume += p.totalVolume;
      totalKubikasi += p.totalKubikasi;
    }
    row++;
    final totals = [
      'TOTAL PENGIRIMAN: ${items.length}',
      'TOTAL JUMLAH BARANG: $totalJumlah',
      'TOTAL BERAT: ${totalBerat.toStringAsFixed(2)} kg',
      'TOTAL VOLUME: ${totalVolume.toStringAsFixed(2)}',
      'TOTAL KUBIKASI: ${totalKubikasi.toStringAsFixed(3)} m³',
    ];
    for (final t in totals) {
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row++)).value = xls.TextCellValue(t);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel gabungan.');
    final dir = await _tempDir();
    final file = File('${dir.path}/Rekap_Laporan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> sharePdf(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generatePdf(p, settings: settings);
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan kubikasi ${p.nomorResi}');
  }

  Future<void> shareExcel(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generateExcel(p, settings: settings);
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan kubikasi ${p.nomorResi}');
  }

  Future<void> shareCombinedPdf(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generateCombinedPdf(items, settings: settings);
    await Share.shareXFiles([XFile(file.path)], text: 'Rekap laporan kubikasi (${items.length} pengiriman)');
  }

  Future<void> shareCombinedExcel(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generateCombinedExcel(items, settings: settings);
    await Share.shareXFiles([XFile(file.path)], text: 'Rekap laporan kubikasi (${items.length} pengiriman)');
  }

  Future<_LoadedPhotos> _loadPhotos(Pengiriman p, {required int limit}) async {
    if (limit <= 0) return const _LoadedPhotos(photos: [], truncated: false);
    final result = <_PhotoData>[];
    for (final item in p.barang) {
      final path = item.photoPath;
      if (path == null || path.isEmpty) continue;
      if (result.length >= limit) {
        return _LoadedPhotos(photos: result, truncated: true);
      }
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final decoded = img.decodeImage(bytes);
        if (decoded == null) continue;
        final processed = _prepareReportImage(decoded);
        result.add(_PhotoData(image: pw.MemoryImage(img.encodeJpg(processed, quality: _reportPhotoJpegQuality)), itemName: item.nama));
      } catch (_) {}
    }
    var totalAvailable = 0;
    for (final item in p.barang) {
      if (item.photoPath != null && item.photoPath!.isNotEmpty) totalAvailable++;
    }
    return _LoadedPhotos(photos: result, truncated: totalAvailable > result.length);
  }

  img.Image _prepareReportImage(img.Image source) {
    final width = source.width;
    final height = source.height;
    final maxDimension = width > height ? width : height;
    if (maxDimension <= _reportPhotoMaxDimension) return source;
    final scale = _reportPhotoMaxDimension / maxDimension;
    return img.copyResize(source, width: (width * scale).round(), height: (height * scale).round());
  }

  Future<Map<String, int>> _allocatePhotoQuotas(List<Pengiriman> items, int maxTotal) async {
    final counts = <String, int>{};
    var total = 0;
    for (final item in items) {
      var count = 0;
      for (final barang in item.barang) {
        if (barang.photoPath != null && barang.photoPath!.isNotEmpty) count++;
      }
      counts[item.id] = count;
      total += count;
    }
    if (total <= maxTotal) return counts;
    final result = <String, int>{for (final item in items) item.id: 0};
    var remaining = maxTotal;
    for (final item in items) {
      if (remaining <= 0) break;
      final quota = counts[item.id] ?? 0;
      final assigned = quota > remaining ? remaining : quota;
      result[item.id] = assigned;
      remaining -= assigned;
    }
    return result;
  }

  pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(children: [
          pw.SizedBox(width: 115, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
        ]),
      );

  pw.Widget _totalRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ]),
      );
}

class _PhotoData {
  final pw.MemoryImage image;
  final String itemName;
  const _PhotoData({required this.image, required this.itemName});
}

class _LoadedPhotos {
  final List<_PhotoData> photos;
  final bool truncated;
  const _LoadedPhotos({required this.photos, required this.truncated});
}
