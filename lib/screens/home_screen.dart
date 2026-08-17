import 'package:flutter/material.dart';
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
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal menghapus barang: $e');
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
        title: const Text('Kalkulator Volume & Kubikasi'),
        centerTitle: false,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahBarang,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      // TOTAL row dipindah ke bottomNavigationBar (bukan child terakhir
      // body Column) supaya Scaffold otomatis mengangkat FAB di atasnya
      // dengan jarak yang benar, sehingga FAB tidak pernah menutupi
      // angka TOTAL VOL/KUBIKASI di pojok kanan bawah.
      bottomNavigationBar: SafeArea(child: _buildTotalRow()),
      body: Column(
        children: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ketuk baris untuk edit, tekan lama untuk hapus.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          _buildHeaderRow(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, i) => _buildItemRow(_items[i], i + 1),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Belum ada barang',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan tombol "Tambah" di bawah untuk mulai\nmenghitung volume & kubikasi barang.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // Kolom pakai proporsi (flex) supaya muat di lebar layar HP tanpa perlu
  // scroll horizontal. Struktur ini sengaja dibuat SEDERHANA (satu
  // ListView vertikal biasa, tanpa nested SingleChildScrollView
  // horizontal) supaya gesture tap/long-press pada baris pasti terdeteksi
  // dengan baik di semua perangkat.
  Widget _cell(Widget child, {required int flex, Color? bg}) {
    return Expanded(
      flex: flex,
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildHeaderRow() {
    TextStyle style(Color fg) =>
        TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 11);
    Widget headText(String text, {Color fg = Colors.black87}) =>
        Text(text, textAlign: TextAlign.center, style: style(fg));

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _cell(headText('NO'), flex: 1),
          _cell(headText('BARANG'), flex: 5),
          _cell(headText('JML'), flex: 2),
          _cell(headText('P'), flex: 2, bg: Colors.green.shade200),
          _cell(headText('L'), flex: 2, bg: Colors.green.shade200),
          _cell(headText('T'), flex: 2, bg: Colors.green.shade200),
          _cell(
            Tooltip(
              message: 'Volume timbang (P x L x T / 5000)',
              child: headText('VOL\nTIMBANG', fg: Colors.white),
            ),
            flex: 3,
            bg: Colors.red.shade600,
          ),
          _cell(headText('KUBI-\nKASI (M³)', fg: Colors.white),
              flex: 3, bg: Colors.red.shade800),
        ],
      ),
    );
  }

  Widget _buildItemRow(BarangItem item, int no) {
    final zebraBg = no.isEven ? Colors.grey.shade50 : Colors.white;
    return Material(
      color: zebraBg,
      child: InkWell(
        onTap: () => _editBarang(item),
        onLongPress: () => _hapusBarang(item),
        child: Row(
          children: [
            _cell(Text('$no', style: const TextStyle(fontSize: 12)), flex: 1),
            _cell(
              Text(item.nama,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              flex: 5,
            ),
            _cell(Text('${item.jumlah}', style: const TextStyle(fontSize: 12)),
                flex: 2),
            _cell(
                Text(_fmtUkuran(item.panjang),
                    style: const TextStyle(fontSize: 12)),
                flex: 2),
            _cell(
                Text(_fmtUkuran(item.lebar),
                    style: const TextStyle(fontSize: 12)),
                flex: 2),
            _cell(
                Text(_fmtUkuran(item.tinggi),
                    style: const TextStyle(fontSize: 12)),
                flex: 2),
            _cell(
              Text(
                _fmt(item.volume),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade600,
                  fontSize: 12,
                ),
              ),
              flex: 3,
            ),
            _cell(
              Text(
                _fmtKubikasi(item.kubikasi),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                  fontSize: 11,
                ),
              ),
              flex: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _cell(
            Text(
              'TOTAL ($_totalJumlah)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              textAlign: TextAlign.left,
            ),
            flex: 10,
          ),
          _cell(
            Text(
              _fmt(_totalVolume),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.red,
              ),
            ),
            flex: 3,
          ),
          _cell(
            Text(
              _fmtKubikasi(_totalKubikasi),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.red.shade700,
              ),
            ),
            flex: 3,
          ),
        ],
      ),
    );
  }
}
