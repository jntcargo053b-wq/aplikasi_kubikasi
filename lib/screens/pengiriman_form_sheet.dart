import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../services/indonesia_region_service.dart';
import '../services/photo_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/barang_form_sheet.dart';
import 'barcode_scanner_screen.dart';

Future<Pengiriman?> showPengirimanFormSheet(
  BuildContext context, {
  Pengiriman? existing,
  List<BarangItem>? initialBarang,
  Pengiriman? duplicateFrom,
}) =>
    showModalBottomSheet<Pengiriman>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PengirimanForm(existing: existing, initialBarang: initialBarang, duplicateFrom: duplicateFrom),
    );

class _PengirimanForm extends StatefulWidget {
  final Pengiriman? existing;
  final List<BarangItem>? initialBarang;
  final Pengiriman? duplicateFrom;
  const _PengirimanForm({this.existing, this.initialBarang, this.duplicateFrom});

  @override
  State<_PengirimanForm> createState() => _PengirimanFormState();
}

class _PengirimanFormState extends State<_PengirimanForm> {
  late final TextEditingController _pengirim;
  late final TextEditingController _noTelepon;
  late final TextEditingController _resi;
  late DateTime _tanggal;
  late List<BarangItem> _barang;
  late final Set<String> _originalPhotoPaths;
  final Set<String> _sessionPhotoPaths = {};
  List<String> _savedSenders = const [];
  Map<String, String> _senderPhones = const {};
  List<Pengiriman> _savedShipments = const [];
  List<BarangItem> _savedBarangTemplates = const [];

  List<IndonesiaRegion> _kotaKabupaten = const [];
  List<IndonesiaRegion> _kecamatan = const [];
  IndonesiaRegion? _selectedKotaKabupaten;
  IndonesiaRegion? _selectedKecamatan;
  bool _loadingWilayah = true;
  bool _loadingKecamatan = false;
  bool _saved = false;
  bool _busy = false;
  String? _wilayahError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? widget.duplicateFrom;
    _pengirim = TextEditingController(text: e?.pengirim ?? '');
    _noTelepon = TextEditingController(text: e?.noTelepon ?? '');
    _resi = TextEditingController(text: widget.duplicateFrom != null ? '' : (e?.nomorResi ?? ''));
    _tanggal = widget.duplicateFrom != null ? DateTime.now() : (e?.tanggal ?? DateTime.now());
    _barang = e?.barang.map((x) => x.copyWith(clearPhoto: widget.duplicateFrom != null)).toList() ??
        widget.initialBarang?.map((x) => x.copyWith()).toList() ??
        [];
    _originalPhotoPaths = _barang
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet();
    _loadWilayah();
    _loadSavedSenders();
  }

  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> _loadSavedSenders() async {
    try {
      final items = await StorageService().loadPengiriman();
      final names = <String>{};
      final phones = <String, String>{};
      final templates = <String, BarangItem>{};
      for (final item in items) {
        final name = item.pengirim.trim();
        if (name.isNotEmpty) {
          names.add(name);
          final phone = item.noTelepon.trim();
          if (phone.isNotEmpty) phones[name.toLowerCase()] = phone;
        }
        for (final itemBarang in item.barang) {
          final key = '${itemBarang.nama.trim().toLowerCase()}|${itemBarang.panjang}|${itemBarang.lebar}|${itemBarang.tinggi}|${itemBarang.berat}';
          if (itemBarang.nama.trim().isNotEmpty) templates.putIfAbsent(key, () => itemBarang.copyWith(clearPhoto: true));
        }
      }
      if (!mounted) return;
      setState(() {
        _savedShipments = items;
        _senderPhones = phones;
        _savedSenders = names.toList()..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _savedBarangTemplates = templates.values.toList()..sort((a,b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      });
    } catch (_) {}
  }

  void _applySender(String value) {
    final phone = _senderPhones[value.trim().toLowerCase()];
    if (phone != null && _noTelepon.text.trim().isEmpty) _noTelepon.text = phone;
  }

  Future<void> _useLastShipment() async {
    if (_busy || widget.existing != null || _savedShipments.isEmpty) return;
    final last = _savedShipments.reduce((a,b) => a.tanggal.isAfter(b.tanggal) ? a : b);
    if (!mounted) return;
    setState(() { _pengirim.text = last.pengirim; _noTelepon.text = last.noTelepon; });
    final city = last.kotaKabupaten.trim().toLowerCase();
    final kec = last.kecamatan.trim().toLowerCase();
    IndonesiaRegion? selectedCity;
    for (final item in _kotaKabupaten) { if (item.name.trim().toLowerCase() == city) { selectedCity = item; break; } }
    if (selectedCity != null) {
      await _loadKecamatan(selectedCity);
      if (!mounted) return;
      IndonesiaRegion? selectedKec;
      for (final item in _kecamatan) { if (item.name.trim().toLowerCase() == kec) { selectedKec = item; break; } }
      setState(() => _selectedKecamatan = selectedKec);
    }
  }

  Future<void> _quickAddBarang() async {
    if (_busy || _savedBarangTemplates.isEmpty) return;
    final picked = await showModalBottomSheet<BarangItem>(
      context: context, showDragHandle: true, useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12,0,12,20),
          itemCount: _savedBarangTemplates.length,
          separatorBuilder: (_,__) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final item = _savedBarangTemplates[index];
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(item.nama),
              subtitle: Text('${item.panjang} × ${item.lebar} × ${item.tinggi} cm • ${item.berat} kg/unit'),
              onTap: () => Navigator.pop(sheetContext, item),
            );
          },
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _barang.add(BarangItem(id: const Uuid().v4(), nama: picked.nama, jumlah: picked.jumlah, panjang: picked.panjang, lebar: picked.lebar, tinggi: picked.tinggi, berat: picked.berat)));
    }
  }
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingWilayah = false;
        _wilayahError =
            'Daftar wilayah offline gagal dimuat. Coba tutup dan buka kembali form.';
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
        const SnackBar(
          content: Text(
            'Daftar kecamatan offline gagal dimuat. Silakan coba pilih kota/kabupaten lagi.',
          ),
        ),
      );
    }
  }

  Future<IndonesiaRegion?> _pickRegion({
    required String title,
    required String hint,
    required List<IndonesiaRegion> regions,
    IndonesiaRegion? selected,
  }) async {
    if (regions.isEmpty) return null;
    final controller = TextEditingController();
    try {
      return await showModalBottomSheet<IndonesiaRegion>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setModalState) {
            final q = controller.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? regions
                : regions
                    .where(
                      (r) =>
                          r.name.toLowerCase().contains(q) ||
                          r.type.toLowerCase().contains(q),
                    )
                    .toList();

            return Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * .72,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            labelText: title,
                            hintText: hint,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: controller.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      setModalState(() {});
                                    },
                                  ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('Tidak ada wilayah yang cocok.'),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  20,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final item = filtered[i];
                                  final isSelected =
                                      item.code == selected?.code;
                                  return ListTile(
                                    leading: Icon(
                                      item.type == 'Kota'
                                          ? Icons.location_city_outlined
                                          : Icons.place_outlined,
                                    ),
                                    title: Text(item.name),
                                    subtitle: Text(item.type),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle)
                                        : null,
                                    onTap: () =>
                                        Navigator.pop(sheetContext, item),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _selectKotaKabupaten() async {
    if (_busy || _loadingWilayah) return;
    final value = await _pickRegion(
      title: 'Cari Kabupaten/Kota',
      hint: 'Ketik nama kabupaten atau kota...',
      regions: _kotaKabupaten,
      selected: _selectedKotaKabupaten,
    );
    if (value == null || !mounted) return;
    setState(() => _selectedKotaKabupaten = value);
    await _loadKecamatan(value);
  }

  Future<void> _selectKecamatan() async {
    if (_busy || _loadingKecamatan || _selectedKotaKabupaten == null) return;
    final value = await _pickRegion(
      title: 'Cari Kecamatan',
      hint: 'Ketik nama kecamatan...',
      regions: _kecamatan,
      selected: _selectedKecamatan,
    );
    if (value != null && mounted) {
      setState(() => _selectedKecamatan = value);
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
        if (item.photoPath != null &&
            !_originalPhotoPaths.contains(item.photoPath)) {
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
        if (newPhoto != null &&
            newPhoto.isNotEmpty &&
            !_originalPhotoPaths.contains(newPhoto) &&
            newPhoto != beforePhoto) {
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
        const SnackBar(
          content: Text(
            'Lengkapi pengirim, kota/kabupaten, kecamatan, resi, dan minimal satu barang.',
          ),
        ),
      );
      return;
    }

    final result = Pengiriman(
      id: widget.existing?.id ?? const Uuid().v4(),
      pengirim: _pengirim.text.trim(),
      noTelepon: _noTelepon.text.trim(),
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
    final currentPhotoPaths = _barang
        .map((b) => b.photoPath)
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    final cleanupPaths = _saved
        ? _sessionPhotoPaths.difference(currentPhotoPaths)
        : _sessionPhotoPaths;
    if (cleanupPaths.isNotEmpty) {
      final paths = List<String>.from(cleanupPaths);
      Future.microtask(() => PhotoStorageService.deleteAll(paths));
    }
    _pengirim.dispose();
    _noTelepon.dispose();
    _resi.dispose();
    super.dispose();
  }

  Widget _regionField({
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
    IndonesiaRegion? value,
  }) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            value?.name ?? hint,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == null ? Colors.grey.shade600 : null,
            ),
          ),
        ),
      );

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
              Center(
                child: Container(width: 42, height: 4, color: AppColors.border),
              ),
              const SizedBox(height: 16),
              Text(
                widget.duplicateFrom != null
                    ? 'Duplikat Pengiriman'
                    : widget.existing == null
                        ? 'Tambah Pengiriman'
                        : 'Edit Pengiriman',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.existing == null && widget.duplicateFrom == null && _savedShipments.isNotEmpty) ...[
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _busy ? null : _useLastShipment, icon: const Icon(Icons.history, size: 18), label: const Text('Gunakan data pengiriman terakhir'))),
              ],
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _pengirim.text),
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  final matches = _savedSenders
                      .where(
                        (name) =>
                            query.isEmpty ||
                            name.toLowerCase().contains(query),
                      )
                      .toList();

                  // Tetap izinkan nama baru diketik meskipun belum ada di
                  // daftar pengirim yang tersimpan.
                  if (value.text.trim().isNotEmpty &&
                      !matches.any(
                        (name) =>
                            name.toLowerCase() ==
                            value.text.trim().toLowerCase(),
                      )) {
                    return [value.text.trim(), ...matches];
                  }
                  return matches;
                },
                onSelected: (value) {
                  _pengirim.text = value;
                  _applySender(value);
                  _pengirim.selection = TextSelection.collapsed(
                    offset: _pengirim.text.length,
                  );
                },
                displayStringForOption: (value) => value,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  if (controller.text != _pengirim.text) {
                    controller.value = TextEditingValue(text: _pengirim.text, selection: TextSelection.collapsed(offset: _pengirim.text.length));
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.next,
                    onChanged: (value) { _pengirim.text = value; _applySender(value); },
                    onSubmitted: (_) => onFieldSubmitted(),
                    decoration: InputDecoration(
                      labelText: 'Nama Pengirim',
                      hintText: _savedSenders.isEmpty
                          ? 'Ketik nama pengirim'
                          : 'Ketik atau pilih pengirim',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: _savedSenders.isEmpty
                          ? null
                          : const Icon(Icons.arrow_drop_down),
                    ),
                    scrollPadding: const EdgeInsets.only(bottom: 180),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final name = options.elementAt(index);
                            final isNew = !_savedSenders.any(
                              (saved) =>
                                  saved.toLowerCase() == name.toLowerCase(),
                            );
                            return ListTile(
                              leading: Icon(
                                isNew
                                    ? Icons.add_circle_outline
                                    : Icons.person_outline,
                              ),
                              title: Text(
                                isNew ? 'Gunakan "$name"' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: isNew
                                  ? const Text('Pengirim baru')
                                  : null,
                              onTap: () => onSelected(name),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noTelepon,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                scrollPadding: const EdgeInsets.only(bottom: 180),
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
                  if (picked != null && mounted) {
                    setState(() => _tanggal = picked);
                  }
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
                  decoration: InputDecoration(labelText: 'Kota/Kab. Tujuan'),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Memuat daftar wilayah offline...'),
                    ],
                  ),
                )
              else
                _regionField(
                  label: 'Kota/Kab. Tujuan',
                  hint: 'Pilih kota/kabupaten tujuan',
                  icon: Icons.location_city_outlined,
                  enabled: !_busy,
                  onTap: _selectKotaKabupaten,
                  value: _selectedKotaKabupaten,
                ),
              if (_wilayahError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _wilayahError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _loadWilayah,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Muat ulang wilayah'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _regionField(
                label: 'Kecamatan Tujuan',
                hint: _selectedKotaKabupaten == null
                    ? 'Pilih kota/kabupaten tujuan terlebih dahulu'
                    : 'Pilih kecamatan tujuan',
                icon: Icons.place_outlined,
                enabled: _selectedKotaKabupaten != null &&
                    !_loadingKecamatan &&
                    !_busy,
                onTap: _selectKecamatan,
                value: _selectedKecamatan,
              ),
              if (_loadingKecamatan) ...[
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
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
                scrollPadding: const EdgeInsets.only(bottom: 180),
              ),
              const SizedBox(height: 18),
              if (widget.existing == null && widget.initialBarang != null && widget.initialBarang!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, size: 20, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data barang dari kalkulator sudah diisi otomatis. Ketuk barang untuk mengubah nama, ukuran, berat, atau foto.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daftar Barang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_savedBarangTemplates.isNotEmpty) OutlinedButton.icon(onPressed: _busy ? null : _quickAddBarang, icon: const Icon(Icons.history), label: const Text('Barang Lama')),
                    if (_savedBarangTemplates.isNotEmpty) const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: _busy ? null : _addItem, icon: const Icon(Icons.add), label: const Text('Tambah Barang')),
                  ]),
                ],
              ),
              const SizedBox(height: 8),
              if (_barang.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Belum ada barang.')),
                )
              else
                ..._barang.asMap().entries.map((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      onTap: _busy ? null : () => _editItem(i),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: b.photoPath == null
                          ? const CircleAvatar(
                              child: Icon(Icons.inventory_2_outlined),
                            )
                          : GestureDetector(
                              onTap: () => showPhotoPreview(context, b.photoPath!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(b.photoPath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  cacheWidth: 144,
                                  cacheHeight: 144,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 16, color: AppColors.muted),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${b.jumlah} pcs • ${b.panjang} × ${b.lebar} × ${b.tinggi} cm • ${b.berat} kg/unit\n${b.kubikasi.toStringAsFixed(3)} m³ • ${b.totalBerat.toStringAsFixed(2)} kg',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Hapus Barang',
                        onPressed: _busy ? null : () => _removeItem(i),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  widget.existing == null
                      ? 'Simpan Pengiriman'
                      : 'Simpan Perubahan',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
