import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../models/packing_calculation.dart';

class PackingCalculatorScreen extends StatefulWidget {
  const PackingCalculatorScreen({super.key});

  @override
  State<PackingCalculatorScreen> createState() => _PackingCalculatorScreenState();
}

class _PackingCalculatorScreenState extends State<PackingCalculatorScreen> {
  static const _ratesKey = 'packing_calculator_rates_v1';
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _packages = TextEditingController(text: '1');
  final _boardSheets = TextEditingController(text: '0');
  final _boardPrice = TextEditingController(text: '0');

  final _woodRate = TextEditingController(text: '3500');
  final _woodStickLength = TextEditingController(text: '200');
  final _woodLengthMultiplier = TextEditingController(text: '8');
  final _woodWidthMultiplier = TextEditingController(text: '8');
  final _woodHeightMultiplier = TextEditingController(text: '4');
  final _screwRate = TextEditingController(text: '320');
  final _nailRate = TextEditingController(text: '25');
  final _nailsPerKg = TextEditingController(text: '430');
  final _fasteners = TextEditingController(text: '68');
  final _laborRate = TextEditingController(text: '15000');
  final _electricityRate = TextEditingController(text: '1500');
  final _overheadRate = TextEditingController(text: '5000');
  final _margin = TextEditingController(text: '25');
  final _additionalQuantity = TextEditingController(text: '0');
  final _additionalPrice = TextEditingController(text: '0');

  PackingFastener _fastener = PackingFastener.nails;
  bool _includeBoard = false;
  bool _loading = true;
  bool _savingRates = false;

  static final _currency = NumberFormat.currency(
    locale: 'id_ID', symbol: 'Rp', decimalDigits: 0,
  );

  double _read(TextEditingController c) {
    final raw = c.text.trim();
    final normalized = raw.contains(',')
        ? raw.replaceAll('.', '').replaceAll(',', '.')
        : raw;
    return double.tryParse(normalized) ?? 0;
  }

  int _readInt(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  PackingRates get _rates => PackingRates(
    woodPerLonjor: _read(_woodRate),
    woodStickLengthCm: _read(_woodStickLength),
    woodLengthMultiplier: _read(_woodLengthMultiplier),
    woodWidthMultiplier: _read(_woodWidthMultiplier),
    woodHeightMultiplier: _read(_woodHeightMultiplier),
    screwPerPiece: _read(_screwRate),
    nailPerGram: _read(_nailRate),
    nailsPerKg: _readInt(_nailsPerKg),
    laborPerPackage: _read(_laborRate),
    electricityPerPackage: _read(_electricityRate),
    overheadPerPackage: _read(_overheadRate),
    fastenersPerPackage: _readInt(_fasteners),
    marginPercent: _read(_margin),
    boardSheetsPerPackage: _read(_boardSheets),
    boardPricePerSheet: _read(_boardPrice),
    additionalMaterialQuantityPerPackage: _read(_additionalQuantity),
    additionalMaterialPricePerUnit: _read(_additionalPrice),
  );

  PackingCalculation? get _calculation {
    final p = _read(_length), l = _read(_width), t = _read(_height);
    if (p <= 0 || l <= 0 || t <= 0 || _readInt(_packages) <= 0) return null;
    try {
      return PackingCalculation.calculate(
        lengthCm: p,
        widthCm: l,
        heightCm: t,
        packageCount: _readInt(_packages),
        fastener: _fastener,
        rates: _rates,
        includeBoard: _includeBoard,
        boardCostPerPackage: null,
      );
    } on ArgumentError {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratesKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final r = PackingRates.fromJson(Map<String, dynamic>.from(decoded));
          _woodRate.text = r.woodPerLonjor.toStringAsFixed(0);
          _woodStickLength.text = r.woodStickLengthCm.toString();
          _woodLengthMultiplier.text = r.woodLengthMultiplier.toString();
          _woodWidthMultiplier.text = r.woodWidthMultiplier.toString();
          _woodHeightMultiplier.text = r.woodHeightMultiplier.toString();
          _screwRate.text = r.screwPerPiece.toStringAsFixed(0);
          _nailRate.text = r.nailPerGram.toStringAsFixed(0);
          _nailsPerKg.text = r.nailsPerKg.toString();
          _fasteners.text = r.fastenersPerPackage.toString();
          _laborRate.text = r.laborPerPackage.toStringAsFixed(0);
          _electricityRate.text = r.electricityPerPackage.toStringAsFixed(0);
          _overheadRate.text = r.overheadPerPackage.toStringAsFixed(0);
          _margin.text = r.marginPercent.toStringAsFixed(0);
          _boardSheets.text = r.boardSheetsPerPackage.toString();
          _boardPrice.text = r.boardPricePerSheet.toStringAsFixed(0);
          _additionalQuantity.text = r.additionalMaterialQuantityPerPackage.toString();
          _additionalPrice.text = r.additionalMaterialPricePerUnit.toStringAsFixed(0);
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveRates() async {
    if (_savingRates) return;
    final r = _rates;
    if (r.nailsPerKg <= 0 || r.fastenersPerPackage < 0 ||
        r.marginPercent < 0 || r.marginPercent >= 100 ||
        r.woodStickLengthCm <= 0 ||
        [r.woodStickLengthCm, r.woodLengthMultiplier, r.woodWidthMultiplier,
          r.woodHeightMultiplier, r.boardSheetsPerPackage, r.boardPricePerSheet,
          r.additionalMaterialQuantityPerPackage, r.additionalMaterialPricePerUnit].any((v) => !v.isFinite || v < 0) ||
        [r.woodPerLonjor, r.screwPerPiece, r.nailPerGram,
          r.laborPerPackage, r.electricityPerPackage, r.overheadPerPackage]
            .any((v) => !v.isFinite || v < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Periksa tarif. Nilai harus valid dan margin di bawah 100%.')),
      );
      return;
    }
    setState(() => _savingRates = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(_ratesKey, jsonEncode(r.toJson()));
      if (!ok) throw StateError('Pengaturan tidak dapat disimpan.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarif packing berhasil disimpan di perangkat.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tarif: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRates = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _length, _width, _height, _packages, _boardSheets, _boardPrice, _woodRate,
      _screwRate, _nailRate, _nailsPerKg, _fasteners, _laborRate,
      _electricityRate, _overheadRate, _margin, _woodStickLength,
      _woodLengthMultiplier, _woodWidthMultiplier, _woodHeightMultiplier,
      _additionalQuantity, _additionalPrice,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, {String? suffix}) =>
      InputDecoration(labelText: label, suffixText: suffix, isDense: true);

  Widget _moneyLine(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: AppColors.text))),
      Text(_currency.format(value), style: const TextStyle(fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _rateField(String label, TextEditingController controller, {String? suffix}) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: _dec(label, suffix: suffix),
      );

  @override
  Widget build(BuildContext context) {
    final result = _calculation;
    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator Packing Kayu')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ukuran barang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _rateField('Panjang', _length, suffix: 'cm')),
                      const SizedBox(width: 8),
                      Expanded(child: _rateField('Lebar', _width, suffix: 'cm')),
                      const SizedBox(width: 8),
                      Expanded(child: _rateField('Tinggi', _height, suffix: 'cm')),
                    ]),
                    const SizedBox(height: 12),
                    _rateField('Jumlah koli', _packages, suffix: 'koli'),
                  ]),
                )),
                const SizedBox(height: 12),
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bahan pengikat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SegmentedButton<PackingFastener>(
                      segments: const [
                        ButtonSegment(value: PackingFastener.nails, label: Text('Paku 1¼ inch')),
                        ButtonSegment(value: PackingFastener.screws, label: Text('Sekrup')),
                      ],
                      selected: {_fastener},
                      onSelectionChanged: (v) => setState(() => _fastener = v.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fastener == PackingFastener.nails
                          ? 'Estimasi ${_readInt(_fasteners)} batang per koli; 430 batang = 1 kg.'
                          : 'Estimasi ${_readInt(_fasteners)} sekrup per koli.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ]),
                )),
                const SizedBox(height: 12),
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tambahkan papan penutup', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Opsional, aktifkan jika pelanggan meminta papan penutup.'),
                      value: _includeBoard,
                      onChanged: (v) => setState(() => _includeBoard = v),
                    ),
                    if (_includeBoard) ...[
                      const SizedBox(height: 8),
                      _rateField('Kebutuhan papan per koli', _boardSheets, suffix: 'lembar'),
                      const SizedBox(height: 8),
                      _rateField('Harga per lembar papan', _boardPrice, suffix: 'Rp'),
                    ],
                  ]),
                )),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Pengaturan tarif', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Tarif dapat disesuaikan dan disimpan secara lokal.'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    _rateField('Harga kayu per lonjor', _woodRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Panjang satu lonjor', _woodStickLength, suffix: 'cm'),
                    const SizedBox(height: 8),
                    const Align(alignment: Alignment.centerLeft, child: Text('Kebutuhan rangka per ukuran barang', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _rateField('Pengali panjang', _woodLengthMultiplier)),
                      const SizedBox(width: 8),
                      Expanded(child: _rateField('Pengali lebar', _woodWidthMultiplier)),
                      const SizedBox(width: 8),
                      Expanded(child: _rateField('Pengali tinggi', _woodHeightMultiplier)),
                    ]),
                    const SizedBox(height: 8),
                    _rateField('Sekrup per buah', _screwRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Paku per gram', _nailRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Jumlah batang paku per kg', _nailsPerKg, suffix: 'batang'),
                    const SizedBox(height: 8),
                    _rateField('Jumlah paku/sekrup per koli', _fasteners, suffix: 'buah'),
                    const SizedBox(height: 8),
                    _rateField('Upah per koli', _laborRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Listrik per koli', _electricityRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Overhead per koli', _overheadRate, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Kebutuhan bahan tambahan per koli', _additionalQuantity, suffix: 'unit'),
                    const SizedBox(height: 8),
                    _rateField('Harga per unit bahan tambahan', _additionalPrice, suffix: 'Rp'),
                    const SizedBox(height: 8),
                    _rateField('Margin keuntungan', _margin, suffix: '%'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _savingRates ? null : _saveRates,
                      icon: _savingRates
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Simpan tarif'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (result == null)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Masukkan panjang, lebar, dan tinggi untuk melihat estimasi ongkos packing.'),
                  ))
                else
                  Card(
                    color: AppColors.primarySoft,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Rincian biaya packing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text('Panjang rangka: ${result.frameLengthCm.toStringAsFixed(0)} cm per koli'),
                        Text('Kayu: ${result.woodSticksPerPackage} lonjor per koli × ${_readInt(_packages)} koli'),
                        Text(_fastener == PackingFastener.nails
                            ? 'Paku: ${result.fastenerQuantity.toStringAsFixed(1)} gram'
                            : 'Sekrup: ${result.fastenerQuantity.toStringAsFixed(0)} buah'),
                        const Divider(height: 22),
                        _moneyLine('Kayu rangka', result.woodCost),
                        _moneyLine(_fastener == PackingFastener.nails ? 'Paku 1¼ inch' : 'Sekrup', result.fastenerCost),
                        _moneyLine('Upah pengerjaan', result.laborCost),
                        _moneyLine('Listrik', result.electricityCost),
                        _moneyLine('Overhead', result.overheadCost),
                        if (_includeBoard) _moneyLine('Papan penutup (${result.boardQuantity.toStringAsFixed(1)} lembar)', result.boardCost),
                        if (result.additionalMaterialQuantity > 0)
                          _moneyLine('Bahan tambahan (${result.additionalMaterialQuantity.toStringAsFixed(1)} unit)', result.additionalMaterialCost),
                        const Divider(height: 22),
                        _moneyLine('Total modal', result.totalCost),
                        _moneyLine('Harga sebelum pembulatan', result.suggestedPrice),
                        const SizedBox(height: 8),
                        const Text('ESTIMASI HARGA JUAL', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800, fontSize: 12)),
                        Text(_currency.format(result.roundedPrice), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        Text('Margin ${_rates.marginPercent.toStringAsFixed(0)}% • dibulatkan ke atas per Rp1.000', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Catatan: jumlah pengikat 68 buah per koli adalah asumsi awal yang bisa diubah. Biaya papan diisi manual karena ukuran dan harga lembar papan belum ditetapkan.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
