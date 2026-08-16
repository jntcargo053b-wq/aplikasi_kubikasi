# Kalkulator Volume Barang

Aplikasi Flutter untuk menghitung volume barang (volumetric weight) sesuai
format tabel di foto: NO, NAMA BARANG, JUMLAH, PANJANG, LEBAR, TINGGI, VOLUME.

## Rumus yang dipakai

VOLUME = (PANJANG × LEBAR × TINGGI ÷ 5000) × JUMLAH

Ini adalah rumus **volumetric weight** standar yang dipakai jasa ekspedisi
(P/L/T dalam cm, hasil dalam kg). Sudah dicek cocok dengan semua 12 baris
di foto (total 866,70).

## Fitur

- Tabel barang dengan header hijau (P/L/T) & merah (VOLUME) seperti di foto
- Tambah barang baru (tombol "+")
- Edit barang: tap baris
- Hapus barang: tekan lama (long press) pada baris → konfirmasi
- Volume dihitung otomatis & live preview saat mengisi form
- Baris TOTAL otomatis (total jumlah barang & total volume)
- Data tersimpan otomatis di device (SharedPreferences), tidak hilang saat app ditutup
- Data contoh dari foto sudah dimuat otomatis saat pertama kali dibuka

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

## Struktur project

```
lib/
  main.dart                     # entry point
  models/barang_item.dart       # model data + rumus volume
  services/storage_service.dart # simpan/muat data lokal
  screens/home_screen.dart      # layar utama (tabel + total)
  widgets/barang_form_sheet.dart# form tambah/edit
```

## Kemungkinan pengembangan lanjutan

- Export ke PDF/Excel (list barang + total)
- Multi-daftar (per pengiriman / per pelanggan)
- Scan barcode/foto barang seperti di TermulScan
- Kalkulasi biaya (volume × tarif per kg)
