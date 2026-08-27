import 'package:uuid/uuid.dart';

const double kFaktorVolumetrik = 5000;
const double kFaktorKubikasi = 1000000;

class BarangItem {
  String id;
  String nama;
  int jumlah;
  double panjang;
  double lebar;
  double tinggi;
  double berat;
  String? photoPath;

  BarangItem({
    required this.id,
    required this.nama,
    required this.jumlah,
    required this.panjang,
    required this.lebar,
    required this.tinggi,
    this.berat = 0,
    this.photoPath,
  });

  double get volume =>
      (panjang * lebar * tinggi / kFaktorVolumetrik) * jumlah;

  double get kubikasi =>
      (panjang * lebar * tinggi / kFaktorKubikasi) * jumlah;

  double get totalBerat => berat * jumlah;

  /// Validates values before persistence or report generation.
  String? validate() {
    if (nama.trim().isEmpty) return 'Nama barang wajib diisi.';
    if (jumlah <= 0) return 'Jumlah barang harus lebih dari 0.';
    if (!panjang.isFinite || panjang <= 0) return 'Panjang harus lebih dari 0.';
    if (!lebar.isFinite || lebar <= 0) return 'Lebar harus lebih dari 0.';
    if (!tinggi.isFinite || tinggi <= 0) return 'Tinggi harus lebih dari 0.';
    if (!berat.isFinite || berat < 0) return 'Berat tidak valid.';
    if (!volume.isFinite || !kubikasi.isFinite || !totalBerat.isFinite) {
      return 'Hasil perhitungan barang tidak valid.';
    }
    return null;
  }

  BarangItem copyWith({
    String? nama,
    int? jumlah,
    double? panjang,
    double? lebar,
    double? tinggi,
    double? berat,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return BarangItem(
      id: id,
      nama: nama ?? this.nama,
      jumlah: jumlah ?? this.jumlah,
      panjang: panjang ?? this.panjang,
      lebar: lebar ?? this.lebar,
      tinggi: tinggi ?? this.tinggi,
      berat: berat ?? this.berat,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'jumlah': jumlah,
        'panjang': panjang,
        'lebar': lebar,
        'tinggi': tinggi,
        'berat': berat,
        if (photoPath != null) 'photoPath': photoPath,
      };

  factory BarangItem.fromJson(Map<String, dynamic> json) => BarangItem(
        id: json['id'] as String? ?? const Uuid().v4(),
        nama: json['nama'] as String? ?? '',
        jumlah: (json['jumlah'] as num?)?.toInt() ?? 1,
        panjang: (json['panjang'] as num?)?.toDouble() ?? 0,
        lebar: (json['lebar'] as num?)?.toDouble() ?? 0,
        tinggi: (json['tinggi'] as num?)?.toDouble() ?? 0,
        berat: (json['berat'] as num?)?.toDouble() ?? 0,
        photoPath: json['photoPath'] as String?,
      );
}
