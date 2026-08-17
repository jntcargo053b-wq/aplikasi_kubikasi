# Aplikasi Kubikasi

Aplikasi Flutter untuk menghitung **VOL 5000** (volumetric weight) dan
**KUBIKASI** (m³) dari data barang, dengan setiap baris (nama, jumlah,
panjang, lebar, tinggi) bisa diinput dan diedit langsung dari tabel.

## Rumus yang dipakai

- **VOL 5000** = (Panjang × Lebar × Tinggi ÷ 5000) × Jumlah — rumus
  volumetric weight standar ekspedisi (P/L/T dalam cm, hasil dalam kg)
- **KUBIKASI (m³)** = (Panjang × Lebar × Tinggi ÷ 1.000.000) × Jumlah

Kedua kolom dihitung otomatis, tidak diinput manual, dan selalu mengikuti
nilai P/L/T/Jumlah terbaru.

## Fitur

- Tabel sesuai kolom: NO, BARANG, JML, P, L, T, VOL 5000, KUBIKASI (M³)
- **Tambah barang** lewat tombol "+"
- **Edit barang**: ketuk baris mana pun → semua field (nama, jumlah,
  panjang, lebar, tinggi) bisa diubah lewat form, VOL 5000 & KUBIKASI
  ter-preview otomatis sebelum disimpan
- **Hapus barang**: tekan lama baris → konfirmasi
- Tabel bisa digeser horizontal supaya kolom KUBIKASI tetap terbaca jelas
  di layar HP kecil
- Baris TOTAL otomatis (jumlah barang, total VOL 5000, total KUBIKASI)
- Data tersimpan otomatis di device (SharedPreferences), tidak hilang saat
  app ditutup
- Data contoh (12 barang) dimuat otomatis saat pertama kali dibuka

## Setup pertama kali (penting)

Project ini baru berisi `lib/` + `pubspec.yaml` — folder platform native
(`android/`, `ios/`, dll) belum ada. **Jangan** membuat file
`android/build.gradle` atau `AndroidManifest.xml` secara manual — kalau
tidak lengkap (bukan hasil `flutter create` asli), Gradle akan menolaknya
dengan error "not a Gradle project". Selalu generate lewat Flutter SDK:

```bash
flutter create -t app .
```

Perintah ini menambahkan folder `android/`, `ios/`, `web/`, dll secara
lengkap (settings.gradle, app/build.gradle, gradle wrapper, MainActivity,
res/, dst.) tanpa menimpa `lib/` maupun `pubspec.yaml` yang sudah ada.
Setelah itu commit foldernya supaya CI tidak perlu generate ulang setiap
build:

```bash
git add android
git commit -m "Add complete Android platform scaffold"
git push
```

## Cara menjalankan

```bash
flutter pub get
flutter run
```

## Cara build APK

```bash
flutter build apk --release
```

APK hasil build ada di `build/app/outputs/flutter-apk/app-release.apk`.

## CI (GitHub Actions)

Workflow ada di `.github/workflows/build_apk.yml`, menggunakan Flutter SDK
asli (channel stable terbaru, via `subosito/flutter-action`) — bukan
`dart pub`/`dart-lang/setup-dart`. Workflow ini juga otomatis menjalankan
`flutter create -t app --platforms=android .` di CI kalau
`android/settings.gradle` belum ada/tidak lengkap, supaya build tetap
jalan walau folder `android/` belum di-commit.

## Struktur project

```
lib/
  main.dart                     # entry point
  models/barang_item.dart       # model data + rumus VOL 5000 & KUBIKASI
  services/storage_service.dart # simpan/muat data lokal
  screens/home_screen.dart      # layar utama (tabel + total)
  widgets/barang_form_sheet.dart# form tambah/edit dengan live preview
```

## Kemungkinan pengembangan lanjutan

- Export ke PDF/Excel (list barang + total)
- Multi-daftar (per pengiriman / per pelanggan)
- Scan barcode/foto barang seperti di TermulScan
- Kalkulasi biaya (VOL 5000 × tarif per kg)
