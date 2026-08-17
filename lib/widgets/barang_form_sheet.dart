import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/barang_item.dart';

/// Menampilkan bottom sheet untuk tambah/edit barang.
/// Mengembalikan [BarangItem] baru jika user menekan simpan, atau null jika batal.
Future<BarangItem?> showBarangFormSheet(
  BuildContext context, {
  BarangItem? existing,
}) {
  return showModalBottomSheet<BarangItem>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _BarangFormContent(existing: existing),
    ),
  );
}

class _BarangFormContent extends StatefulWidget {
  final BarangItem? existing;
  const _BarangFormContent({this.existing});

  @override
  State<_BarangFormContent> createState() => _BarangFormContentState();
}

class _BarangFormContentState extends State<_BarangFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  late final TextEditingController _jumlahCtrl;
  late final TextEditingController _panjangCtrl;
  late final TextEditingController _lebarCtrl;
  late final TextEditingController _tinggiCtrl;

  late final Listenable _previewListenable;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _namaCtrl = TextEditingController(text: e?.nama ?? '');
    _jumlahCtrl = TextEditingController(text: (e?.jumlah ?? 1).toString());
    _panjangCtrl = TextEditingController(text: _fmtInput(e?.panjang));
    _lebarCtrl = TextEditingController(text: _fmtInput(e?.lebar));
    _tinggiCtrl = TextEditingController(text: _fmtInput(e?.tinggi));
    // Gabungkan listenable dari 4 controller supaya preview VOL 5000 /
    // KUBIKASI ikut update tiap ketik, TANPA setState di level form.
    // Kalau pakai setState di sini, seluruh form (termasuk semua
    // TextFormField) ikut rebuild tiap keystroke, dan di sebagian
    // keyboard Android ini bisa membuat field kehilangan fokus saat
    // sedang diketik. Dengan Listenable.merge + AnimatedBuilder yang
    // membungkus HANYA kotak preview, TextFormField tidak pernah
    // di-rebuild ulang sehingga fokus/ketikan tidak terganggu.
    _previewListenable = Listenable.merge(
      [_jumlahCtrl, _panjangCtrl, _lebarCtrl, _tinggiCtrl],
    );
  }

  String _fmtInput(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  double get _previewVolume {
    final jumlah = int.tryParse(_jumlahCtrl.text) ?? 0;
    final p = double.tryParse(_panjangCtrl.text.replaceAll(',', '.')) ?? 0;
    final l = double.tryParse(_lebarCtrl.text.replaceAll(',', '.')) ?? 0;
    final t = double.tryParse(_tinggiCtrl.text.replaceAll(',', '.')) ?? 0;
    return (p * l * t / kFaktorVolumetrik) * jumlah;
  }

  double get _previewKubikasi {
    final jumlah = int.tryParse(_jumlahCtrl.text) ?? 0;
    final p = double.tryParse(_panjangCtrl.text.replaceAll(',', '.')) ?? 0;
    final l = double.tryParse(_lebarCtrl.text.replaceAll(',', '.')) ?? 0;
    final t = double.tryParse(_tinggiCtrl.text.replaceAll(',', '.')) ?? 0;
    return (p * l * t / kFaktorKubikasi) * jumlah;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _jumlahCtrl.dispose();
    _panjangCtrl.dispose();
    _lebarCtrl.dispose();
    _tinggiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEdit ? 'Edit Barang' : 'Tambah Barang',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jumlahCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Jumlah tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _panjangCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Panjang (cm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateUkuran,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lebarCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Lebar (cm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateUkuran,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _tinggiCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tinggi (cm)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateUkuran,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _previewListenable,
                builder: (context, _) => Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VOL 5000',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _previewVolume
                                  .toStringAsFixed(2)
                                  .replaceAll('.', ','),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KUBIKASI (M³)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _previewKubikasi
                                  .toStringAsFixed(3)
                                  .replaceAll('.', ','),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _onSave,
                child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Barang'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateUkuran(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null || n <= 0) return 'Tidak valid';
    return null;
  }

  void _onSave() {
    try {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Masih ada isian yang belum valid, cek lagi ya.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final item = BarangItem(
        id: widget.existing?.id ?? const Uuid().v4(),
        nama: _namaCtrl.text.trim(),
        jumlah: int.parse(_jumlahCtrl.text),
        panjang: double.parse(_panjangCtrl.text.replaceAll(',', '.')),
        lebar: double.parse(_lebarCtrl.text.replaceAll(',', '.')),
        tinggi: double.parse(_tinggiCtrl.text.replaceAll(',', '.')),
      );
      Navigator.of(context).pop(item);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
