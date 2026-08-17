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

  // Lebar kolom tetap supaya tabel bisa di-scroll horizontal dan semua
  // kolom (termasuk KUBIKASI) tetap terbaca jelas di layar HP.
  static const double _wNo = 32;
  static const double _wNama = 150;
  static const double _wJml = 48;
  static const double _wUkuran = 52;
  static const double _wVolume = 84;
  static const double _wKubikasi = 92;
  double get _tableWidth =>
      _wNo + _wNama + _wJml + (_wUkuran * 3) + _wVolume + _wKubikasi;

  final ScrollController _headerScrollCtrl = ScrollController();
  final ScrollController _bodyScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Header tidak bisa digeser langsung oleh user, jadi posisinya
    // disinkronkan mengikuti scroll body secara manual di sini.
    _bodyScrollCtrl.addListener(() {
      if (_headerScrollCtrl.hasClients &&
          _headerScrollCtrl.offset != _bodyScrollCtrl.offset) {
        _headerScrollCtrl.jumpTo(_bodyScrollCtrl.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerScrollCtrl.dispose();
    _bodyScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    var items = await _storage.load();
    if (items.isEmpty) {
      items = _contohData();
      await _storage.save(items);
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _persist() => _storage.save(_items);

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
    final baru = await showBarangFormSheet(context);
    if (baru == null) return;
    setState(() => _items.add(baru));
    await _persist();
  }

  Future<void> _editBarang(BarangItem item) async {
    final hasil = await showBarangFormSheet(context, existing: item);
    if (hasil == null) return;
    setState(() {
      final idx = _items.indexWhere((e) => e.id == item.id);
      if (idx != -1) _items[idx] = hasil;
    });
    await _persist();
  }

  Future<void> _hapusBarang(BarangItem item) async {
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
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _persist();
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
                      'Ketuk baris untuk edit, tekan lama untuk hapus. '
                      'Geser tabel ke samping untuk lihat semua kolom.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            controller: _headerScrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(width: _tableWidth, child: _buildHeaderRow()),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Belum ada barang'))
                : SingleChildScrollView(
                    controller: _bodyScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _tableWidth,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (ctx, i) =>
                            _buildItemRow(_items[i], i + 1),
                      ),
                    ),
                  ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(width: _tableWidth, child: _buildTotalRow()),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    Widget child, {
    required double width,
    Color? bg,
  }) {
    return Container(
      width: width,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _buildHeaderRow() {
    TextStyle style(Color fg) =>
        TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 12);
    Widget headText(String text, {Color? bg, Color fg = Colors.black87}) =>
        Text(text, textAlign: TextAlign.center, style: style(fg));

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _cell(headText('NO'), width: _wNo),
          _cell(headText('BARANG'), width: _wNama),
          _cell(headText('JML'), width: _wJml),
          _cell(headText('P'), width: _wUkuran, bg: Colors.green.shade200),
          _cell(headText('L'), width: _wUkuran, bg: Colors.green.shade200),
          _cell(headText('T'), width: _wUkuran, bg: Colors.green.shade200),
          _cell(headText('VOL 5000', fg: Colors.white),
              width: _wVolume, bg: Colors.red),
          _cell(headText('KUBIKASI (M³)', fg: Colors.white),
              width: _wKubikasi, bg: Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _buildItemRow(BarangItem item, int no) {
    return InkWell(
      onTap: () => _editBarang(item),
      onLongPress: () => _hapusBarang(item),
      child: Row(
        children: [
          _cell(Text('$no'), width: _wNo),
          _cell(
            Text(item.nama,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
            width: _wNama,
          ),
          _cell(Text('${item.jumlah}'), width: _wJml),
          _cell(Text(_fmtUkuran(item.panjang)), width: _wUkuran),
          _cell(Text(_fmtUkuran(item.lebar)), width: _wUkuran),
          _cell(Text(_fmtUkuran(item.tinggi)), width: _wUkuran),
          _cell(
            Text(
              _fmt(item.volume),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            width: _wVolume,
          ),
          _cell(
            Text(
              _fmtKubikasi(item.kubikasi),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            width: _wKubikasi,
          ),
        ],
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.left,
            ),
            width: _wNo + _wNama + _wJml + (_wUkuran * 3),
          ),
          _cell(
            Text(
              _fmt(_totalVolume),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            width: _wVolume,
          ),
          _cell(
            Text(
              _fmtKubikasi(_totalKubikasi),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
            width: _wKubikasi,
          ),
        ],
      ),
    );
  }
}
