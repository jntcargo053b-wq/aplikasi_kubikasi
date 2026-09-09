import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'pengiriman_form_sheet.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorItem {
  final TextEditingController panjang = TextEditingController();
  final TextEditingController lebar = TextEditingController();
  final TextEditingController tinggi = TextEditingController();
  final TextEditingController jumlah = TextEditingController(text: '1');
  final TextEditingController berat = TextEditingController();

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  int get qty => int.tryParse(jumlah.text) ?? 0;
  double get singleM3 => _number(panjang) * _number(lebar) * _number(tinggi) / 1000000;
  double get kubikasi => singleM3 * qty;
  double get volumetricWeight =>
      _number(panjang) * _number(lebar) * _number(tinggi) * qty / 5000;
  double get actualWeight => _number(berat) * qty;

  void dispose() {
    panjang.dispose();
    lebar.dispose();
    tinggi.dispose();
    jumlah.dispose();
    berat.dispose();
  }
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final List<_CalculatorItem> _items = [_CalculatorItem()];

  double get _totalKubikasi => _items.fold(0, (sum, item) => sum + item.kubikasi);
  double get _totalVolumetric => _items.fold(0, (sum, item) => sum + item.volumetricWeight);
  double get _totalActual => _items.fold(0, (sum, item) => sum + item.actualWeight);
  int get _totalPieces => _items.fold(0, (sum, item) => sum + item.qty);

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_CalculatorItem()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      _clearItem(_items.first);
      return;
    }
    final item = _items.removeAt(index);
    item.dispose();
    setState(() {});
  }

  void _clearItem(_CalculatorItem item) {
    item.panjang.clear();
    item.lebar.clear();
    item.tinggi.clear();
    item.jumlah.text = '1';
    item.berat.clear();
    setState(() {});
  }

  void _clearAll() {
    for (final item in _items) {
      item.dispose();
    }
    setState(() {
      _items
        ..clear()
        ..add(_CalculatorItem());
    });
  }

  InputDecoration _dec(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hitung Kubikasi'),
        actions: [
          IconButton(
            tooltip: 'Clear semua',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalkulator kubikasi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Tambahkan beberapa jenis barang untuk menghitung total sekaligus.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_items.length} jenis barang • $_totalPieces pcs',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearAll,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_items.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _itemCard(index, _items[index]),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Barang'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x222563EB),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Kubikasi',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_totalKubikasi.toStringAsFixed(3)} m³',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Result(
                        label: 'Volumetrik',
                        value: '${_totalVolumetric.toStringAsFixed(2)} kg',
                      ),
                    ),
                    Expanded(
                      child: _Result(
                        label: 'Berat aktual',
                        value: '${_totalActual.toStringAsFixed(2)} kg',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showPengirimanFormSheet(context),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Lanjut ke Pengiriman'),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(int index, _CalculatorItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Barang ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Clear barang',
                onPressed: () => _clearItem(item),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Hapus barang',
                onPressed: () => _removeItem(index),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: _items.length > 1 ? AppColors.text : AppColors.muted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.panjang,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Panjang', suffix: 'cm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.lebar,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Lebar', suffix: 'cm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.tinggi,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Tinggi', suffix: 'cm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.jumlah,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Jumlah', suffix: 'pcs'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.berat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Berat/pcs', suffix: 'kg'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.kubikasi.toStringAsFixed(3)} m³',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${item.actualWeight.toStringAsFixed(2)} kg',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final String label;
  final String value;

  const _Result({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
}
