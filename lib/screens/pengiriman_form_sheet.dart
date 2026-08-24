import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../widgets/barang_form_sheet.dart';
import 'barcode_scanner_screen.dart';

Future<Pengiriman?> showPengirimanFormSheet(
  BuildContext context, {
  Pengiriman? existing,
}) {
  return showModalBottomSheet<Pengiriman>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PengirimanForm(existing: existing),
  );
}

class _PengirimanForm extends StatefulWidget {
  final Pengiriman? existing;
  const _PengirimanForm({this.existing});

  @override
  State<_PengirimanForm> createState() => _PengirimanFormState();
}

class _PengirimanFormState extends State<_PengirimanForm> {
  late final TextEditingController _pengirim;
  late final TextEditingController _resi;
  late DateTime _tanggal;
  late List<BarangItem> _barang;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _pengirim = TextEditingController(text: e?.pengirim ?? '');
    _resi = TextEditingController(text: e?.nomorResi ?? '');
    _tanggal = e?.tanggal ?? DateTime.now();
    _barang = e?.barang.map((x) => x.copyWith()).toList() ?? [];
  }

  @override
  void dispose() {
    _pengirim.dispose();
    _resi.dispose();
    super.dispose();
  }

  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> _addItem() async {
    final item = await showBarangFormSheet(context);
    if (item != null && mounted) setState(() => _barang.add(item));
  }

  Future<void> _editItem(int index) async {
    final item = await showBarangFormSheet(context, existing: _barang[index]);
    if (item != null && mounted) setState(() => _barang[index] = item);
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _resi.text = result.trim());
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _tanggal = d);
  }

  void _save() {
    final pengirim = _pengirim.text.trim();
    final resi = _resi.text.trim();

    if (pengirim.isEmpty) {
      _error('Nama pengirim wajib diisi.');
      return;
    }
    if (_barang.isEmpty) {
      _error('Tambahkan minimal satu barang.');
      return;
    }
    if (resi.isEmpty) {
      _error('Nomor resi wajib diisi atau dipindai.');
      return;
    }

    Navigator.pop(
      context,
      Pengiriman(
        id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        pengirim: pengirim,
        tanggal: _tanggal,
        nomorResi: resi,
        barang: List.of(_barang),
      ),
    );
  }

  void _error(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final maxHeight = media.size.height * .94;
    final availableHeight = media.size.height - bottom;
    final sheetHeight = availableHeight.clamp(0.0, maxHeight);
    final totalK = _barang.fold<double>(0, (s, e) => s + e.kubikasi);
    final totalV = _barang.fold<double>(0, (s, e) => s + e.volume);
    final totalB = _barang.fold<double>(0, (s, e) => s + e.totalBerat);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .94,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottom),
          children: [
            Center(child: Container(width: 42, height: 4, color: AppColors.border)),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Pengiriman Baru' : 'Edit Pengiriman',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pengirim,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Pengirim',
                hintText: 'Isi sekali untuk seluruh barang',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(_date(_tanggal)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text('Daftar Barang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Barang'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_barang.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('Belum ada barang. Tekan “Tambah Barang”.'),
              )
            else
              ...List.generate(_barang.length, (i) {
                final b = _barang[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _editItem(i),
                    title: Text(b.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${b.jumlah} × ${b.panjang}×${b.lebar}×${b.tinggi} cm • Kubikasi ${b.kubikasi.toStringAsFixed(3)} m³',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _barang.removeAt(i)),
                    ),
                  ),
                );
              }),
            if (_barang.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: ${_barang.length} jenis • Volume ${totalV.toStringAsFixed(2)} • '
                  'Kubikasi ${totalK.toStringAsFixed(3)} m³ • Berat ${totalB.toStringAsFixed(2)} kg',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Nomor Resi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _resi,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nomor Resi',
                hintText: 'Scan barcode atau ketik manual',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Barcode Resi'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Selesai & Simpan Pengiriman'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pengiriman tidak disimpan sebagai transaksi selesai sebelum nomor resi tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
