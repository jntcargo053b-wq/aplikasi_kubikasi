# Final static audit

## Required files
- pubspec.yaml: OK
- lib/main.dart: OK
- lib/models/barang_item.dart: OK
- lib/models/pengiriman.dart: OK
- lib/screens/home_screen.dart: OK
- lib/screens/pengiriman_form_sheet.dart: OK
- lib/screens/barcode_scanner_screen.dart: OK
- lib/widgets/barang_form_sheet.dart: OK
- lib/services/storage_service.dart: OK
- AndroidManifest camera permission: OK
- GitHub Actions workflow: OK

## Live preview
`Listenable.merge([_jumlah, _p, _l, _t])` feeds an `AnimatedBuilder`.
Therefore typing any dimension or quantity updates Volume Timbang and Kubikasi
without rebuilding the whole form.

## Transaction flow
Pengirim + tanggal are shipment-level fields. Multiple BarangItem records can
be added. A shipment cannot be returned/saved until pengirim, at least one
barang, and nomor resi are present. Resi may be typed or scanned.

## Build
The repository does not contain Gradle wrapper files. The workflow deliberately
runs `flutter create --platforms=android --no-pub .` before the build to generate
missing wrapper/scaffold files. This is necessary for this repository.

## Limit
This is a static/package audit; a real GitHub Actions runner has not been
executed from this chat environment. The next definitive verification is the
Actions build after upload.
