import 'package:uuid/uuid.dart';
import 'barang_item.dart';

class Pengiriman {
  final String id;
  final String pengirim;
  final DateTime tanggal;
  final String nomorResi;
  final String kotaKabupaten;
  final String kecamatan;
  final List<BarangItem> barang;

  Pengiriman({
    required this.id,
    required this.pengirim,
    required this.tanggal,
    required this.nomorResi,
    this.kotaKabupaten = '',
    this.kecamatan = '',
    required this.barang,
  });

  int get totalJumlah => barang.fold(0, (s, e) => s + e.jumlah);
  double get totalVolume => barang.fold(0, (s, e) => s + e.volume);
  double get totalKubikasi => barang.fold(0, (s, e) => s + e.kubikasi);
  double get totalBerat => barang.fold(0, (s, e) => s + e.totalBerat);

  Map<String, dynamic> toJson() => {
        'id': id,
        'pengirim': pengirim,
        'tanggal': tanggal.toIso8601String(),
        'nomorResi': nomorResi,
        'kotaKabupaten': kotaKabupaten,
        'kecamatan': kecamatan,
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
      tanggal: DateTime.tryParse(json['tanggal'] as String? ?? '') ?? DateTime.now(),
      nomorResi: json['nomorResi'] as String? ?? '',
      kotaKabupaten: json['kotaKabupaten'] as String? ?? '',
      kecamatan: json['kecamatan'] as String? ?? '',
      barang: list,
    );
  }
}
