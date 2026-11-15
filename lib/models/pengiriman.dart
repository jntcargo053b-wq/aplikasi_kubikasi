import 'package:uuid/uuid.dart';
import 'barang_item.dart';

class Pengiriman {
  final String id;
  final String pengirim;
  final String namaPenerima;
  final String noTelepon;
  final DateTime tanggal;
  final String nomorResi;
  final String kotaKabupaten;
  final String kecamatan;
  /// Null keeps legacy per-item weight calculation; otherwise this is the shipment-wide weight in kg.
  final double? beratGlobal;
  final List<BarangItem> barang;

  Pengiriman({
    required this.id,
    required this.pengirim,
    this.namaPenerima = '',
    this.noTelepon = '',
    required this.tanggal,
    required this.nomorResi,
    this.kotaKabupaten = '',
    this.kecamatan = '',
    this.beratGlobal,
    required this.barang,
  });

  int get totalJumlah => barang.fold(0, (s, e) => s + e.jumlah);
  double get totalVolume => barang.fold(0, (s, e) => s + e.volume);
  double get totalKubikasi => barang.fold(0, (s, e) => s + e.kubikasi);
  double get totalBerat => beratGlobal ?? barang.fold(0, (s, e) => s + e.totalBerat);

  Map<String, dynamic> toJson() => {
        'id': id,
        'pengirim': pengirim,
        'namaPenerima': namaPenerima,
        'noTelepon': noTelepon,
        'tanggal': tanggal.toIso8601String(),
        'nomorResi': nomorResi,
        'kotaKabupaten': kotaKabupaten,
        'kecamatan': kecamatan,
        if (beratGlobal != null) 'beratGlobal': beratGlobal,
        'barang': barang.map((e) => e.toJson()).toList(),
      };

  factory Pengiriman.fromJson(Map<String, dynamic> json) {
    final raw = json['barang'];
    final list = <BarangItem>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            list.add(BarangItem.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
    }
    return Pengiriman(
      id: json['id'] as String? ?? const Uuid().v4(),
      pengirim: json['pengirim'] as String? ?? '',
      namaPenerima: json['namaPenerima'] as String? ?? '',
      noTelepon: json['noTelepon'] as String? ?? '',
      tanggal: DateTime.tryParse(json['tanggal'] as String? ?? '') ?? DateTime.now(),
      nomorResi: json['nomorResi'] as String? ?? '',
      kotaKabupaten: json['kotaKabupaten'] as String? ?? '',
      kecamatan: json['kecamatan'] as String? ?? '',
      beratGlobal: (json['beratGlobal'] as num?)?.toDouble(),
      barang: list,
    );
  }
}
