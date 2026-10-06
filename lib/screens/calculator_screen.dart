import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/barang_item.dart';
import '../models/pengiriman.dart';
import '../services/storage_service.dart';
import '../services/photo_storage_service.dart';
import 'package:uuid/uuid.dart';
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
  final FocusNode panjangFocus = FocusNode();
  final FocusNode lebarFocus = FocusNode();
  final FocusNode tinggiFocus = FocusNode();
  final FocusNode jumlahFocus = FocusNode();
  final FocusNode beratFocus = FocusNode();

  double _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    return value != null && value.isFinite ? value : 0;
  }

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
    panjangFocus.dispose(); lebarFocus.dispose(); tinggiFocus.dispose(); jumlahFocus.dispose(); beratFocus.dispose();
  }
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final List<_CalculatorItem> _items = [_CalculatorItem()];
  bool _savingShipment = false;

  double get _totalKubikasi => _items.fold(0, (sum, item) => sum + item.kubikasi);
  double get _totalVolumetric => _items.fold(0, (sum, item) => sum + item.volumetricWeight);
  double get _totalActual => _items.fold(0, (sum, item) => sum + item.actualWeight);
  int get _totalPieces => _items.fold(0, (sum, item) => sum + item.qty);

  bool _isReadyForShipment(_CalculatorItem item) =>
      item.qty > 0 &&
      item._number(item.panjang) > 0 &&
      item._number(item.lebar) > 0 &&
      item._number(item.tinggi) > 0 &&
      item._number(item.berat) >= 0 &&
      item.kubikasi.isFinite &&
      item.volumetricWeight.isFinite &&
      item.actualWeight.isFinite;

  Future<void> _continueToShipment() async {
    if (_savingShipment) return;
    final invalidIndex = _items.indexWhere((item) => !_isReadyForShipment(item));
    if (invalidIndex != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lengkapi ukuran, jumlah, dan berat Barang ${invalidIndex + 1} sebelum lanjut.',
          ),
        ),
      );
      return;
    }

    final barang = _items
        .asMap()
        .entries
        .map(
          (entry) => BarangItem(
            id: const Uuid().v4(),
            nama: 'Barang ${entry.key + 1}',
            jumlah: entry.value.qty,
            panjang: entry.value._number(entry.value.panjang),
            lebar: entry.value._number(entry.value.lebar),
            tinggi: entry.value._number(entry.value.tinggi),
            berat: entry.value._number(entry.value.berat),
          ),
        )
        .toList();

    setState(() => _savingShipment = true);
    try {
      final shipment = await showPengirimanFormSheet(
        context,
        initialBarang: barang,
      );
      if (shipment == null || !mounted) return;

      var shipmentPersisted = false;
      try {
        final storage = StorageService();
        final existing = await storage.loadPengiriman();
        if (!mounted) return;

        final resi = shipment.nomorResi.trim().toLowerCase();
        final duplicateResi = resi.isNotEmpty &&
            existing.any(
              (item) => item.nomorResi.trim().toLowerCase() == resi,
            );
        if (duplicateResi) {
          await PhotoStorageService.deleteAll(
            shipment.barang.map((item) => item.photoPath),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nomor resi sudah digunakan. Gunakan nomor resi yang berbeda.',
              ),
            ),
          );
          return;
        }

        await storage.savePengiriman([...existing, shipment]);
        shipmentPersisted = true;
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (error) {
        // Once persisted, keep referenced photos even if route navigation fails.
        if (!shipmentPersisted) {
          await PhotoStorageService.deleteAll(
            shipment.barang.map((item) => item.photoPath),
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengiriman: $error'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingShipment = false);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    final item = _CalculatorItem();
    setState(() => _items.add(item));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.panjangFocus.requestFocus();
    });
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
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_totalKubikasi.toStringAsFixed(3)} m³',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
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
          FilledButton.icon(
            onPressed: !_savingShipment && _items.every(_isReadyForShipment)
                ? _continueToShipment
                : null,
            icon: _savingShipment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_box_outlined),
            label: Text(
              _savingShipment ? 'Menyimpan...' : 'Lanjut ke Pengiriman',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Data ukuran, jumlah, dan berat akan otomatis dibawa ke form pengiriman.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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
                  focusNode: item.panjangFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => item.lebarFocus.requestFocus(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Panjang', suffix: 'cm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.lebar,
                  focusNode: item.lebarFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => item.tinggiFocus.requestFocus(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: _dec('Lebar', suffix: 'cm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.tinggi,
                  focusNode: item.tinggiFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => item.jumlahFocus.requestFocus(),
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
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Kurangi jumlah',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final next = (item.qty - 1).clamp(1, 999999);
                        item.jumlah.text = next.toString();
                        item.jumlah.selection = TextSelection.collapsed(
                          offset: item.jumlah.text.length,
                        );
                        setState(() {});
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: item.jumlah,
                        focusNode: item.jumlahFocus,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => item.beratFocus.requestFocus(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '1',
                          suffixText: 'pcs',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tambah jumlah',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final next = (item.qty + 1).clamp(1, 999999);
                        item.jumlah.text = next.toString();
                        item.jumlah.selection = TextSelection.collapsed(
                          offset: item.jumlah.text.length,
                        );
                        setState(() {});
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.berat,
                  focusNode: item.beratFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _continueToShipment(),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      );
}
