import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'pengiriman_form_sheet.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _panjang = TextEditingController();
  final _lebar = TextEditingController();
  final _tinggi = TextEditingController();
  final _jumlah = TextEditingController(text: '1');
  final _berat = TextEditingController();

  double _number(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  int get _qty => int.tryParse(_jumlah.text) ?? 0;
  double get _kubikasi => _number(_panjang) * _number(_lebar) * _number(_tinggi) * _qty / 1000000;
  double get _volume => _number(_panjang) * _number(_lebar) * _number(_tinggi) * _qty / 5000;
  double get _totalBerat => _number(_berat) * _qty;

  @override
  void dispose() {
    _panjang.dispose();
    _lebar.dispose();
    _tinggi.dispose();
    _jumlah.dispose();
    _berat.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? suffix, IconData? icon}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon == null ? null : Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hitung Kubikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kalkulator cepat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('Masukkan ukuran dalam sentimeter.', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: TextField(controller: _panjang, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Panjang', suffix: 'cm'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _lebar, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Lebar', suffix: 'cm'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _tinggi, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Tinggi', suffix: 'cm'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _jumlah, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Jumlah', icon: Icons.inventory_2_outlined))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _berat, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: _dec('Berat/pcs', suffix: 'kg'))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x222563EB), blurRadius: 24, offset: Offset(0, 12))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hasil Kubikasi', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${_kubikasi.toStringAsFixed(3)} m³', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Result(label: 'Volume', value: '${_volume.toStringAsFixed(2)} kg volumetrik')),
                Expanded(child: _Result(label: 'Berat aktual', value: '${_totalBerat.toStringAsFixed(2)} kg')),
              ]),
            ]),
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
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      );
}
