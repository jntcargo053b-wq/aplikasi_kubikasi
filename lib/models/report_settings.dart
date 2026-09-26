/// Pengaturan header kustom yang ditampilkan pada laporan (PDF & Excel).
///
/// [headerNote] tetap dipertahankan come as field alamat agar kompatibel
/// dengan data/pengaturan versi sebelumnya.
class ReportSettings {
  static const String defaultTitle = 'LAPORAN KUBIKASI PENGIRIMAN';

  final String companyName;
  final String headerNote;
  final String? logoPath;
  final String reportTitle;

  const ReportSettings({
    this.companyName = '',
    this.headerNote = '',
    this.logoPath,
    this.reportTitle = defaultTitle,
  });

  /// Dianggap "kosong" (belum dikustom user) jika perusahaan, alamat, dan
  /// logo belum diisi, dan judul laporan masih judul bawaan atau kosong.
  /// Judul bawaan tidak dihitung sebagai kustomisasi karena field ini selalu
  /// terisi otomatis dengan [defaultTitle] saat belum pernah diubah.
  bool get isEmpty =>
      companyName.trim().isEmpty &&
      headerNote.trim().isEmpty &&
      (logoPath == null || logoPath!.trim().isEmpty) &&
      (reportTitle.trim().isEmpty || reportTitle.trim() == defaultTitle);

  ReportSettings copyWith({
    String? companyName,
    String? headerNote,
    String? logoPath,
    String? reportTitle,
  }) => ReportSettings(
        companyName: companyName ?? this.companyName,
        headerNote: headerNote ?? this.headerNote,
        logoPath: logoPath ?? this.logoPath,
        reportTitle: reportTitle ?? this.reportTitle,
      );

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'headerNote': headerNote,
        'logoPath': logoPath,
        'reportTitle': reportTitle,
      };

  factory ReportSettings.fromJson(Map<String, dynamic> json) => ReportSettings(
        companyName: json['companyName'] as String? ?? '',
        headerNote: json['headerNote'] as String? ?? '',
        logoPath: json['logoPath'] as String?,
        reportTitle: (json['reportTitle'] as String?)?.trim().isNotEmpty == true
            ? json['reportTitle'] as String
            : defaultTitle,
      );
}