import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';
import '../services/photo_storage_service.dart';

Future<BarangItem?> showBarangFormSheet(
  BuildContext context, {
  BarangItem? existing,
  String? initialName,
  bool focusQuantity = false,
  FutureOr<void> Function(BarangItem item)? onSaveAndAddAnother,
}) {
  return showModalBottomSheet<BarangItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BarangForm(
      existing: existing,
      initialName: initialName,
      focusQuantity: focusQuantity,
      onSaveAndAddAnother: onSaveAndAddAnother,
    ),
  );
}

class _BarangForm extends StatefulWidget {
  final BarangItem? existing;
  final String? initialName;
  final bool focusQuantity;
  final FutureOr<void> Function(BarangItem item)? onSaveAndAddAnother;
  const _BarangForm({
    this.existing,
    this.initialName,
    this.focusQuantity = false,
    this.onSaveAndAddAnother,
  });

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
  final Set<String> _createdPhotos = <String>{};
  final Set<Future<void>> _pendingPhotoCopies = <Future<void>>{};
  bool _saved = false;
  bool _busy = false;
  late final Listenable _previewListenable;
  late final FocusNode _pFocus, _lFocus, _tFocus, _jumlahFocus, _beratFocus;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? widget.initialName ?? '');
    _jumlah = TextEditingController(text: '${e?.jumlah ?? 1}');
    _berat = TextEditingController(text: e == null ? '' : _n(e.berat));
    _p = TextEditingController(text: e == null ? '' : _n(e.panjang));
    _l = TextEditingController(text: e == null ? '' : _n(e.lebar));
    _t = TextEditingController(text: e == null ? '' : _n(e.tinggi));
    _photo = e?.photoPath;
    _previewListenable = Listenable.merge([_jumlah, _p, _l, _t]);
    _pFocus = FocusNode();
    _lFocus = FocusNode();
    _tFocus = FocusNode();
    _jumlahFocus = FocusNode();
    _beratFocus = FocusNode();
    if (widget.focusQuantity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumlahFocus.requestFocus();
        _jumlah.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _jumlah.text.length,
        );
      });
    }
  }

  String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  double? _parseNumber(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  double _d(String s) => _parseNumber(s) ?? 0;

  bool get _hasChanges {
    final original = widget.existing;
    if (original == null) {
      return _nama.text.trim() != (widget.initialName ?? '').trim() ||
          _p.text.trim().isNotEmpty ||
          _l.text.trim().isNotEmpty ||
          _t.text.trim().isNotEmpty ||
          _jumlah.text.trim() != '1' ||
          _berat.text.trim().isNotEmpty ||
          _photo != null;
    }
    return _nama.text.trim() != original.nama || _p.text.trim() != _n(original.panjang) || _l.text.trim() != _n(original.lebar) || _t.text.trim() != _n(original.tinggi) || _jumlah.text.trim() != original.jumlah.toString() || _berat.text.trim() != _n(original.berat) || _photo != original.photoPath;
  }

  Future<void> _confirmDiscard() async {
    if (!_hasChanges || !mounted) { Navigator.pop(context); return; }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: const Text('Isian yang belum disimpan akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Tetap di sini')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Buang')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_saved && _createdPhotos.isNotEmpty) {
      final paths = List<String>.from(_createdPhotos);
      final copies = List<Future<void>>.from(_pendingPhotoCopies);
      unawaited(() async {
        if (copies.isNotEmpty) await Future.wait(copies, eagerError: false);
        await PhotoStorageService.deleteAll(paths);
      }());
    }
    for (final c in [_nama, _jumlah, _berat, _p, _l, _t]) {
      c.dispose();
    }
    for (final f in [
      _pFocus,
      _lFocus,
      _tFocus,
      _jumlahFocus,
      _beratFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        _showPickerMessage(
          status.isPermanentlyDenied
              ? 'Izin kamera ditolak permanen. Aktifkan lewat Setelan.'
              : 'Izin kamera diperlukan untuk mengambil foto.',
          showSettingsAction: status.isPermanentlyDenied,
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        final dir = await getApplicationDocumentsDirectory();
        final target = File(
          '${dir.path}/barang_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        _createdPhotos.add(target.path);
        final copyFuture = File(picked.path).copy(target.path);
        _pendingPhotoCopies.add(copyFuture);
        try {
          await copyFuture;
        } catch (_) {
          await PhotoStorageService.delete(target.path);
          _createdPhotos.remove(target.path);
          rethrow;
        } finally {
          _pendingPhotoCopies.remove(copyFuture);
        }
        if (!mounted) return;
        final previous = _photo;
        setState(() => _photo = target.path);
        if (previous != null &&
            _createdPhotos.contains(previous) &&
            previous != target.path) {
          _createdPhotos.remove(previous);
          await PhotoStorageService.delete(previous);
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isPermissionError =
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied';
      _showPickerMessage(
        isPermissionError
            ? 'Izin akses ditolak. Aktifkan lewat Setelan.'
            : 'Gagal mengambil foto (${e.code}).',
        showSettingsAction: isPermissionError,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPickerMessage(String message, {bool showSettingsAction = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: showSettingsAction
            ? SnackBarAction(label: 'Setelan', onPressed: openAppSettings)
            : null,
      ),
    );
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  Future<void> _save({bool addAnother = false}) async {
    if (!_key.currentState!.validate()) return;
    final item = BarangItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      nama: _nama.text.trim().isEmpty ? (widget.initialName ?? 'Barang') : _nama.text.trim(),
      jumlah: int.parse(_jumlah.text),
      panjang: _d(_p.text),
      lebar: _d(_l.text),
      tinggi: _d(_t.text),
      berat: _d(_berat.text),
      photoPath: _photo,
    );
    if (addAnother && widget.onSaveAndAddAnother != null) {
      await widget.onSaveAndAddAnother!(item);
      if (!mounted) return;
      final handedOffPhoto = item.photoPath;
      if (handedOffPhoto != null) _createdPhotos.remove(handedOffPhoto);
      _saved = false;
      setState(() {
        _nama.clear();
        _jumlah.text = '1';
        _berat.clear();
        _p.clear();
        _l.clear();
        _t.clear();
        _photo = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pFocus.requestFocus();
      });
      return;
    }
    _saved = true;
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom;
    final maxHeight = media.size.height * .92;
    final availableHeight = media.size.height - bottom;
    final sheetHeight = availableHeight.clamp(0.0, maxHeight);
    return PopScope(
      canPop: !_busy && !_hasChanges,
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !_busy) _confirmDiscard(); },
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: sheetHeight,
          child: Form(
            key: _key,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 40 + bottom + 96),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    color: AppColors.border,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null ? 'Tambah Barang' : 'Edit Barang',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _size(_p, 'Panjang', _pFocus, _lFocus)),
                    const SizedBox(width: 8),
                    Expanded(child: _size(_l, 'Lebar', _lFocus, _tFocus)),
                    const SizedBox(width: 8),
                    Expanded(child: _size(_t, 'Tinggi', _tFocus, _jumlahFocus)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jumlah,
                  focusNode: _jumlahFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Jumlah', hintText: '1'),
                  scrollPadding: const EdgeInsets.only(bottom: 180),
                  onFieldSubmitted: (_) => _beratFocus.requestFocus(),
                  validator: (v) {
                    final x = int.tryParse(v?.trim() ?? '');
                    return x == null || x <= 0 ? 'Jumlah harus lebih dari 0' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _berat,
                  focusNode: _beratFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Berat per unit', hintText: '0', suffixText: 'kg'),
                  scrollPadding: const EdgeInsets.only(bottom: 180),
                  onFieldSubmitted: (_) => _save(),
                  validator: (v) {
                    final value = _parseNumber(v ?? '');
                    return value == null || value < 0 ? 'Berat tidak valid' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nama,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Nama Barang (opsional)', hintText: 'Otomatis jika dikosongkan'),
                  scrollPadding: const EdgeInsets.only(bottom: 180),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _showPhotoSourceSheet,
                        icon: Icon(
                          _photo == null
                              ? Icons.add_a_photo_outlined
                              : Icons.photo_camera_back_outlined,
                        ),
                        label: Text(
                          _photo == null ? 'Foto Barang' : 'Ganti Foto',
                        ),
                      ),
                    ),
                    if (_photo != null) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => showPhotoPreview(context, _photo!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photo!),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            cacheWidth: 162,
                            cacheHeight: 162,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 54,
                              height: 54,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _previewListenable,
                  builder: (context, _) => Row(
                    children: [
                      Expanded(
                        child: _metric(
                          'VOLUME TIMBANG',
                          _volume.toStringAsFixed(2),
                          'kg',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metric(
                          'KUBIKASI',
                          _kubikasi.toStringAsFixed(3),
                          'm³',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.existing == null &&
                    widget.onSaveAndAddAnother != null) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _save(addAnother: true),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Simpan & Tambah Lagi'),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(
                    widget.existing == null
                        ? 'Tambah Barang'
                        : 'Simpan Perubahan',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _size(TextEditingController c, String label, FocusNode focus, FocusNode next) => TextFormField(
        controller: c,
        onTap: () {
          if (c.text.isNotEmpty) {
            c.selection = TextSelection(
              baseOffset: 0,
              extentOffset: c.text.length,
            );
          }
        },
        focusNode: focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, hintText: '0', suffixText: 'cm'),
        scrollPadding: const EdgeInsets.only(bottom: 180),
        onFieldSubmitted: (_) => next.requestFocus(),
        validator: (v) {
          final value = _parseNumber(v ?? '');
          return value == null || value <= 0
              ? '$label harus lebih dari 0'
              : null;
        },
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
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '$value $suffix',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
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

void showPhotoPreview(BuildContext context, String path) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _PhotoPreview(path: path),
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  final String path;
  const _PhotoPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.file(File(path)),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
