import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final availableHeight = media.size.height - media.viewInsets.bottom;
      final sheetHeight = availableHeight < media.size.height * 0.92
          ? availableHeight
          : media.size.height * 0.92;

      return Align(
        alignment: Alignment.bottomCenter,
        child: Material(
            color: Colors.white,
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              height: sheetHeight.toDouble(),
              child: _BarangFormContent(existing: existing),
            ),
          ),
        );
    },
  );
}

class _BarangFormContent extends StatefulWidget {
  final BarangItem? existing;
  const _BarangFormContent({this.existing});

  @override
  State<_BarangFormContent> createState() => _BarangFormContentState();
}

class _BarangFormContentState extends State<_BarangFormContent> {
  String? _photoPath;
  // Di-cache supaya tidak panggil File.existsSync() (I/O sync) di setiap
  // build(); hanya dihitung ulang saat _photoPath benar-benar berubah.
  bool _hasPhotoFile = false;
  bool _photoBusy = false;
  late final TextEditingController _beratCtrl;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaCtrl;
  late final TextEditingController _jumlahCtrl;
  late final TextEditingController _panjangCtrl;
  late final TextEditingController _lebarCtrl;
  late final TextEditingController _tinggiCtrl;
  late final TextEditingController _pengirimCtrl;
  late DateTime _tanggal;

  late final Listenable _previewListenable;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.existing?.photoPath;
    _hasPhotoFile = _photoPath != null &&
        _photoPath!.isNotEmpty &&
        File(_photoPath!).existsSync();

    final e = widget.existing;
    _beratCtrl = TextEditingController(text: _fmtInput(e?.berat));
    _namaCtrl = TextEditingController(text: e?.nama ?? '');
    _jumlahCtrl = TextEditingController(text: (e?.jumlah ?? 1).toString());
    _panjangCtrl = TextEditingController(text: _fmtInput(e?.panjang));
    _lebarCtrl = TextEditingController(text: _fmtInput(e?.lebar));
    _tinggiCtrl = TextEditingController(text: _fmtInput(e?.tinggi));
    _pengirimCtrl = TextEditingController(text: e?.pengirim ?? '');
    _tanggal = e?.tanggal ?? DateTime.now();
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
    _beratCtrl.dispose();
    _namaCtrl.dispose();
    _jumlahCtrl.dispose();
    _panjangCtrl.dispose();
    _lebarCtrl.dispose();
    _tinggiCtrl.dispose();
    _pengirimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            isEdit ? 'Edit Barang' : 'Tambah Barang',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _namaCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Barang',
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pengirimCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Pengirim',
              hintText: 'Contoh: PT Maju Jaya',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nama pengirim wajib diisi'
                : null,
          ),
          const SizedBox(height: 12),
          _buildTanggalPicker(),
          const SizedBox(height: 12),
          _buildPhotoPicker(),
          const SizedBox(height: 12),
          TextFormField(
            controller: _jumlahCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              prefixIcon: Icon(Icons.numbers_rounded, size: 20),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Jumlah tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _beratCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Berat per unit',
              suffixText: 'kg',
              prefixIcon: Icon(Icons.scale_outlined, size: 20),
            ),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (n == null || n < 0) return 'Berat tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _panjangCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Panjang', suffixText: 'cm'),
                  validator: _validateUkuran,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lebarCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Lebar', suffixText: 'cm'),
                  validator: _validateUkuran,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _tinggiCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tinggi', suffixText: 'cm'),
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
                Expanded(child: _buildPreviewBox(
                  title: 'VOLUME TIMBANG',
                  value: _previewVolume.toStringAsFixed(2).replaceAll('.', ','),
                  valueColor: AppColors.primary,
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildPreviewBox(
                  title: 'KUBIKASI',
                  value: _previewKubikasi.toStringAsFixed(3).replaceAll('.', ','),
                  valueColor: AppColors.primaryDark,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: _onSave,
            child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Barang'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreviewBox({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalPicker() {
    return InkWell(
      onTap: _pickTanggal,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Tanggal',
          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          DateFormat('dd MMM yyyy', 'id_ID').format(_tanggal),
          style: const TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ),
    );
  }

  Future<void> _pickTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (hasil == null) return;
    setState(() {
      // Pertahankan jam:menit asli, hanya tanggalnya yang diganti.
      _tanggal = DateTime(
        hasil.year,
        hasil.month,
        hasil.day,
        _tanggal.hour,
        _tanggal.minute,
      );
    });
  }

  Widget _buildPhotoPicker() {
    final hasPhoto = _hasPhotoFile;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 68, height: 68,
              child: hasPhoto
                  ? Image.file(
                      File(_photoPath!),
                      fit: BoxFit.cover,
                      // Decode sesuai ukuran tampil (bukan resolusi asli
                      // 1400x1400) supaya tidak boros memory per thumbnail.
                      cacheWidth:
                          (68 * MediaQuery.of(context).devicePixelRatio)
                              .round(),
                      cacheHeight:
                          (68 * MediaQuery.of(context).devicePixelRatio)
                              .round(),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFEFF2F5),
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.muted, size: 28),
                      ),
                    )
                  : const ColoredBox(
                      color: Color(0xFFEFF2F5),
                      child: Icon(Icons.photo_camera_outlined, color: AppColors.muted, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Foto Barang', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _photoBusy ? null : () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Kamera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _photoBusy ? null : () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Galeri'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasPhoto)
            IconButton(
              tooltip: 'Hapus foto',
              onPressed: _photoBusy ? null : _removePhoto,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      setState(() => _photoBusy = true);
      final picked = await ImagePicker().pickImage(
        source: source, imageQuality: 82, maxWidth: 1400, maxHeight: 1400,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final photoDir = Directory('${dir.path}/barang_photos');
      await photoDir.create(recursive: true);
      final dot = picked.path.lastIndexOf('.');
      final ext = dot >= 0 ? picked.path.substring(dot) : '.jpg';
      final file = File('${photoDir.path}/barang_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(picked.path).copy(file.path);

      // Hapus file foto lama (kalau ada) supaya tidak jadi sampah menumpuk
      // di storage tiap kali user ganti foto.
      final oldPath = _photoPath;
      if (oldPath != null && oldPath.isNotEmpty && oldPath != file.path) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (_) {
            // Gagal hapus file lama bukan fatal, foto baru tetap dipakai.
          }
        }
      }

      if (mounted) {
        setState(() {
          _photoPath = file.path;
          _hasPhotoFile = true;
        });
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final oldPath = _photoPath;
    setState(() {
      _photoPath = null;
      _hasPhotoFile = false;
    });
    if (oldPath != null && oldPath.isNotEmpty) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (_) {
          // Abaikan; foto sudah dilepas dari form walau file gagal dihapus.
        }
      }
    }
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
        berat: double.tryParse(_beratCtrl.text.replaceAll(',', '.')) ?? 0,
        photoPath: _photoPath,
        panjang: double.parse(_panjangCtrl.text.replaceAll(',', '.')),
        lebar: double.parse(_lebarCtrl.text.replaceAll(',', '.')),
        tinggi: double.parse(_tinggiCtrl.text.replaceAll(',', '.')),
        pengirim: _pengirimCtrl.text.trim(),
        tanggal: _tanggal,
      );
      Navigator.of(context).pop(item);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
