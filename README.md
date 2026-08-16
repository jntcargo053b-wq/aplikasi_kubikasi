# Aplikasi Kubikasi

Aplikasi Flutter untuk menghitung Volume (VOL 5000) dan Kubikasi (m³) dari data barang, 
berdasarkan rumus:

- **VOL 5000** = (Panjang × Lebar × Tinggi) ÷ 5000
- **KUBIKASI** = (Panjang × Lebar × Tinggi) ÷ 1.000.000

Data contoh yang ditampilkan sesuai dengan tabel dari file Excel (total VOL 5000 = 778,06 dan total KUBIKASI = 3,89).

## Fitur

- Menampilkan daftar barang dengan dimensi (P, L, T)
- Otomatis menghitung VOL 5000 dan KUBIKASI per barang
- Menampilkan total kedua kolom di bagian bawah tabel
- Data tersimpan otomatis di device (SharedPreferences), tidak hilang saat app ditutup
- Data contoh dari foto sudah dimuat otomatis saat pertama kali dibuka

## Setup pertama kali (penting)

Project ini baru berisi `lib/` + `pubspec.yaml` — folder platform native
(`android/`, `ios/`, dll) belum ada. Sebelum build/jalan pertama kali,
jalankan di root project:

```bash
flutter create .
