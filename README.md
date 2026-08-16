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
