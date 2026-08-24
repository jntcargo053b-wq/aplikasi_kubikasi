# Aplikasi Kubikasi — Shipment Workflow

## Alur baru
1. Isi **Nama Pengirim** satu kali.
2. Pilih **Tanggal** satu kali.
3. Tambahkan **banyak barang** pada pengiriman yang sama.
4. Isi **Nomor Resi** manual atau gunakan **Scan Barcode Resi**.
5. Tekan **Selesai & Simpan Pengiriman**.

Transaksi tidak disimpan sebagai pengiriman selesai sebelum nomor resi tersedia.

## Kalkulasi dipertahankan
- Volume timbang = `P × L × T / 5000 × jumlah`
- Kubikasi = `P × L × T / 1.000.000 × jumlah`
- Berat total = `berat per unit × jumlah`

## Struktur
- `Pengiriman` = header transaksi: pengirim, tanggal, nomor resi, daftar barang.
- `BarangItem` = detail barang dan kalkulasi.
- `StorageService` = penyimpanan pengiriman.
- `BarcodeScannerScreen` = scan resi.
- `PengirimanFormSheet` = alur transaksi baru.

Data lama `daftar_barang_v1` tidak dipaksakan menjadi transaksi selesai karena data lama tidak memiliki nomor resi.

## Build GitHub Actions
Workflow `.github/workflows/build_apk.yml` menjalankan:
`flutter create --platforms=android --no-pub .` → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --release`.

## Dari HP
1. Extract ZIP.
2. Upload/replace isi repository GitHub.
3. Pastikan `.github/workflows/build_apk.yml` ikut ter-upload.
4. Buka **Actions → Build APK**.
5. Download artifact `app-release-apk`.


## CI / Gradle Wrapper
The repository does not carry Gradle wrapper files. The GitHub Actions workflow
therefore runs `flutter create --platforms=android --no-pub .` before `flutter pub get`.
This supplies missing Gradle wrapper/platform scaffold files while preserving
the existing Dart source and existing Android files.
