import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/pengiriman.dart';
import '../models/report_settings.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/photo_storage_service.dart';
import 'pengiriman_form_sheet.dart';
import 'report_header_settings_screen.dart';
import '../widgets/barang_form_sheet.dart';

enum _SortMode { terbaru, terlama, pengirim }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _exportService = ExportService();
  final _settingsService = SettingsService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchText = '';
  bool _exporting = false;
  String? _exportingLabel;
  List<Pengiriman> _items = [];
  ReportSettings _reportSettings = const ReportSettings();
  bool _loading = true;
  _SortMode _sort = _SortMode.terbaru;
  String _pengirim = 'Semua';
  DateTime? _mulai;
  DateTime? _sampai;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _storage.loadPengiriman();
    final reportSettings = await _settingsService.loadReportSettings();
    if (!mounted) return;
    setState(() {
      _items = data;
      _reportSettings = reportSettings;
      _loading = false;
    });
  }

  Future<void> _openReportHeaderSettings() async {
    final result = await Navigator.of(context).push<ReportSettings>(
      MaterialPageRoute(builder: (_) => const ReportHeaderSettingsScreen()),
    );
    if (result != null && mounted) {
      setState(() => _reportSettings = result);
    }
  }

  String get _search => _searchText;
  bool _matchesSearch(Pengiriman e) =>
      _search.isEmpty ||
      e.nomorResi.toLowerCase().contains(_search) ||
      e.pengirim.toLowerCase().contains(_search) ||
      e.barang.any((b) => b.nama.toLowerCase().contains(_search));

  void _ensureFilterValid() {
    if (!_pengirimList.contains(_pengirim)) _pengirim = 'Semua';
  }

  List<Pengiriman> get _displayed {
    _ensureFilterValid();
    var list = _items.where((e) {
      if (!_matchesSearch(e)) return false;
      if (_pengirim != 'Semua' && e.pengirim != _pengirim) return false;
      if (_mulai != null &&
          e.tanggal.isBefore(DateTime(_mulai!.year, _mulai!.month, _mulai!.day))) {
        return false;
      }
      if (_sampai != null) {
        final end = DateTime(_sampai!.year, _sampai!.month, _sampai!.day, 23, 59, 59, 999);
        if (e.tanggal.isAfter(end)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _SortMode.terbaru:
        list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
        break;
      case _SortMode.terlama:
        list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
        break;
      case _SortMode.pengirim:
        list.sort((a, b) => a.pengirim.toLowerCase().compareTo(b.pengirim.toLowerCase()));
        break;
    }
    return list;
  }

  List<String> get _pengirimList {
    final names = _items.map((e) => e.pengirim.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();
    return ['Semua', ...names];
  }

  Future<void> _newShipment() async {
    final result = await showPengirimanFormSheet(context);
    if (result == null || !mounted) return;
    final previous = List<Pengiriman>.of(_items);
    final next = [...previous, result];
    final saved = await _persistItems(next);
    if (saved && mounted) {
      setState(() => _items = next);
      await _cleanupAfterSuccessfulSave(previous, next);
    } else {
      await _cleanupNewPhotosOnFailedSave(previous, result);
    }
  }

  Future<void> _edit(Pengiriman item) async {
    final result = await showPengirimanFormSheet(context, existing: item);
    if (result == null || !mounted) return;
    final i = _items.indexWhere((e) => e.id == item.id);
    if (i == -1) return;
    final previous = List<Pengiriman>.of(_items);
    final next = List<Pengiriman>.of(_items);
    next[i] = result;
    final saved = await _persistItems(next);
    if (saved && mounted) {
      setState(() => _items = next);
      await _cleanupAfterSuccessfulSave(previous, next);
    } else {
      await _cleanupNewPhotosOnFailedSave(previous, result);
    }
  }

  Future<bool> _persistItems(List<Pengiriman> next) async {
    try {
      await _storage.savePengiriman(next);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan data pengiriman. Perubahan tidak diterapkan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Set<String> _photoPaths(Iterable<Pengiriman> items) => items
      .expand((e) => e.barang)
      .map((b) => b.photoPath)
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .toSet();

  Future<void> _cleanupAfterSuccessfulSave(
    List<Pengiriman> previous,
    List<Pengiriman> next,
  ) async {
    final before = _photoPaths(previous);
    final after = _photoPaths(next);
    // Only files that belonged to the previous persisted state and are no
    // longer referenced may be deleted. Newly-created files remain intact.
    await PhotoStorageService.deleteAll(before.difference(after));
  }

  Future<void> _cleanupNewPhotosOnFailedSave(
    List<Pengiriman> previous,
    Pengiriman result,
  ) async {
    final oldPaths = _photoPaths(previous);
    final newPaths = result.barang
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet();
    // Persistence failed, so remove only files introduced by this edit/new
    // shipment. Existing persisted photos must remain untouched.
    await PhotoStorageService.deleteAll(newPaths.difference(oldPaths));
  }

  Future<void> _delete(Pengiriman item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengiriman?'),
        content: Text('Hapus resi ${item.nomorResi} beserta semua barangnya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Remove the persisted shipment first, then clean up every photo owned by it.
    // The photo cleanup is deliberately best-effort so a single stale file can
    // never block deletion of the shipment itself.
    final next = List<Pengiriman>.of(_items)..removeWhere((e) => e.id == item.id);
    if (!await _persistItems(next)) return;
    if (!mounted) return;
    setState(() => _items = next);

    // Do not delete a path that is still referenced elsewhere, even if old
    // data happens to contain the same path more than once.
    final remainingPhotoPaths = next
        .expand((e) => e.barang)
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .toSet();
    final deletedShipmentPhotos = item.barang
        .map((b) => b.photoPath)
        .whereType<String>()
        .where((p) => p.isNotEmpty && !remainingPhotoPaths.contains(p));
    await PhotoStorageService.deleteAll(deletedShipmentPhotos);
  }

  Future<void> _shareReport(Pengiriman item, {required bool pdf}) async {
    await _runExport(
      label: 'Menyiapkan ${pdf ? 'PDF' : 'Excel'}...',
      action: () => pdf
          ? _exportService.sharePdf(item, settings: _reportSettings)
          : _exportService.shareExcel(item, settings: _reportSettings),
    );
  }

  Future<void> _shareFilteredReport(List<Pengiriman> items, {required bool pdf}) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk dibagikan.')));
      return;
    }
    await _runExport(
      label: 'Menyiapkan rekap ${pdf ? 'PDF' : 'Excel'}...',
      action: () => pdf
          ? _exportService.shareCombinedPdf(items, settings: _reportSettings)
          : _exportService.shareCombinedExcel(items, settings: _reportSettings),
    );
  }

  Future<void> _runExport({required String label, required Future<void> Function() action}) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportingLabel = label;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
    } finally {
      if (mounted) setState(() { _exporting = false; _exportingLabel = null; });
    }
  }

  Future<void> _pickRange(bool start) async {
    final initial = start ? (_mulai ?? DateTime.now()) : (_sampai ?? _mulai ?? DateTime.now());
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null) return;
    setState(() {
      if (start) {
        _mulai = d;
        if (_sampai != null && _sampai!.isBefore(d)) _sampai = d;
      } else {
        _sampai = d;
        if (_mulai != null && _mulai!.isAfter(d)) _mulai = d;
      }
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() {
        _searchController.clear();
        _searchText = '';
        _pengirim = 'Semua';
        _mulai = null;
        _sampai = null;
      });
  }

  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final list = _displayed;
    final totalK = list.fold<double>(0, (s, e) => s + e.totalKubikasi);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalkulator Kubikasi', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Header Laporan',
            onPressed: _openReportHeaderSettings,
            icon: const Icon(Icons.edit_document),
          ),
          PopupMenuButton<_SortMode>(
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _SortMode.terbaru, child: Text('Tanggal Terbaru')),
              PopupMenuItem(value: _SortMode.terlama, child: Text('Tanggal Terlama')),
              PopupMenuItem(value: _SortMode.pengirim, child: Text('Pengirim A-Z')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newShipment,
        icon: const Icon(Icons.add),
        label: const Text('Pengiriman Baru'),
      ),
      body: Stack(
        children: [
          _body(list, totalK),
          if (_exporting)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        SizedBox(width: 14),
                        Text(_exportingLabel ?? 'Menyiapkan laporan...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(List<Pengiriman> list, double totalK) {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchDebounce?.cancel();
                final normalized = value.trim().toLowerCase();
                _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                  if (!mounted) return;
                  setState(() => _searchText = normalized);
                });
              },
              decoration: InputDecoration(
                hintText: 'Cari resi, pengirim, atau nama barang',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty ? null : IconButton(
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
          ),
          _filters(),
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bagikan ${list.length} pengiriman hasil filter',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Bagikan hasil filter',
                        onSelected: (v) {
                          if (v == 'pdf') _shareFilteredReport(list, pdf: true);
                          if (v == 'excel') _shareFilteredReport(list, pdf: false);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'pdf', child: Text('Share Rekap PDF')),
                          PopupMenuItem(value: 'excel', child: Text('Share Rekap Excel')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(child: _summary('Pengiriman', '${list.length}')),
                Expanded(child: _summary('Kubikasi', totalK.toStringAsFixed(3))),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Belum ada pengiriman tersimpan.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _card(list[i]),
                  ),
          ),
        ],
      );
  }

  Widget _summary(String a, String b) => Column(
        children: [
          Text(a, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(b, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _pengirim,
              items: _pengirimList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _pengirim = v ?? 'Semua'),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(_mulai == null ? 'Dari tanggal' : 'Dari ${_date(_mulai!)}'),
            onSelected: (_) => _pickRange(true),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(_sampai == null ? 'Sampai tanggal' : 'Sampai ${_date(_sampai!)}'),
            onSelected: (_) => _pickRange(false),
          ),
          if (_pengirim != 'Semua' || _mulai != null || _sampai != null || _search.isNotEmpty) ...[
            const SizedBox(width: 8),
            ActionChip(label: const Text('Reset'), onPressed: _clearFilters),
          ],
        ],
      ),
    );
  }

  Widget _card(Pengiriman p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(p.nomorResi, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${p.pengirim} • ${_date(p.tanggal)} • ${p.barang.length} jenis barang', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.expand_more),
            PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _edit(p);
            if (v == 'delete') _delete(p);
            if (v == 'share_pdf') _shareReport(p, pdf: true);
            if (v == 'share_excel') _shareReport(p, pdf: false);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'share_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('Share Laporan (PDF)'),
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 0,
              ),
            ),
            PopupMenuItem(
              value: 'share_excel',
              child: ListTile(
                leading: Icon(Icons.grid_on_outlined),
                title: Text('Share Laporan (Excel)'),
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 0,
              ),
            ),
            PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
            ),
          ],
        ),
        children: [
          ...p.barang.map((b) => ListTile(
                dense: true,
                leading: b.photoPath == null
                    ? const Icon(Icons.inventory_2_outlined)
                    : GestureDetector(
                        onTap: () => showPhotoPreview(context, b.photoPath!),
                        child: Image.file(
                          File(b.photoPath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 144,
                          cacheHeight: 144,
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                title: Text(b.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${b.jumlah} × ${b.panjang}×${b.lebar}×${b.tinggi} cm', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('${b.kubikasi.toStringAsFixed(3)} m³'),
              )),
          ListTile(
            title: const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Volume ${p.totalVolume.toStringAsFixed(2)} • Berat ${p.totalBerat.toStringAsFixed(2)} kg'),
            trailing: Text('${p.totalKubikasi.toStringAsFixed(3)} m³', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
