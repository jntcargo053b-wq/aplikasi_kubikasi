import 'dart:io';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:uuid/uuid.dart';
import '../models/barang_item.dart';
import '../services/storage_service.dart';
import '../widgets/barang_form_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  List<BarangItem> _items = [];
  bool _loading = true;

  // Cache hasil File.existsSync() per path supaya tidak I/O sync tiap
  // kali list di-rebuild (mis. tiap kali item lain ditambah/diedit/dihapus).
  final Map<String, bool> _photoExistsCache = {};

  bool _photoFileExists(String path) =>
      _photoExistsCache.putIfAbsent(path, () => File(path).existsSync());

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      var items = await _storage.load();
      if (items.isEmpty) {
        items = _contohData();
        await _storage.save(items);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Gagal memuat data: $e');
    }
  }

  Future<void> _persist() => _storage.save(_items);

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int get _totalJumlah => _items.fold(0, (sum, e) => sum + e.jumlah);
  double get _totalVolume => _items.fold(0.0, (sum, e) => sum + e.volume);
  double get _totalKubikasi => _items.fold(0.0, (sum, e) => sum + e.kubikasi);

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  String _fmtKubikasi(double v) => v.toStringAsFixed(3).replaceAll('.', ',');
  String _fmtUkuran(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().replaceAll('.', ',');
  }

  Future<void> _tambahBarang() async {
    try {
      final baru = await showBarangFormSheet(context);
      if (baru == null) return;
      setState(() => _items.add(baru));
      await _persist();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menambah barang: $e');
    }
  }

  Future<void> _editBarang(BarangItem item) async {
    try {
      final hasil = await showBarangFormSheet(context, existing: item);
      if (hasil == null) return;
      // Foto lama sudah dihapus dari disk oleh form kalau diganti/dihapus;
      // di sini cukup bersihkan entry cache-nya biar tidak menumpuk terus.
      if (item.photoPath != null && item.photoPath != hasil.photoPath) {
        _photoExistsCache.remove(item.photoPath);
      }
      setState(() {
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx != -1) _items[idx] = hasil;
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal mengubah barang: $e');
    }
  }

  Future<void> _hapusBarang(BarangItem item) async {
    try {
      final konfirmasi = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Barang'),
          content: Text('Hapus "${item.nama}" dari daftar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (konfirmasi != true) return;
      setState(() => _items.removeWhere((e) => e.id == item.id));
      await _persist();
      // Hapus juga file foto terkait supaya tidak jadi sampah di storage.
      final path = item.photoPath;
      if (path != null && path.isNotEmpty) {
        _photoExistsCache.remove(path);
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // Gagal hapus file bukan fatal untuk alur hapus item.
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menghapus barang: $e');
    }
  }

  Future<void> _hapusSemuaBarang() async {
    if (_items.isEmpty) return;
    try {
      final konfirmasi = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus Semua Barang'),
          content: Text(
              'Hapus semua ${_items.length} barang dari daftar? Tindakan ini tidak bisa dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus Semua',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (konfirmasi != true) return;

      // Kumpulkan path foto sebelum list dikosongkan, supaya file-nya juga
      // ikut dibersihkan dari storage.
      final photoPaths = _items
          .map((e) => e.photoPath)
          .where((p) => p != null && p.isNotEmpty)
          .cast<String>()
          .toList();

      setState(() {
        _items.clear();
        _photoExistsCache.clear();
      });
      await _persist();

      for (final path in photoPaths) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // Gagal hapus file bukan fatal untuk alur hapus semua.
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menghapus semua barang: $e');
    }
  }

  List<BarangItem> _contohData() => [
        BarangItem(
            id: const Uuid().v4(),
            nama: 'LEMARI',
            jumlah: 1,
            panjang: 182,
            lebar: 54,
            tinggi: 168),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'SISI BED',
            jumlah: 1,
            panjang: 192,
            lebar: 18,
            tinggi: 5),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'KAKI BED',
            jumlah: 1,
            panjang: 127,
            lebar: 50,
            tinggi: 5),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'KEPALA BED',
            jumlah: 1,
            panjang: 127,
            lebar: 24,
            tinggi: 80),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'BUFET',
            jumlah: 1,
            panjang: 63,
            lebar: 33,
            tinggi: 175),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'TOALET / MEJA RIAS',
            jumlah: 1,
            panjang: 120,
            lebar: 38,
            tinggi: 170),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'LEMARI PUTIH',
            jumlah: 1,
            panjang: 150,
            lebar: 39,
            tinggi: 138),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'MEJA KECIL',
            jumlah: 1,
            panjang: 46,
            lebar: 82,
            tinggi: 62),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'ALAS TEMPAT TIDUR',
            jumlah: 1,
            panjang: 120,
            lebar: 10,
            tinggi: 20),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'LACI',
            jumlah: 1,
            panjang: 37,
            lebar: 19,
            tinggi: 38),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'KURSI LIPAT',
            jumlah: 2,
            panjang: 8,
            lebar: 100,
            tinggi: 45),
        BarangItem(
            id: const Uuid().v4(),
            nama: 'KURSI TOALET (MEJA RIAS)',
            jumlah: 1,
            panjang: 43,
            lebar: 53,
            tinggi: 38),
      ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kalkulator Kubikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Hitung volume barang dengan cepat', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'hapus_semua') _hapusSemuaBarang();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'hapus_semua',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Hapus Semua', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahBarang,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (_items.isNotEmpty) _buildGuide(),
          _buildHeaderRow(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: _items.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, i) {
                      if (i == _items.length) {
                        return _buildTotalRow();
                      }
                      return _buildItemRow(_items[i], i + 1);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuide() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(
          children: [
            Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFFC2410C)),
            SizedBox(width: 8),
            Expanded(child: Text('Ketuk barang untuk edit • tekan lama untuk hapus', style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412), fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.inventory_2_outlined, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            const Text('Belum ada barang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 6),
            const Text('Tambahkan barang untuk mulai menghitung\nvolume dan kubikasi pengiriman.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _tambahBarang,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Barang'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    Widget child, {
    required int flex,
    Color? bg,
    Alignment alignment = Alignment.center,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        color: bg,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        alignment: alignment,
        child: child,
      ),
    );
  }

  Widget _buildHeaderRow() {
    TextStyle style(Color fg) => TextStyle(
          fontWeight: FontWeight.w800,
          color: fg,
          fontSize: 10,
          height: 1.15,
        );
    Widget headText(String text, {Color fg = AppColors.muted}) => Text(text, textAlign: TextAlign.center, style: style(fg));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border(top: BorderSide(color: AppColors.border), bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _cell(headText('NO'), flex: 1),
          _cell(headText('BARANG', fg: AppColors.text), flex: 5, alignment: Alignment.centerLeft),
          _cell(headText('JML'), flex: 2),
          _cell(headText('P'), flex: 2, bg: const Color(0xFFE8F5E9)),
          _cell(headText('L'), flex: 2, bg: const Color(0xFFE8F5E9)),
          _cell(headText('T'), flex: 2, bg: const Color(0xFFE8F5E9)),
          _cell(headText('VOL\n5000', fg: Colors.white), flex: 3, bg: AppColors.primary),
          _cell(headText('BERAT\nKG', fg: AppColors.text), flex: 3, bg: const Color(0xFFFFF1D6)),
          _cell(headText('KUBIKASI\nM³', fg: Colors.white), flex: 3, bg: AppColors.primaryDark),
        ],
      ),
    );
  }

  Widget _buildItemRow(BarangItem item, int no) {
    final zebraBg = no.isEven ? const Color(0xFFFCFCFD) : Colors.white;

    TextStyle normal = const TextStyle(
      fontSize: 11,
      color: AppColors.text,
      height: 1.15,
    );
    TextStyle number = const TextStyle(
      fontSize: 11,
      color: AppColors.text,
      height: 1.15,
    );

    return Material(
      color: zebraBg,
      child: InkWell(
        onTap: () => _editBarang(item),
        onLongPress: () => _hapusBarang(item),
        child: Row(
          children: [
            _cell(
              Text(
                '$no',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.muted,
                ),
              ),
              flex: 1,
            ),
            _cell(
              Row(
                children: [
                  _buildItemThumbnail(item),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.nama,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
              flex: 5,
              alignment: Alignment.centerLeft,
            ),
            _cell(
              Text(
                '${item.jumlah}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              flex: 2,
            ),
            _cell(Text(_fmtUkuran(item.panjang), style: number), flex: 2),
            _cell(Text(_fmtUkuran(item.lebar), style: number), flex: 2),
            _cell(Text(_fmtUkuran(item.tinggi), style: number), flex: 2),
            _cell(
              Text(
                _fmt(item.volume),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              flex: 3,
            ),
            _cell(
              Text(
                _fmt(item.berat),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              flex: 3,
            ),
            _cell(
              Text(
                _fmtKubikasi(item.kubikasi),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              flex: 3,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildItemThumbnail(BarangItem item) {
    final path = item.photoPath;
    final hasPhoto =
        path != null && path.isNotEmpty && _photoFileExists(path);
    return GestureDetector(
      onTap: hasPhoto ? () => _showPhotoPreview(path!) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          width: 34, height: 34,
          child: hasPhoto
              ? Image.file(
                  File(path!),
                  fit: BoxFit.cover,
                  // Decode sesuai ukuran tampil (34dp), bukan resolusi asli
                  // foto (bisa sampai 1400x1400) — ini yang paling boros
                  // memory kalau daftar barang panjang & banyak berfoto.
                  cacheWidth:
                      (34 * MediaQuery.of(context).devicePixelRatio).round(),
                  cacheHeight:
                      (34 * MediaQuery.of(context).devicePixelRatio).round(),
                  errorBuilder: (_, __, ___) => _photoPlaceholder(),
                )
              : _photoPlaceholder(),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFF0F2F5),
      child: Icon(Icons.image_outlined, size: 17, color: AppColors.muted),
    );
  }

  void _showPhotoPreview(String path) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(File(path), fit: BoxFit.contain)),
            Positioned(
              top: 4, right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _totalBerat {
    return _items.fold<double>(
      0,
      (sum, item) => sum + item.jumlah * item.berat,
    );
  }

  Widget _buildTotalRow() {
    const totalLabel = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    );
    const totalNumber = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          _cell(const SizedBox.shrink(), flex: 1, bg: const Color(0xFFF7F8FA)),
          _cell(
            const Text('TOTAL', style: totalLabel),
            flex: 5,
            bg: const Color(0xFFF7F8FA),
            alignment: Alignment.centerLeft,
          ),
          _cell(
            Text('$_totalJumlah', style: totalNumber),
            flex: 2,
            bg: const Color(0xFFF7F8FA),
          ),
          _cell(const SizedBox.shrink(), flex: 2, bg: const Color(0xFFF7F8FA)),
          _cell(const SizedBox.shrink(), flex: 2, bg: const Color(0xFFF7F8FA)),
          _cell(const SizedBox.shrink(), flex: 2, bg: const Color(0xFFF7F8FA)),
          _cell(
            Text(
              _fmt(_totalVolume),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            flex: 3,
            bg: const Color(0xFFF7F8FA),
          ),
          _cell(
            Text(
              _fmt(_totalBerat),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            flex: 3,
            bg: const Color(0xFFF7F8FA),
          ),
          _cell(
            Text(
              _fmtKubikasi(_totalKubikasi),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            flex: 3,
            bg: const Color(0xFFF7F8FA),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A101828), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(child: _summaryStat('TOTAL BARANG', '$_totalJumlah', 'item')),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(child: _summaryStat('VOL. TIMBANG', _fmt(_totalVolume), 'kg', accent: AppColors.primary)),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(child: _summaryStat('TOTAL KUBIKASI', _fmtKubikasi(_totalKubikasi), 'm³', accent: AppColors.primaryDark)),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, String unit, {Color accent = AppColors.text}) {
    return Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 4),
        RichText(text: TextSpan(children: [TextSpan(text: value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent)), TextSpan(text: ' $unit', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted))])),
      ],
    );
  }
}
