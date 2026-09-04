import 'package:flutter_wilayah_indonesia/services/wilayah_service.dart';

class IndonesiaRegion {
  final String code;
  final String name;
  final String type;

  const IndonesiaRegion({
    required this.code,
    required this.name,
    required this.type,
  });
}

/// Offline region data for the shipment form.
/// The package bundles the Indonesian administrative datasets, so no
/// HTTP/API request is made while the application is running.
class IndonesiaRegionService {
  static Future<List<IndonesiaRegion>> loadAllKabupatenKota() async {
    final provinces = await WilayahService.getProvinsi();
    final results = <IndonesiaRegion>[];

    final perProvince = await Future.wait(
      provinces.map((province) async {
        final cities = await WilayahService.getKabupatenByProvinsi(province.id);
        return cities
            .map(
              (item) => IndonesiaRegion(
                code: item.id,
                name: item.nama.trim(),
                type: _normalizeType(item.nama),
              ),
            )
            .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
            .toList();
      }),
    );

    for (final list in perProvince) {
      results.addAll(list);
    }

    final unique = <String, IndonesiaRegion>{};
    for (final item in results) {
      unique[item.code] = item;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  static Future<List<IndonesiaRegion>> loadKecamatan(
    String kabupatenCode,
  ) async {
    final code = kabupatenCode.trim();
    if (code.isEmpty) return const [];

    final districts = await WilayahService.getKecamatanByKabupaten(code);
    final unique = <String, IndonesiaRegion>{};
    for (final item in districts) {
      final region = IndonesiaRegion(
        code: item.id,
        name: item.nama.trim(),
        type: 'Kecamatan',
      );
      if (region.code.isNotEmpty && region.name.isNotEmpty) {
        unique[region.code] = region;
      }
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  static String _normalizeType(String name) {
    final upper = name.trim().toUpperCase();
    if (upper.startsWith('KOTA ')) return 'Kota';
    return 'Kabupaten';
  }
}
