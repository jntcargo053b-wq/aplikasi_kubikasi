import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../models/report_settings.dart';

/// Layanan untuk membuat dan membagikan laporan pengiriman
/// dalam format PDF maupun Excel (.xlsx), baik per-resi maupun gabungan.
class ExportService {
  final _tanggalFmt = DateFormat('dd/MM/yyyy');
  final _waktuFmt = DateFormat('dd/MM/yyyy HH:mm');

  /// Batas jumlah foto yang disisipkan/dilampirkan per laporan, supaya
  /// laporan (khususnya rekap gabungan) tidak membengkak dan berisiko
  /// membuat aplikasi kehabisan memori di perangkat low-end.
  static const int _maxEmbeddedPhotos = 60;
  /// Foto laporan diperkecil khusus untuk PDF agar penggunaan RAM dan ukuran
  /// file tetap aman. File foto asli tidak pernah diubah.
  static const int _reportPhotoMaxDimension = 1400;
  static const int _reportPhotoJpegQuality = 82;

  String _sanitize(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return cleaned.isEmpty ? 'pengiriman' : cleaned;
  }

  void _validateShipment(Pengiriman p) {
    final error = p.validateForReport();
    if (error != null) {
      throw StateError('Data laporan tidak valid: $error');
    }
  }

  Future<Directory> _tempDir() async {
    final dir = await getTemporaryDirectory();
    final reportDir = Directory('${dir.path}/reports');
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }
    return reportDir;
  }

  /// Membuat file PDF berisi rincian barang dan total kubikasi
  /// untuk satu pengiriman, lalu mengembalikan File-nya.
  Future<File> generatePdf(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async =>
      (await _buildPdf(p, settings)).file;

  /// Widget baris judul header laporan. Jika [settings.companyName] diisi,
  /// nama usaha dijadikan judul utama dan [defaultTitle] menjadi subjudul;
  /// jika kosong, [defaultTitle] tetap dipakai seperti sebelumnya.
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
    final note = settings.headerNote.trim();
    final title = company.isNotEmpty ? company : defaultTitle;
    final titleStyle = pw.TextStyle(
      fontSize: company.isNotEmpty ? 16 : 18,
      fontWeight: pw.FontWeight.bold,
    );
    final children = <pw.Widget>[];

    if (logo != null) {
      children.add(
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
                children: [
                  pw.Text(title, style: titleStyle),
                  if (company.isNotEmpty)
                    pw.SizedBox(height: 2),
                  if (company.isNotEmpty)
                    pw.Text(
                      defaultTitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF475569)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      children.add(pw.Text(title, style: titleStyle));
      if (company.isNotEmpty) {
        children.add(
          pw.Text(
            defaultTitle,
            style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF475569)),
          ),
        );
      }
    }

    if (note.isNotEmpty) {
      children.add(pw.SizedBox(height: 2));
      children.add(
        pw.Text(
          note,
          style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B)),
        ),
      );
    }
    return children;
  }

  Future<({File file, bool hasPhotos})> _buildPdf(Pengiriman p, ReportSettings settings) async {
    _validateShipment(p);
    final doc = pw.Document();
    final logo = await _loadReportLogo(settings);
    final loaded = await _loadPhotos(p, limit: _maxEmbeddedPhotos);
    final photos = loaded.photos;

    final headers = ['No', 'Nama Barang', 'Jml', 'P×L×T (cm)', 'Berat (kg)', 'Volume', 'Kubikasi (m³)'];
    final rows = [
      for (var i = 0; i < p.barang.length; i++)
        [
          '${i + 1}',
          p.barang[i].nama,
          p.barang[i].jumlah.toString(),
          '${_fmtNum(p.barang[i].panjang)}×${_fmtNum(p.barang[i].lebar)}×${_fmtNum(p.barang[i].tinggi)}',
          p.barang[i].totalBerat.toStringAsFixed(2),
          p.barang[i].volume.toStringAsFixed(2),
          p.barang[i].kubikasi.toStringAsFixed(3),
        ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._headerLines(settings, 'Laporan Kubikasi Pengiriman', logo),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 4),
          _infoRow('Nomor Resi', p.nomorResi),
          _infoRow('Pengirim', p.pengirim),
          _infoRow('Tanggal', _tanggalFmt.format(p.tanggal)),
          _infoRow('Jumlah Jenis Barang', '${p.barang.length}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.1),
              6: pw.FlexColumnWidth(1.2),
            },
            border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RINGKASAN TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 6),
                _totalRow('Total Jumlah Barang', '${p.totalJumlah}'),
                _totalRow('Total Berat', '${p.totalBerat.toStringAsFixed(2)} kg'),
                _totalRow('Total Volume', p.totalVolume.toStringAsFixed(2)),
                _totalRow('Total Kubikasi', '${p.totalKubikasi.toStringAsFixed(3)} m³'),
              ],
            ),
          ),
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('DOKUMENTASI FOTO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final photo in photos)
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 150, child: pw.Image(photo.image, fit: pw.BoxFit.contain)),
                        pw.SizedBox(height: 4),
                        pw.Text(photo.itemName, style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
              ],
            ),
            if (loaded.truncated) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Catatan: hanya $_maxEmbeddedPhotos foto pertama yang disertakan agar ukuran file tidak terlalu besar.',
                style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: const PdfColor.fromInt(0xFF64748B)),
              ),
            ],
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Dicetak: ${_waktuFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B)),
          ),
        ],
      ),
    );

    final dir = await _tempDir();
    final file = File('${dir.path}/Laporan_${_sanitize(p.nomorResi)}.pdf');
    await file.writeAsBytes(await doc.save());
    return (file: file, hasPhotos: photos.isNotEmpty);
  }

  /// Membuat satu PDF gabungan dari beberapa pengiriman.
  Future<File> generateCombinedPdf(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async =>
      (await _buildCombinedPdf(items, settings)).file;

  Future<({File file, bool hasPhotos})> _buildCombinedPdf(List<Pengiriman> items, ReportSettings settings) async {
    if (items.isEmpty) throw ArgumentError('Tidak ada pengiriman untuk dibagikan.');
    for (final item in items) {
      _validateShipment(item);
    }
    final doc = pw.Document();
    final logo = await _loadReportLogo(settings);
    // Pertahankan urutan yang dikirim HomeScreen (sudah mengikuti filter + sort UI).
    final sorted = List<Pengiriman>.from(items);
    final totalJumlah = sorted.fold<int>(0, (s, p) => s + p.totalJumlah);
    final totalBerat = sorted.fold<double>(0, (s, p) => s + p.totalBerat);
    final totalVolume = sorted.fold<double>(0, (s, p) => s + p.totalVolume);
    final totalKubikasi = sorted.fold<double>(0, (s, p) => s + p.totalKubikasi);

    // Alokasikan budget foto secara adil antar-resi agar resi lama tidak
    // kehilangan seluruh dokumentasinya hanya karena resi awal memiliki
    // lebih banyak foto. Urutan shipment tetap mengikuti urutan HomeScreen.
    final photoQuotas = await _allocatePhotoQuotas(sorted, _maxEmbeddedPhotos);
    final combinedPhotos = <String, List<_PhotoData>>{};
    var anyTruncated = false;
    var totalEmbedded = 0;
    for (final shipment in sorted) {
      final quota = photoQuotas[shipment.id] ?? 0;
      final loaded = await _loadPhotos(shipment, limit: quota);
      combinedPhotos[shipment.id] = loaded.photos;
      totalEmbedded += loaded.photos.length;
      if (loaded.truncated) anyTruncated = true;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ..._headerLines(settings, 'Rekap Laporan Kubikasi Pengiriman', logo),
            pw.SizedBox(height: 4),
            pw.Text('Jumlah pengiriman: ${sorted.length}', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
            pw.Divider(thickness: 1),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: const ['No', 'Tanggal', 'Resi', 'Pengirim', 'Barang', 'Berat (kg)', 'Kubikasi (m³)'],
            data: [
              for (var i = 0; i < sorted.length; i++)
                [
                  '${i + 1}',
                  _tanggalFmt.format(sorted[i].tanggal),
                  sorted[i].nomorResi,
                  sorted[i].pengirim,
                  '${sorted[i].totalJumlah}',
                  sorted[i].totalBerat.toStringAsFixed(2),
                  sorted[i].totalKubikasi.toStringAsFixed(3),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
            border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FixedColumnWidth(55),
              2: pw.FlexColumnWidth(1.25),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FixedColumnWidth(38),
              5: pw.FixedColumnWidth(50),
              6: pw.FixedColumnWidth(58),
            },
          ),
          pw.SizedBox(height: 14),
          for (final shipment in sorted) ...[
            if ((combinedPhotos[shipment.id] ?? const <_PhotoData>[]).isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Foto - Resi ${shipment.nomorResi}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final photo in (combinedPhotos[shipment.id] ?? const <_PhotoData>[]))
                    pw.Container(
                      width: 250,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(height: 145, child: pw.Image(photo.image, fit: pw.BoxFit.contain)),
                          pw.SizedBox(height: 3),
                          pw.Text(photo.itemName, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
          if (anyTruncated) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Catatan: dokumentasi foto dibatasi maksimal $_maxEmbeddedPhotos foto dan dialokasikan secara merata antar-resi. Sebagian foto dapat tidak disertakan.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: const PdfColor.fromInt(0xFF64748B)),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 1),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RINGKASAN TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(height: 6),
                _totalRow('Total Pengiriman', '${sorted.length}'),
                _totalRow('Total Jumlah Barang', '$totalJumlah'),
                _totalRow('Total Berat', '${totalBerat.toStringAsFixed(2)} kg'),
                _totalRow('Total Volume', totalVolume.toStringAsFixed(2)),
                _totalRow('Total Kubikasi', '${totalKubikasi.toStringAsFixed(3)} m³'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Dicetak: ${_waktuFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B))),
        ],
      ),
    );
    final dir = await _tempDir();
    final file = File('${dir.path}/Rekap_Kubikasi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return (file: file, hasPhotos: totalEmbedded > 0);
  }

  /// Membuat satu Excel gabungan dari beberapa pengiriman.
  Future<File> generateCombinedExcel(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    if (items.isEmpty) throw ArgumentError('Tidak ada pengiriman untuk dibagikan.');
    for (final item in items) {
      _validateShipment(item);
    }
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Rekap';
    final sheet = workbook[sheetName];
    if (workbook.getDefaultSheet() != null && workbook.getDefaultSheet() != sheetName) {
      workbook.delete(workbook.getDefaultSheet()!);
    }
    void setCell(int col, int row, dynamic value, {bool bold = false}) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is num) {
        cell.value = xls.DoubleCellValue(value.toDouble());
      } else {
        cell.value = xls.TextCellValue(value.toString());
      }
      if (bold) cell.cellStyle = xls.CellStyle(bold: true);
    }
    // Pertahankan urutan yang dikirim HomeScreen (sudah mengikuti filter + sort UI).
    final sorted = List<Pengiriman>.from(items);
    var row0 = 0;
    final company = settings.companyName.trim();
    final note = settings.headerNote.trim();
    if (company.isNotEmpty) {
      setCell(0, row0, company, bold: true);
      row0++;
      setCell(0, row0, 'Rekap Laporan Kubikasi Pengiriman');
      row0++;
    } else {
      setCell(0, row0, 'Rekap Laporan Kubikasi Pengiriman', bold: true);
      row0++;
    }
    if (note.isNotEmpty) {
      setCell(0, row0, note);
      row0++;
    }
    setCell(0, row0, 'Jumlah Pengiriman', bold: true);
    setCell(1, row0, sorted.length);
    row0 += 2;
    final headerRow = row0;
    const headers = ['No', 'Tanggal', 'Nomor Resi', 'Pengirim', 'Nama Barang', 'Jumlah', 'Panjang (cm)', 'Lebar (cm)', 'Tinggi (cm)', 'Berat/pcs (kg)', 'Total Berat (kg)', 'Volume', 'Kubikasi (m³)', 'Foto'];
    for (var c = 0; c < headers.length; c++) {
      setCell(c, headerRow, headers[c], bold: true);
    }
    var row = headerRow + 1;
    for (var i = 0; i < sorted.length; i++) {
      final shipment = sorted[i];
      for (final b in shipment.barang) {
        setCell(0, row, i + 1);
        setCell(1, row, _tanggalFmt.format(shipment.tanggal));
        setCell(2, row, shipment.nomorResi);
        setCell(3, row, shipment.pengirim);
        setCell(4, row, b.nama);
        setCell(5, row, b.jumlah);
        setCell(6, row, b.panjang);
        setCell(7, row, b.lebar);
        setCell(8, row, b.tinggi);
        setCell(9, row, b.berat);
        setCell(10, row, b.totalBerat);
        setCell(11, row, b.volume);
        setCell(12, row, b.kubikasi);
        setCell(13, row, b.photoPath != null && await File(b.photoPath!).exists() ? 'Ada' : 'Tidak ada');
        row++;
      }
    }
    row++;
    setCell(0, row, 'TOTAL', bold: true);
    setCell(5, row, sorted.fold<int>(0, (s, p) => s + p.totalJumlah), bold: true);
    setCell(10, row, sorted.fold<double>(0, (s, p) => s + p.totalBerat), bold: true);
    setCell(11, row, sorted.fold<double>(0, (s, p) => s + p.totalVolume), bold: true);
    setCell(12, row, sorted.fold<double>(0, (s, p) => s + p.totalKubikasi), bold: true);
    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnAutoFit(c);
    }
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel.');
    final dir = await _tempDir();
    final file = File('${dir.path}/Rekap_Kubikasi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> shareCombinedPdf(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    final built = await _buildCombinedPdf(items, settings);
    await Share.shareXFiles(
      [XFile(built.file.path)],
      text: built.hasPhotos
          ? 'Rekap Kubikasi - ${items.length} pengiriman (dengan foto)'
          : 'Rekap Kubikasi - ${items.length} pengiriman',
      subject: 'Rekap Kubikasi Pengiriman',
    );
  }

  Future<void> shareCombinedExcel(List<Pengiriman> items, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generateCombinedExcel(items, settings: settings);
    final quotas = await _allocatePhotoQuotas(items, _maxEmbeddedPhotos);
    final photoFiles = <File>[];
    var totalValidPhotos = 0;
    for (final item in items) {
      totalValidPhotos += await _countValidPhotos(item);
      final quota = quotas[item.id] ?? 0;
      photoFiles.addAll(await _compressedPhotoFiles(item, limit: quota));
    }
    final truncated = totalValidPhotos > _maxEmbeddedPhotos;
    await Share.shareXFiles(
      [XFile(file.path), ...photoFiles.map((f) => XFile(f.path))],
      text: photoFiles.isEmpty
          ? 'Rekap Kubikasi - ${items.length} pengiriman'
          : 'Rekap Kubikasi - ${items.length} pengiriman + ${photoFiles.length} foto terkompresi${truncated ? ' (maks $_maxEmbeddedPhotos, dibagi merata per resi)' : ''}',
      subject: 'Rekap Kubikasi Pengiriman',
    );
  }

  /// Membuat file Excel (.xlsx) berisi rincian barang dan total
  /// kubikasi untuk satu pengiriman, lalu mengembalikan File-nya.
  Future<File> generateExcel(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    _validateShipment(p);
    final workbook = xls.Excel.createExcel();
    final sheetName = 'Laporan';
    final sheet = workbook[sheetName];
    if (workbook.getDefaultSheet() != null && workbook.getDefaultSheet() != sheetName) {
      workbook.delete(workbook.getDefaultSheet()!);
    }

    void setCell(int col, int row, dynamic value, {bool bold = false}) {
      final cell = sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      if (value is num) {
        cell.value = xls.DoubleCellValue(value.toDouble());
      } else {
        cell.value = xls.TextCellValue(value.toString());
      }
      if (bold) {
        cell.cellStyle = xls.CellStyle(bold: true);
      }
    }

    var row0 = 0;
    final company = settings.companyName.trim();
    final note = settings.headerNote.trim();
    if (company.isNotEmpty) {
      setCell(0, row0, company, bold: true);
      row0++;
      setCell(0, row0, 'Laporan Kubikasi Pengiriman');
      row0++;
    } else {
      setCell(0, row0, 'Laporan Kubikasi Pengiriman', bold: true);
      row0++;
    }
    if (note.isNotEmpty) {
      setCell(0, row0, note);
      row0++;
    }
    setCell(0, row0, 'Nomor Resi');
    setCell(1, row0, p.nomorResi);
    row0++;
    setCell(0, row0, 'Pengirim');
    setCell(1, row0, p.pengirim);
    row0++;
    setCell(0, row0, 'Tanggal');
    setCell(1, row0, _tanggalFmt.format(p.tanggal));
    row0 += 2;

    final tableHeaderRow = row0;
    final headers = ['No', 'Nama Barang', 'Jumlah', 'Panjang (cm)', 'Lebar (cm)', 'Tinggi (cm)', 'Berat/pcs (kg)', 'Total Berat (kg)', 'Volume', 'Kubikasi (m³)', 'Foto'];
    for (var c = 0; c < headers.length; c++) {
      setCell(c, tableHeaderRow, headers[c], bold: true);
    }

    var row = tableHeaderRow + 1;
    for (var i = 0; i < p.barang.length; i++) {
      final b = p.barang[i];
      setCell(0, row, i + 1);
      setCell(1, row, b.nama);
      setCell(2, row, b.jumlah);
      setCell(3, row, b.panjang);
      setCell(4, row, b.lebar);
      setCell(5, row, b.tinggi);
      setCell(6, row, b.berat);
      setCell(7, row, b.totalBerat);
      setCell(8, row, b.volume);
      setCell(9, row, b.kubikasi);
      setCell(10, row, b.photoPath != null && await File(b.photoPath!).exists() ? 'Ada' : 'Tidak ada');
      row++;
    }

    row += 1;
    setCell(0, row, 'TOTAL', bold: true);
    setCell(2, row, p.totalJumlah, bold: true);
    setCell(7, row, p.totalBerat, bold: true);
    setCell(8, row, p.totalVolume, bold: true);
    setCell(9, row, p.totalKubikasi, bold: true);

    for (var c = 0; c < headers.length; c++) {
      sheet.setColumnAutoFit(c);
    }

    final bytes = workbook.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel.');
    final dir = await _tempDir();
    final file = File('${dir.path}/Laporan_${_sanitize(p.nomorResi)}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> sharePdf(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    final built = await _buildPdf(p, settings);
    await Share.shareXFiles(
      [XFile(built.file.path)],
      text: built.hasPhotos
          ? 'Laporan Kubikasi - Resi ${p.nomorResi} (dengan foto)'
          : 'Laporan Kubikasi - Resi ${p.nomorResi}',
      subject: 'Laporan Kubikasi - Resi ${p.nomorResi}',
    );
  }

  Future<void> shareExcel(Pengiriman p, {ReportSettings settings = const ReportSettings()}) async {
    final file = await generateExcel(p, settings: settings);
    final photoFiles = await _compressedPhotoFiles(p, limit: _maxEmbeddedPhotos);
    await Share.shareXFiles(
      [XFile(file.path), ...photoFiles.map((f) => XFile(f.path))],
      text: photoFiles.isEmpty
          ? 'Laporan Kubikasi - Resi ${p.nomorResi}'
          : 'Laporan Kubikasi - Resi ${p.nomorResi} + ${photoFiles.length} foto terkompresi',
      subject: 'Laporan Kubikasi - Resi ${p.nomorResi}',
    );
  }

  /// Memuat foto barang untuk disisipkan ke PDF, dibatasi oleh [limit]
  /// agar tidak membebani memori. `truncated` bernilai true jika ada
  /// foto valid yang tidak ikut dimuat karena melebihi batas.
  Future<({List<_PhotoData> photos, bool truncated})> _loadPhotos(
    Pengiriman p, {
    required int limit,
  }) async {
    final validItems = <BarangItem>[];
    for (final item in p.barang) {
      final path = item.photoPath;
      if (path == null || path.trim().isEmpty) continue;
      if (await File(path).exists()) validItems.add(item);
    }

    final truncated = validItems.length > limit;
    final toLoad = truncated ? validItems.sublist(0, limit) : validItems;

    final result = <_PhotoData>[];
    for (final item in toLoad) {
      try {
        final bytes = await File(item.photoPath!).readAsBytes();
        if (bytes.isEmpty) continue;
        // Decode/resize/encode dilakukan di isolate terpisah supaya UI tetap
        // responsif ketika laporan berisi banyak foto beresolusi tinggi.
        final reportBytes = await compute(_preparePhotoForReportIsolate, bytes);
        if (reportBytes.isEmpty) continue;
        result.add(_PhotoData(item.nama, pw.MemoryImage(reportBytes)));
      } catch (_) {}
    }
    return (photos: result, truncated: truncated);
  }

  Future<Map<String, int>> _allocatePhotoQuotas(List<Pengiriman> items, int budget) async {
    final counts = <String, int>{};
    for (final item in items) {
      var count = 0;
      for (final b in item.barang) {
        final path = b.photoPath;
        if (path == null || path.trim().isEmpty) continue;
        if (await File(path).exists()) count++;
      }
      counts[item.id] = count;
    }

    final quotas = <String, int>{for (final item in items) item.id: 0};
    var remaining = budget;
    // Round-robin: satu foto per resi setiap putaran. Jika ada resi yang
    // sudah habis fotonya, slot berikutnya diberikan ke resi lain.
    while (remaining > 0) {
      var allocatedThisRound = false;
      for (final item in items) {
        if (remaining <= 0) break;
        final id = item.id;
        final current = quotas[id] ?? 0;
        if (current < (counts[id] ?? 0)) {
          quotas[id] = current + 1;
          remaining--;
          allocatedThisRound = true;
        }
      }
      if (!allocatedThisRound) break;
    }
    return quotas;
  }

  Future<int> _countValidPhotos(Pengiriman p) async {
    var count = 0;
    for (final item in p.barang) {
      final path = item.photoPath;
      if (path == null || path.trim().isEmpty) continue;
      if (await File(path).exists()) count++;
    }
    return count;
  }

  Future<List<File>> _compressedPhotoFiles(Pengiriman p, {int? limit}) async {
    final result = <File>[];
    final dir = await _tempDir();
    // Sertakan id pengiriman pada nama file: dua pengiriman berbeda dapat
    // memiliki barang dengan nama yang sama (mis. "Kardus"), dan tanpa id
    // di sini file kompresi milik pengiriman kedua akan menimpa milik
    // pengiriman pertama sebelum sempat dibagikan.
    final safeShipment = _sanitize(
      p.nomorResi.trim().isNotEmpty ? p.nomorResi : p.id,
    );
    var index = 0;
    for (final item in p.barang) {
      if (limit != null && result.length >= limit) break;
      final path = item.photoPath;
      if (path == null || path.trim().isEmpty) continue;
      final source = File(path);
      if (!await source.exists()) continue;
      try {
        final bytes = await source.readAsBytes();
        if (bytes.isEmpty) continue;
        final prepared = await compute(_preparePhotoForReportIsolate, bytes);
        final safeName = _sanitize(item.nama);
        final output = File(
          '${dir.path}/share_photo_${safeShipment}_${safeName}_${(index++ + 1).toString().padLeft(2, '0')}.jpg',
        );
        await output.writeAsBytes(prepared, flush: true);
        result.add(output);
      } catch (_) {}
    }
    return result;
  }

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.SizedBox(width: 140, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  pw.Widget _totalRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
}

Uint8List _preparePhotoForReportIsolate(Uint8List bytes) {
  const maxDimension = ExportService._reportPhotoMaxDimension;
  const quality = ExportService._reportPhotoJpegQuality;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    img.Image prepared = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      prepared = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDimension : null,
        height: decoded.height > decoded.width ? maxDimension : null,
        interpolation: img.Interpolation.linear,
      );
    }
    return Uint8List.fromList(img.encodeJpg(prepared, quality: quality));
  } catch (_) {
    return bytes;
  }
}

class _PhotoData {
  final String itemName;
  final pw.MemoryImage image;
  const _PhotoData(this.itemName, this.image);
}
