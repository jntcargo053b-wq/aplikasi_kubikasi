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

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
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
        title: const Text('Kalkulator Volume Barang'),
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
          _buildHeaderRow(),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Belum ada barang'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, i) => _buildItemRow(_items[i], i + 1),
                  ),
          ),
          _buildTotalRow(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    TextStyle headStyle(Color bg, Color fg) => TextStyle(
          fontWeight: FontWeight.bold,
          color: fg,
          fontSize: 12,
        );
    Widget cell(String text, {Color? bg, Color fg = Colors.black87, int flex = 2}) {
      return Expanded(
        flex: flex,
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: headStyle(bg ?? Colors.transparent, fg),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          cell('NO', flex: 1),
          cell('BARANG', flex: 4),
          cell('JML', flex: 2),
          cell('P', bg: Colors.green.shade200, flex: 2),
          cell('L', bg: Colors.green.shade200, flex: 2),
          cell('T', bg: Colors.green.shade200, flex: 2),
          cell('VOLUME', bg: Colors.red, fg: Colors.white, flex: 3),
        ],
      ),
    );
  }

  Widget _buildItemRow(BarangItem item, int no) {
    Widget cell(Widget child, {int flex = 2}) => Expanded(
          flex: flex,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            alignment: Alignment.center,
            child: child,
          ),
        );

    return InkWell(
      onTap: () => _editBarang(item),
      onLongPress: () => _hapusBarang(item),
      child: Row(
        children: [
          cell(Text('$no'), flex: 1),
          cell(
            Text(item.nama,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
            flex: 4,
          ),
          cell(Text('${item.jumlah}'), flex: 2),
          cell(Text(_fmtUkuran(item.panjang)), flex: 2),
          cell(Text(_fmtUkuran(item.lebar)), flex: 2),
          cell(Text(_fmtUkuran(item.tinggi)), flex: 2),
          cell(
            Text(
              _fmt(item.volume),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            flex: 3,
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TOTAL  ($_totalJumlah barang)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _fmt(_totalVolume),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
