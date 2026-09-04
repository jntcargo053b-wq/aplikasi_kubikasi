import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../services/indonesia_region_service.dart';
import '../services/photo_storage_service.dart';
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
  late final Set<String> _originalPhotoPaths;
  final Set<String> _sessionPhotoPaths = <String>{};

  List<IndonesiaRegion> _kotaKabupaten = const [];
  List<IndonesiaRegion> _kecamatan = const [];
  IndonesiaRegion? _selectedKotaKabupaten;
  IndonesiaRegion? _selectedKecamatan;
  bool _loadingWilayah = true;
  bool _loadingKecamatan = false;
  String? _wilayahError;
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _pengirim = TextEditingController(text: e?.pengirim ?? '');
    _resi = TextEditingController(text: e?.nomorResi ?? '');
    _tanggal = e?.tanggal ?? DateTime.now();
    _barang = e?.barang.map((x) => x.copyWith()).toList() ?? [];
    _originalPhotoPaths = _barang
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet();
    _loadWilayah();
  }

  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> _loadWilayah() async {
    try {
      final data = await IndonesiaRegionService.loadAllKabupatenKota();
      if (!mounted) return;
      IndonesiaRegion? selected;
      if (widget.existing?.kotaKabupaten.isNotEmpty == true) {
        final target = widget.existing!.kotaKabupaten.trim().toLowerCase();
        for (final item in data) {
          if (item.name.trim().toLowerCase() == target) {
            selected = item;
            break;
          }
        }
      }
      setState(() {
        _kotaKabupaten = data;
        _selectedKotaKabupaten = selected;
        _loadingWilayah = false;
        _wilayahError = null;
      });
      if (selected != null) await _loadKecamatan(selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingWilayah = false;
        _wilayahError = 'Gagal memuat daftar kota/kabupaten. Periksa koneksi internet.';
      });
    }
  }

  Future<void> _loadKecamatan(IndonesiaRegion kota) async {
    setState(() {
      _loadingKecamatan = true;
      _kecamatan = const [];
      _selectedKecamatan = null;
    });
    try {
      final data = await IndonesiaRegionService.loadKecamatan(kota.code);
      if (!mounted) return;
      IndonesiaRegion? selected;
      if (widget.existing?.kecamatan.isNotEmpty == true) {
        final target = widget.existing!.kecamatan.trim().toLowerCase();
        for (final item in data) {
          if (item.name.trim().toLowerCase() == target) {
            selected = item;
            break;
          }
        }
      }
      setState(() {
        _kecamatan = data;
        _selectedKecamatan = selected;
        _loadingKecamatan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingKecamatan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kecamatan gagal dimuat. Silakan coba pilih kota/kabupaten lagi.')),
      );
    }
  }

  Future<void> _addItem() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final item = await showBarangFormSheet(
        context,
        initialName: 'Item${_barang.length + 1}',
      );
      if (item != null && mounted) {
        if (item.photoPath != null && !_originalPhotoPaths.contains(item.photoPath)) {
          _sessionPhotoPaths.add(item.photoPath!);
        }
        setState(() => _barang.add(item));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editItem(int index) async {
    if (_busy || index < 0 || index >= _barang.length) return;
    final before = _barang[index];
    final beforePhoto = before.photoPath;
    setState(() => _busy = true);
    try {
      final item = await showBarangFormSheet(context, existing: before);
      if (item != null && mounted) {
        final newPhoto = item.photoPath;
        if (newPhoto != null && newPhoto.isNotEmpty && !_originalPhotoPaths.contains(newPhoto) && newPhoto != beforePhoto) {
          _sessionPhotoPaths.add(newPhoto);
        }
        if (beforePhoto != null && _sessionPhotoPaths.contains(beforePhoto)) {
          _sessionPhotoPaths.add(beforePhoto);
        }
        setState(() => _barang[index] = item);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeItem(int index) async {
    if (_busy || index < 0 || index >= _barang.length) return;
    final removed = _barang[index];
    setState(() => _busy = true);
    try {
      setState(() => _barang.removeAt(index));
      final path = removed.photoPath;
      if (path != null && _sessionPhotoPaths.contains(path)) {
        _sessionPhotoPaths.remove(path);
        await PhotoStorageService.delete(path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanResi() async {
    if (_busy) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) setState(() => _resi.text = result);
  }

  void _save() {
    if (_pengirim.text.trim().isEmpty ||
        _resi.text.trim().isEmpty ||
        _barang.isEmpty ||
        _selectedKotaKabupaten == null ||
        _selectedKecamatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi pengirim, kota/kabupaten, kecamatan, resi, dan minimal satu barang.')),
      );
      return;
    }
    final result = Pengiriman(
      id: widget.existing?.id ?? const Uuid().v4(),
      pengirim: _pengirim.text.trim(),
      tanggal: _tanggal,
      nomorResi: _resi.text.trim(),
      kotaKabupaten: _selectedKotaKabupaten!.name,
      kecamatan: _selectedKecamatan!.name,
      barang: _barang.map((x) => x.copyWith()).toList(),
    );
    _saved = true;
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    if (!_saved && _sessionPhotoPaths.isNotEmpty) {
      final paths = List<String>.from(_sessionPhotoPaths);
      Future.microtask(() => PhotoStorageService.deleteAll(paths));
    }
    _pengirim.dispose();
    _resi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 42, height: 4, color: AppColors.border)),
              const SizedBox(height: 16),
              Text(
                widget.existing == null ? 'Tambah Pengiriman' : 'Edit Pengiriman',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pengirim,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nama Pengirim'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tanggal,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) setState(() => _tanggal = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal'),
                  child: Row(
                    children: [
                      Expanded(child: Text(_date(_tanggal))),
                      const Icon(Icons.calendar_today_outlined, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingWilayah)
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Kota/Kabupaten'),
                  child: Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Memuat daftar wilayah...')]),
                )
              else
                DropdownButtonFormField<IndonesiaRegion>(
                  key: ValueKey(_selectedKotaKabupaten?.code ?? 'kota-kabupaten-none'),
                  initialValue: _selectedKotaKabupaten,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kota/Kabupaten',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  hint: const Text('Pilih kota/kabupaten'),
                  items: _kotaKabupaten
                      .map((item) => DropdownMenuItem<IndonesiaRegion>(
                            value: item,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedKotaKabupaten = value);
                          _loadKecamatan(value);
                        },
                ),
              if (_wilayahError != null) ...[
                const SizedBox(height: 6),
                Text(_wilayahError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _busy ? null : _loadWilayah, icon: const Icon(Icons.refresh, size: 18), label: const Text('Muat ulang wilayah')),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<IndonesiaRegion>(
                key: ValueKey(_selectedKecamatan?.code ?? 'kecamatan-none-${_selectedKotaKabupaten?.code ?? ''}'),
                initialValue: _selectedKecamatan,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kecamatan',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                hint: Text(_selectedKotaKabupaten == null ? 'Pilih kota/kabupaten terlebih dahulu' : 'Pilih kecamatan'),
                items: _kecamatan
                    .map((item) => DropdownMenuItem<IndonesiaRegion>(
                          value: item,
                          child: Text(item.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (_selectedKotaKabupaten == null || _loadingKecamatan || _busy)
                    ? null
                    : (value) => setState(() => _selectedKecamatan = value),
              ),
              if (_loadingKecamatan) ...[
                const SizedBox(height: 6),
                const Align(alignment: Alignment.centerLeft, child: LinearProgressIndicator(minHeight: 2)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _resi,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Nomor Resi',
                  suffixIcon: IconButton(
                    tooltip: 'Scan Resi',
                    onPressed: _busy ? null : _scanResi,
                    icon: const Icon(Icons.qr_code_scanner_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Text('Daftar Barang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  OutlinedButton.icon(onPressed: _busy ? null : _addItem, icon: const Icon(Icons.add), label: const Text('Tambah Barang')),
                ],
              ),
              const SizedBox(height: 8),
              if (_barang.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Belum ada barang.')))
              else
                ..._barang.asMap().entries.map((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: _busy ? null : () => _editItem(i),
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(b.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${b.jumlah} × ${b.panjang} × ${b.lebar} × ${b.tinggi} cm • ${b.berat} kg'),
                      trailing: IconButton(tooltip: 'Hapus Barang', onPressed: _busy ? null : () => _removeItem(i), icon: const Icon(Icons.delete_outline)),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              FilledButton(onPressed: _busy ? null : _save, child: Text(widget.existing == null ? 'Simpan Pengiriman' : 'Simpan Perubahan')),
            ],
          ),
        ),
      ),
    );
  }
}
