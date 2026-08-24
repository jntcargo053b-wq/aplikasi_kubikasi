import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';

Future<BarangItem?> showBarangFormSheet(
  BuildContext context, {
  BarangItem? existing,
}) {
  return showModalBottomSheet<BarangItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BarangForm(existing: existing),
  );
}

class _BarangForm extends StatefulWidget {
  final BarangItem? existing;
  const _BarangForm({this.existing});

  @override
  State<_BarangForm> createState() => _BarangFormState();
}

class _BarangFormState extends State<_BarangForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _jumlah;
  late final TextEditingController _berat;
  late final TextEditingController _p;
  late final TextEditingController _l;
  late final TextEditingController _t;
  String? _photo;
  bool _busy = false;
  late final Listenable _previewListenable;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _jumlah = TextEditingController(text: '${e?.jumlah ?? 1}');
    _berat = TextEditingController(text: e == null ? '' : _n(e.berat));
    _p = TextEditingController(text: e == null ? '' : _n(e.panjang));
    _l = TextEditingController(text: e == null ? '' : _n(e.lebar));
    _t = TextEditingController(text: e == null ? '' : _n(e.tinggi));
    _photo = e?.photoPath;

    _previewListenable = Listenable.merge([
      _jumlah,
      _p,
      _l,
      _t,
    ]);
  }

  String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  double _d(String s) => double.tryParse(s.replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    for (final c in [_nama, _jumlah, _berat, _p, _l, _t]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        final dir = await getApplicationDocumentsDirectory();
        final target = File('${dir.path}/barang_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await File(picked.path).copy(target.path);
        if (!mounted) return;
        setState(() => _photo = target.path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final item = BarangItem(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      nama: _nama.text.trim(),
      jumlah: int.parse(_jumlah.text),
      panjang: _d(_p.text),
      lebar: _d(_l.text),
      tinggi: _d(_t.text),
      berat: _d(_berat.text),
      photoPath: _photo,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final maxHeight = media.size.height * .92;
    final availableHeight = media.size.height - bottom;
    final sheetHeight = availableHeight.clamp(0.0, maxHeight);
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .92,
        child: Form(
          key: _key,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottom),
            children: [
              Center(child: Container(width: 42, height: 4, color: AppColors.border)),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Tambah Barang' : 'Edit Barang',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nama,
                decoration: const InputDecoration(labelText: 'Nama Barang'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jumlah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
                validator: (v) {
                  final x = int.tryParse(v ?? '');
                  return x == null || x <= 0 ? 'Jumlah tidak valid' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _berat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Berat per unit', suffixText: 'kg'),
                validator: (v) => _d(v ?? '') < 0 ? 'Berat tidak valid' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _size(_p, 'Panjang')),
                  const SizedBox(width: 8),
                  Expanded(child: _size(_l, 'Lebar')),
                  const SizedBox(width: 8),
                  Expanded(child: _size(_t, 'Tinggi')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(_photo == null ? 'Foto Barang' : 'Ganti Foto'),
                    ),
                  ),
                  if (_photo != null && File(_photo!).existsSync()) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_photo!), width: 54, height: 54, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _previewListenable,
                builder: (context, _) => Row(
                  children: [
                    Expanded(child: _metric('VOLUME TIMBANG', _volume.toStringAsFixed(2), '')),
                    const SizedBox(width: 8),
                    Expanded(child: _metric('KUBIKASI', _kubikasi.toStringAsFixed(3), 'm³')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(widget.existing == null ? 'Tambah Barang' : 'Simpan Perubahan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _size(TextEditingController c, String label) => Expanded(
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: 'cm'),
          validator: (v) => _d(v ?? '') <= 0 ? 'Wajib' : null,
        ),
      );

  Widget _metric(String title, String value, String suffix) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$value $suffix', maxLines: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );

  double get _volume =>
      (_d(_p.text) * _d(_l.text) * _d(_t.text) / kFaktorVolumetrik) *
      (int.tryParse(_jumlah.text) ?? 0);

  double get _kubikasi =>
      (_d(_p.text) * _d(_l.text) * _d(_t.text) / kFaktorKubikasi) *
      (int.tryParse(_jumlah.text) ?? 0);
}
