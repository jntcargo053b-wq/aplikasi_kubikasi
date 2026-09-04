import 'dart:convert';
import 'package:http/http.dart' as http;

class IndonesiaRegion {
  final String code;
  final String name;
  final String type;

  const IndonesiaRegion({required this.code, required this.name, required this.type});

  factory IndonesiaRegion.fromJson(Map<String, dynamic> json) => IndonesiaRegion(
        code: '${json['kode'] ?? ''}',
        name: '${json['nama'] ?? ''}'.trim(),
        type: '${json['tipe'] ?? ''}'.trim(),
      );
}

/// Data kabupaten/kota dan kecamatan untuk form pengiriman.
/// Kabupaten/kota dimuat dari seluruh 38 provinsi, sedangkan kecamatan
/// hanya dimuat setelah kabupaten/kota dipilih agar form tetap ringan.
class IndonesiaRegionService {
  static const _baseUrl = 'https://api-wilayah-indo.pages.dev/api';

  static Future<List<IndonesiaRegion>> loadAllKabupatenKota() async {
    final provinces = await _getList('$_baseUrl/provinsi');
    final provinceCodes = provinces.map((e) => e.code).where((e) => e.isNotEmpty).toList();
    final results = <IndonesiaRegion>[];

    final responses = await Future.wait(
      provinceCodes.map((code) => _getList('$_baseUrl/kabupaten?provinsi=$code')),
    );
    for (final list in responses) {
      results.addAll(list);
    }

    final unique = <String, IndonesiaRegion>{};
    for (final item in results) {
      if (item.code.isNotEmpty && item.name.isNotEmpty) unique[item.code] = item;
    }
    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  static Future<List<IndonesiaRegion>> loadKecamatan(String kabupatenCode) async {
    if (kabupatenCode.trim().isEmpty) return const [];
    final list = await _getList('$_baseUrl/kecamatan?kabupaten=${Uri.encodeQueryComponent(kabupatenCode)}');
    final unique = <String, IndonesiaRegion>{};
    for (final item in list) {
      if (item.code.isNotEmpty && item.name.isNotEmpty) unique[item.code] = item;
    }
    final sorted = unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  static Future<List<IndonesiaRegion>> _getList(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Server wilayah mengembalikan HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw Exception('Format data wilayah tidak valid.');
    return decoded
        .whereType<Map>()
        .map((e) => IndonesiaRegion.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.code.isNotEmpty && e.name.isNotEmpty)
        .toList();
  }
}
