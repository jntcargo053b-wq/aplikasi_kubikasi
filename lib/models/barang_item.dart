/// Faktor pembagi volumetrik standar logistik (P x L x T (cm) / 5000).
/// Ini adalah rumus "volume weight" yang umum dipakai jasa ekspedisi.
const double kFaktorVolumetrik = 5000;

/// Faktor konversi cm³ ke m³ (1.000.000 cm³ = 1 m³).
const double kFaktorKubikasi = 1000000;

class BarangItem {
  String id;
  String nama;
  int jumlah;
  double panjang; // cm
  double lebar; // cm
  double tinggi; // cm
  double berat; // kg per unit
  String? photoPath;
  String pengirim;
  DateTime tanggal;

  BarangItem({
    required this.id,
    required this.nama,
    required this.jumlah,
    required this.panjang,
    required this.lebar,
    required this.tinggi,
    this.berat = 0,
    this.photoPath,
    this.pengirim = '',
    DateTime? tanggal,
  }) : tanggal = tanggal ?? DateTime.now();

  /// Volume per baris = (P x L x T / 5000) x Jumlah
  double get volume =>
      (panjang * lebar * tinggi / kFaktorVolumetrik) * jumlah;

  /// Kubikasi per baris (m³) = (P x L x T / 1.000.000) x Jumlah
  double get kubikasi =>
      (panjang * lebar * tinggi / kFaktorKubikasi) * jumlah;

  /// [clearPhoto] = true akan mengosongkan [photoPath] walau [photoPath]
  /// yang di-pass adalah null (parameter null biasa berarti "tidak diubah").
  BarangItem copyWith({
    String? nama,
    int? jumlah,
    double? panjang,
    double? lebar,
    double? tinggi,
    double? berat,
    String? photoPath,
    bool clearPhoto = false,
    String? pengirim,
    DateTime? tanggal,
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
      pengirim: pengirim ?? this.pengirim,
      tanggal: tanggal ?? this.tanggal,
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
        'pengirim': pengirim,
        'tanggal': tanggal.toIso8601String(),
      };

  factory BarangItem.fromJson(Map<String, dynamic> json) => BarangItem(
        id: json['id'] as String,
        nama: json['nama'] as String,
        jumlah: (json['jumlah'] as num).toInt(),
        panjang: (json['panjang'] as num).toDouble(),
        lebar: (json['lebar'] as num).toDouble(),
        tinggi: (json['tinggi'] as num).toDouble(),
        berat: (json['berat'] as num?)?.toDouble() ?? 0,
        photoPath: json['photoPath'] as String?,
        pengirim: json['pengirim'] as String? ?? '',
        tanggal: json['tanggal'] != null
            ? DateTime.tryParse(json['tanggal'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
