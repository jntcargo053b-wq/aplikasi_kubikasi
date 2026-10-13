# Nextcube — Aplikasi Kubikasi Pengiriman

Aplikasi Android Flutter untuk mencatat pengiriman dengan beberapa barang per resi.

## Alur pengiriman
1. Isi nama pengirim dan tanggal.
2. Tambahkan satu atau beberapa barang.
3. Isi nomor resi secara manual atau melalui pemindaian barcode.
4. Simpan setelah data wajib lengkap.

## Perhitungan
- Volume timbang: `panjang × lebar × tinggi / 5000 × jumlah`
- Kubikasi: `panjang × lebar × tinggi / 1.000.000 × jumlah`
- Berat total: `berat per unit × jumlah`

## Dependensi

File `pubspec.lock` disimpan di repository untuk mengunci versi dependensi yang ter-resolve dan membuat build CI lebih konsisten. Perbarui file ini dengan `flutter pub get` saat dependensi diubah.

## Build melalui GitHub Actions
Workflow [Build APK](.github/workflows/build_apk.yml) menggunakan Flutter stable yang dipatok versinya, menyiapkan Gradle wrapper 8.14 di runner, lalu menjalankan `flutter pub get`, `flutter analyze`, `flutter test`, dan `flutter build apk --release`.

Workflow tidak menjalankan `flutter create`; berkas platform Android yang ada di repository dipertahankan. APK release diunggah sebagai artifact bernama `app-release-apk`.

## Dokumentasi
- [Perilaku berbagi laporan](docs/SHARE_REPORT.md)

Catatan audit lama yang tidak lagi dipelihara telah dihapus dari root. Untuk kondisi terbaru, utamakan source code dan hasil GitHub Actions.
