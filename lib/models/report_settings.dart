/// Pengaturan header kustom yang ditampilkan pada laporan (PDF & Excel)
/// saat share report. Bersifat opsional — jika kosong, laporan memakai
/// judul default seperti sebelumnya.
class ReportSettings {
  /// Nama usaha/ekspedisi, ditampilkan sebagai judul utama pengganti
  /// judul default ("Laporan Kubikasi Pengiriman" / "Rekap ...").
  final String companyName;

  /// Catatan tambahan di bawah judul, mis. alamat, nomor telepon,
  /// atau slogan singkat.
  final String headerNote;

  /// Absolute path of the app-owned company logo used in reports.
  /// The file is copied into the app documents directory before this value
  /// is persisted; the original gallery file is never owned by the app.
  final String? logoPath;

  const ReportSettings({
    this.companyName = '',
    this.headerNote = '',
    this.logoPath,
  });

  bool get isEmpty =>
      companyName.trim().isEmpty &&
      headerNote.trim().isEmpty &&
      (logoPath == null || logoPath!.trim().isEmpty);

  ReportSettings copyWith({
    String? companyName,
    String? headerNote,
    String? logoPath,
  }) => ReportSettings(
        companyName: companyName ?? this.companyName,
        headerNote: headerNote ?? this.headerNote,
        logoPath: logoPath ?? this.logoPath,
      );

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'headerNote': headerNote,
        'logoPath': logoPath,
      };

  factory ReportSettings.fromJson(Map<String, dynamic> json) => ReportSettings(
        companyName: json['companyName'] as String? ?? '',
        headerNote: json['headerNote'] as String? ?? '',
        logoPath: json['logoPath'] as String?,
      );
}
