from pathlib import Path

path = Path('lib/services/export_service.dart')
s = path.read_text()
start = s.index('  Future<({File file, bool hasPhotos})> _buildPdf(')
end = s.index('  /// Membuat satu Excel gabungan dari beberapa pengiriman.', start)
new = r'''  pw.Widget _reportFooter(pw.Context context) => pw.Align(
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
    required DateTime tanggal,
  }) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text('Resi: $resi', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Pengirim: $pengirim', style: const pw.TextStyle(fontSize: 9)),
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
        _infoRow('Tanggal', _tanggalFmt.format(p.tanggal)), _infoRow('Jumlah Jenis Barang', '${p.barang.length}'),
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
          _photoSection(photos: photos, title: 'DOKUMENTASI FOTO', resi: p.nomorResi, pengirim: p.pengirim, tanggal: p.tanggal),
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

  /// Membuat satu PDF gabungan dari beberapa pengiriman.
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
          headers: const ['No', 'Tanggal', 'Resi', 'Pengirim', 'Barang', 'Berat (kg)', 'Kubikasi (m³)'],
          data: [for (var i = 0; i < sorted.length; i++) ['${i + 1}', _tanggalFmt.format(sorted[i].tanggal), sorted[i].nomorResi, sorted[i].pengirim, '${sorted[i].totalJumlah}', sorted[i].totalBerat.toStringAsFixed(2), sorted[i].totalKubikasi.toStringAsFixed(3)]],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), cellStyle: const pw.TextStyle(fontSize: 7.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)), border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
          columnWidths: const {0: pw.FixedColumnWidth(22), 1: pw.FixedColumnWidth(55), 2: pw.FlexColumnWidth(1.25), 3: pw.FlexColumnWidth(1.4), 4: pw.FixedColumnWidth(38), 5: pw.FixedColumnWidth(50), 6: pw.FixedColumnWidth(58)},
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF2563EB), width: 1), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RINGKASAN TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)), pw.SizedBox(height: 6),
            _totalRow('Total Pengiriman', '${sorted.length}'), _totalRow('Total Jumlah Barang', '$totalJumlah'), _totalRow('Total Berat', '${totalBerat.toStringAsFixed(2)} kg'), _totalRow('Total Volume', totalVolume.toStringAsFixed(2)), _totalRow('Total Kubikasi', '${totalKubikasi.toStringAsFixed(3)} m³'),
          ]),
        ),
        pw.SizedBox(height: 18), pw.Text('Dicetak: ${_waktuFmt.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF64748B))),
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
        build: (context) => [_photoSection(photos: photos, title: 'DOKUMENTASI FOTO — RESI ${shipment.nomorResi}', resi: shipment.nomorResi, pengirim: shipment.pengirim, tanggal: shipment.tanggal)],
      ));
    }

    if (anyTruncated) {
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), footer: _reportFooter,
        header: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          ..._headerLines(settings, 'Rekap Laporan Kubikasi Pengiriman', logo), pw.SizedBox(height: 4), pw.Divider(thickness: 1),
        ]),
        build: (context) => [
          pw.Text('CATATAN DOKUMENTASI', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Dokumentasi foto dibatasi maksimal $_maxEmbeddedPhotos foto untuk menjaga ukuran file dan penggunaan memori. Foto dialokasikan secara merata antar-resi.', style: const pw.TextStyle(fontSize: 9)),
        ],
      ));
    }

    final dir = await _tempDir();
    final file = File('${dir.path}/Rekap_Kubikasi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return (file: file, hasPhotos: totalEmbedded > 0);
  }

'''
path.write_text(s[:start] + new + s[end:])
print('patched', path)
PY