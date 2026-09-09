import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/pengiriman.dart';

class ShipmentDetailScreen extends StatelessWidget {
  final Pengiriman shipment;
  final VoidCallback onEdit;
  final VoidCallback onSharePdf;
  final VoidCallback onShareExcel;
  final void Function(int index) onEditItem;

  const ShipmentDetailScreen({
    super.key,
    required this.shipment,
    required this.onEdit,
    required this.onSharePdf,
    required this.onShareExcel,
    required this.onEditItem,
  });

  String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pengiriman'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pdf') onSharePdf();
              if (v == 'excel') onShareExcel();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Bagikan PDF')),
              PopupMenuItem(value: 'excel', child: Text('Bagikan Excel')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shipment.nomorResi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(_date(shipment.tanggal), style: const TextStyle(color: AppColors.muted)),
                ])),
              ]),
              const SizedBox(height: 18),
              _Info(label: 'Pengirim', value: shipment.pengirim),
              if (shipment.noTelepon.isNotEmpty) _Info(label: 'No. Telepon', value: shipment.noTelepon),
              _Info(label: 'Kota/Kabupaten', value: shipment.kotaKabupaten),
              _Info(label: 'Kecamatan', value: shipment.kecamatan),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Informasi Barang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...shipment.barang.asMap().entries.map((entry) {
            final i = entry.key;
            final b = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onEditItem(i),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    if (b.photoPath != null && File(b.photoPath!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(b.photoPath!), width: 58, height: 58, fit: BoxFit.cover, cacheWidth: 174, cacheHeight: 174),
                      )
                    else
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                      ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${b.jumlah} pcs • ${b.panjang} × ${b.lebar} × ${b.tinggi} cm', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${b.kubikasi.toStringAsFixed(3)} m³ • ${b.totalBerat.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ])),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ]),
                ),
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              _Total(label: 'Total Barang', value: '${shipment.totalJumlah}'),
              _Total(label: 'Total Berat', value: '${shipment.totalBerat.toStringAsFixed(2)} kg'),
              _Total(label: 'Total Volume', value: shipment.totalVolume.toStringAsFixed(2)),
              const Divider(color: Colors.white24, height: 20),
              _Total(label: 'Total Kubikasi', value: '${shipment.totalKubikasi.toStringAsFixed(3)} m³', large: true),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('Edit'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: onSharePdf, icon: const Icon(Icons.share_outlined), label: const Text('Bagikan'))),
          ]),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 118, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12))),
          const Text('•  ', style: TextStyle(color: AppColors.border)),
          Expanded(child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Total extends StatelessWidget {
  final String label;
  final String value;
  final bool large;
  const _Total({required this.label, required this.value, this.large = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: large ? 13 : 12)),
          Text(value, style: TextStyle(color: Colors.white, fontSize: large ? 22 : 13, fontWeight: FontWeight.w800)),
        ]),
      );
}
