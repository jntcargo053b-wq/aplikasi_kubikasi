/// Pengaturan header kustom yang ditampilkan pada laporan (PDF & Excel).
///
/// [headerNote] tetap dipertahankan sebagai field alamat agar kompatibel
/// dengan data/pengaturan versi sebelumnya.
class ReportSettings {
  final String companyName;
  final String headerNote;
  final String? logoPath;
  final String reportTitle;

  const ReportSettings({
    this.companyName = '',
    this.headerNote = '',
    this.logoPath,
    this.reportTitle = 'LAPORAN KUBIKASI PENGIRIMAN',
  });

  bool get isEmpty =>
      companyName.trim().isEmpty &&
      headerNote.trim().isEmpty &&
      (logoPath == null || logoPath!.trim().isEmpty) &&
      reportTitle.trim().isEmpty;

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
            : 'LAPORAN KUBIKASI PENGIRIMAN',
      );
}
