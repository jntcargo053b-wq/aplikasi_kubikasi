import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/pengiriman.dart';
import '../models/barang_item.dart';
import '../models/report_settings.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/photo_storage_service.dart';
import '../widgets/barang_form_sheet.dart';
import 'pengiriman_form_sheet.dart';
import 'report_header_settings_screen.dart';
import 'backup_restore_screen.dart';
import 'calculator_screen.dart';
import 'shipment_detail_screen.dart';

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
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<dynamic>([
      _storage.loadPengiriman(),
      _settingsService.loadReportSettings(),
    ]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<Pengiriman>;
      _reportSettings = results[1] as ReportSettings;
      _loading = false;
    });
  }

  String get _search => _searchText;
  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  bool _matchesSearch(Pengiriman e) => _search.isEmpty ||
      e.nomorResi.toLowerCase().contains(_search) ||
      e.pengirim.toLowerCase().contains(_search) ||
      e.kotaKabupaten.toLowerCase().contains(_search) ||
      e.kecamatan.toLowerCase().contains(_search) ||
      e.barang.any((b) => b.nama.toLowerCase().contains(_search));

  List<String> get _pengirimList {
    final names = _items.map((e) => e.pengirim.trim()).where((e) => e.isNotEmpty).toSet().toList()..sort();
    return ['Semua', ...names];
  }

  List<Pengiriman> get _displayed {
    if (!_pengirimList.contains(_pengirim)) _pengirim = 'Semua';
    final list = _items.where((e) {
      if (!_matchesSearch(e)) return false;
      if (_pengirim != 'Semua' && e.pengirim != _pengirim) return false;
      if (_mulai != null && e.tanggal.isBefore(DateTime(_mulai!.year, _mulai!.month, _mulai!.day))) return false;
      if (_sampai != null) {
        final end = DateTime(_sampai!.year, _sampai!.month, _sampai!.day, 23, 59, 59, 999);
        if (e.tanggal.isAfter(end)) return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case _SortMode.terbaru:
        list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      case _SortMode.terlama:
        list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
      case _SortMode.pengirim:
        list.sort((a, b) => a.pengirim.toLowerCase().compareTo(b.pengirim.toLowerCase()));
    }
    return list;
  }

  Future<void> _newShipment() async {
    final result = await showPengirimanFormSheet(context);
    if (result == null || !mounted) return;
    final previous = List<Pengiriman>.of(_items);
    final next = [...previous, result];
    if (await _persistItems(next)) {
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
    final next = List<Pengiriman>.of(_items)..[i] = result;
    if (await _persistItems(next)) {
      setState(() => _items = next);
      await _cleanupAfterSuccessfulSave(previous, next);
    } else {
      await _cleanupNewPhotosOnFailedSave(previous, result);
    }
  }

  Future<void> _editBarang(Pengiriman shipment, int index) async {
    if (index < 0 || index >= shipment.barang.length) return;
    final result = await showBarangFormSheet(context, existing: shipment.barang[index]);
    if (result == null || !mounted) return;
    final i = _items.indexWhere((e) => e.id == shipment.id);
    if (i == -1) return;
    final previous = List<Pengiriman>.of(_items);
    final updated = List<BarangItem>.of(shipment.barang)..[index] = result;
    final updatedShipment = Pengiriman(
      id: shipment.id,
      pengirim: shipment.pengirim,
      noTelepon: shipment.noTelepon,
      tanggal: shipment.tanggal,
      nomorResi: shipment.nomorResi,
      kotaKabupaten: shipment.kotaKabupaten,
      kecamatan: shipment.kecamatan,
      barang: updated,
    );
    final next = List<Pengiriman>.of(_items)..[i] = updatedShipment;
    if (await _persistItems(next)) {
      setState(() => _items = next);
      await _cleanupAfterSuccessfulSave(previous, next);
    } else {
      final oldPaths = _photoPaths(previous);
      final newPath = result.photoPath;
      if (newPath != null && newPath.isNotEmpty && !oldPaths.contains(newPath)) await PhotoStorageService.delete(newPath);
    }
  }

  Set<String> _photoPaths(Iterable<Pengiriman> items) => items.expand((e) => e.barang).map((b) => b.photoPath).whereType<String>().where((p) => p.isNotEmpty).toSet();

  Future<void> _cleanupAfterSuccessfulSave(List<Pengiriman> previous, List<Pengiriman> next) async {
    await PhotoStorageService.deleteAll(_photoPaths(previous).difference(_photoPaths(next)));
  }

  Future<void> _cleanupNewPhotosOnFailedSave(List<Pengiriman> previous, Pengiriman result) async {
    await PhotoStorageService.deleteAll(_photoPaths([result]).difference(_photoPaths(previous)));
  }

  Future<bool> _persistItems(List<Pengiriman> next) async {
    try {
      await _storage.savePengiriman(next);
      return true;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan data pengiriman. Perubahan tidak diterapkan.')));
      return false;
    }
  }

  Future<void> _delete(Pengiriman item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengiriman?'),
        content: Text('Hapus resi ${item.nomorResi} beserta semua barangnya?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final next = List<Pengiriman>.of(_items)..removeWhere((e) => e.id == item.id);
    if (!await _persistItems(next) || !mounted) return;
    setState(() => _items = next);
    final remaining = _photoPaths(next);
    await PhotoStorageService.deleteAll(_photoPaths([item]).difference(remaining));
  }

  Future<void> _openReportHeaderSettings() async {
    final result = await Navigator.of(context).push<ReportSettings>(MaterialPageRoute(builder: (_) => const ReportHeaderSettingsScreen()));
    if (result != null && mounted) setState(() => _reportSettings = result);
  }

  Future<void> _shareReport(Pengiriman item, {required bool pdf}) async {
    await _runExport(
      label: 'Menyiapkan ${pdf ? 'PDF' : 'Excel'}...',
      action: () => pdf ? _exportService.sharePdf(item, settings: _reportSettings) : _exportService.shareExcel(item, settings: _reportSettings),
    );
  }

  Future<void> _shareFilteredReport(List<Pengiriman> items, {required bool pdf}) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk dibagikan.')));
      return;
    }
    await _runExport(
      label: 'Menyiapkan rekap ${pdf ? 'PDF' : 'Excel'}...',
      action: () => pdf ? _exportService.shareCombinedPdf(items, settings: _reportSettings) : _exportService.shareCombinedExcel(items, settings: _reportSettings),
    );
  }

  Future<void> _runExport({required String label, required Future<void> Function() action}) async {
    if (_exporting) return;
    setState(() { _exporting = true; _exportingLabel = label; });
    try {
      await action();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
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
    setState(() { _searchController.clear(); _searchText = ''; _pengirim = 'Semua'; _mulai = null; _sampai = null; });
  }

  void _openShipment(Pengiriman item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentDetailScreen(
      shipment: item,
      onEdit: () async { Navigator.pop(context); await _edit(item); },
      onSharePdf: () => _shareReport(item, pdf: true),
      onShareExcel: () => _shareReport(item, pdf: false),
      onEditItem: (index) async { Navigator.pop(context); await _editBarang(item, index); },
    )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final list = _displayed;
    final totalK = list.fold<double>(0, (s, e) => s + e.totalKubikasi);
    return Scaffold(
      appBar: AppBar(
        title: _brand(),
        actions: [
          IconButton(tooltip: 'Backup & Restore', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())), icon: const Icon(Icons.shield_outlined)),
          IconButton(tooltip: 'Pengaturan laporan', onPressed: _openReportHeaderSettings, icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: Stack(children: [_body(list, totalK), if (_exporting) _exportOverlay()]),
      floatingActionButton: FloatingActionButton(onPressed: _newShipment, child: const Icon(Icons.add_rounded)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
          if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen()));
          if (index == 2) _shareFilteredReport(list, pdf: true);
          if (index == 3) _showSettingsMenu();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.view_in_ar_outlined), selectedIcon: Icon(Icons.view_in_ar_rounded), label: 'Kalkulator'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Pengaturan'),
        ],
      ),
    );
  }

  Widget _brand() => RichText(text: const TextSpan(style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -1), children: [TextSpan(text: 'next', style: TextStyle(color: AppColors.text)), TextSpan(text: 'cube', style: TextStyle(color: AppColors.primary))]));

  Widget _body(List<Pengiriman> list, double totalK) {
    final today = DateTime.now();
    final todayCount = _items.where((e) => e.tanggal.year == today.year && e.tanggal.month == today.month && e.tanggal.day == today.day).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
        children: [
          const Text('Selamat Datang', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
          const SizedBox(height: 4),
          const Text('Kelola pengiriman Anda dengan lebih mudah.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _quickAction(Icons.view_in_ar_outlined, 'Hitung\nKubikasi', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen())))),
            const SizedBox(width: 10),
            Expanded(child: _quickAction(Icons.add_box_outlined, 'Tambah\nPengiriman', _newShipment)),
            const SizedBox(width: 10),
            Expanded(child: _quickAction(Icons.backup_outlined, 'Backup &\nRestore', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())))),
          ]),
          const SizedBox(height: 20),
          _sectionTitle('Rekap Hari Ini', '$_items.length data'),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _statCard(Icons.local_shipping_outlined, '${_items.length}', 'Total Pengiriman')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(Icons.calendar_today_outlined, '$todayCount', 'Hari Ini')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _statCard(Icons.view_in_ar_outlined, '${_items.fold<double>(0, (s, e) => s + e.totalKubikasi).toStringAsFixed(3)} m³', 'Total Kubikasi')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(Icons.inventory_2_outlined, '${_items.fold<int>(0, (s, e) => s + e.totalJumlah)}', 'Total Barang')),
          ]),
          const SizedBox(height: 22),
          _sectionTitle('Pengiriman Terbaru', list.isEmpty ? '' : '${list.length} hasil'),
          const SizedBox(height: 9),
          _searchBox(),
          _filters(),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(child: ListTile(
              leading: const Icon(Icons.share_outlined, color: AppColors.primary),
              title: Text('Bagikan ${list.length} hasil filter', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('PDF atau Excel', style: TextStyle(fontSize: 12)),
              trailing: PopupMenuButton<String>(onSelected: (v) => _shareFilteredReport(list, pdf: v == 'pdf'), itemBuilder: (_) => const [PopupMenuItem(value: 'pdf', child: Text('Bagikan PDF')), PopupMenuItem(value: 'excel', child: Text('Bagikan Excel'))]),
            )),
            const SizedBox(height: 8),
          ],
          if (list.isEmpty) _emptyState() else ...list.map(_shipmentCard),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6), child: Column(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.primary)), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]))));

  Widget _statCard(IconData icon, String value, String label) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.primary, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11))]))])));

  Widget _sectionTitle(String title, String trailing) => Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), if (trailing.isNotEmpty) Text(trailing, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700))]);

  Widget _searchBox() => Padding(padding: const EdgeInsets.only(top: 2), child: TextField(controller: _searchController, onChanged: (value) { _searchDebounce?.cancel(); final normalized = value.trim().toLowerCase(); _searchDebounce = Timer(const Duration(milliseconds: 250), () { if (mounted) setState(() => _searchText = normalized); }); }, decoration: InputDecoration(hintText: 'Cari resi, pengirim, barang, atau wilayah', prefixIcon: const Icon(Icons.search), suffixIcon: _search.isEmpty ? null : IconButton(onPressed: _clearFilters, icon: const Icon(Icons.clear)))));

  Widget _filters() => SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [DropdownButtonHideUnderline(child: DropdownButton<String>(value: _pengirim, items: _pengirimList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _pengirim = v ?? 'Semua'))), const SizedBox(width: 8), FilterChip(label: Text(_mulai == null ? 'Dari tanggal' : 'Dari ${_date(_mulai!)}'), onSelected: (_) => _pickRange(true)), const SizedBox(width: 8), FilterChip(label: Text(_sampai == null ? 'Sampai tanggal' : 'Sampai ${_date(_sampai!)}'), onSelected: (_) => _pickRange(false)), const SizedBox(width: 8), PopupMenuButton<_SortMode>(tooltip: 'Urutkan', onSelected: (v) => setState(() => _sort = v), itemBuilder: (_) => const [PopupMenuItem(value: _SortMode.terbaru, child: Text('Terbaru')), PopupMenuItem(value: _SortMode.terlama, child: Text('Terlama')), PopupMenuItem(value: _SortMode.pengirim, child: Text('Pengirim A-Z'))], child: const Chip(avatar: Icon(Icons.sort, size: 18), label: Text('Urutkan'))), if (_pengirim != 'Semua' || _mulai != null || _sampai != null || _search.isNotEmpty) ...[const SizedBox(width: 8), ActionChip(label: const Text('Reset'), onPressed: _clearFilters)]]));

  Widget _shipmentCard(Pengiriman p) => Card(margin: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => _openShipment(p), borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.nomorResi, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${p.pengirim} • ${_date(p.tanggal)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)), const SizedBox(height: 5), Text('${p.barang.length} jenis barang • ${p.totalKubikasi.toStringAsFixed(3)} m³', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))])), const Icon(Icons.chevron_right, color: AppColors.muted)]))));

  Widget _emptyState() => Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(children: [Container(width: 62, height: 62, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 30)), const SizedBox(height: 14), const Text('Belum ada pengiriman', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 5), const Text('Tambahkan pengiriman pertama untuk mulai mencatat kubikasi.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)), const SizedBox(height: 16), FilledButton.icon(onPressed: _newShipment, icon: const Icon(Icons.add), label: const Text('Tambah Pengiriman'))])));

  Widget _exportOverlay() => Container(color: Colors.black.withValues(alpha: .12), child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)), const SizedBox(width: 14), Text(_exportingLabel ?? 'Menyiapkan laporan...')])))));

  Future<void> _showSettingsMenu() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.tune_outlined), title: const Text('Header Laporan'), onTap: () { Navigator.pop(context); _openReportHeaderSettings(); }), ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('Backup & Restore'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupRestoreScreen())); }), ListTile(leading: const Icon(Icons.sort_outlined), title: const Text('Urutkan Data'), subtitle: Text(_sort == _SortMode.terbaru ? 'Terbaru' : _sort == _SortMode.terlama ? 'Terlama' : 'Pengirim A-Z'), onTap: () { Navigator.pop(context); showMenu<_SortMode>(context: context, position: const RelativeRect.fromLTRB(100, 400, 20, 0), items: const [PopupMenuItem(value: _SortMode.terbaru, child: Text('Terbaru')), PopupMenuItem(value: _SortMode.terlama, child: Text('Terlama')), PopupMenuItem(value: _SortMode.pengirim, child: Text('Pengirim A-Z'))]).then((v) { if (v != null && mounted) setState(() => _sort = v); }); }), const SizedBox(height: 10)])));
    if (mounted) setState(() => _navIndex = 0);
  }
}
