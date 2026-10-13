# Perilaku berbagi laporan

Dokumen ini mencerminkan implementasi saat ini pada `lib/services/export_service.dart`.

## Format
- PDF per resi: laporan kubikasi dengan foto yang tersedia tertanam di PDF.
- PDF rekap: laporan untuk daftar pengiriman dari HomeScreen, dengan foto yang tersedia tertanam sesuai batas laporan.
- Excel per resi dan rekap: data kubikasi dalam berkas `.xlsx`. Foto tidak ditanamkan ke workbook.

## Urutan laporan
ExportService mempertahankan urutan daftar pengiriman yang diterimanya; filter dan mode pengurutan berasal dari layar pemanggil.

## Optimasi foto pada PDF
Foto asli tidak diubah. Salinan untuk laporan diperkecil dan dikompresi; pemrosesan foto laporan dijalankan terpisah dari UI isolate.

## Berbagi Excel
Fungsi `shareExcel` dan `shareCombinedExcel` saat ini hanya mengirim berkas Excel melalui share intent. **Lampiran JPG tidak ikut dikirim bersama Excel** pada implementasi sekarang. Jika foto dibutuhkan, gunakan laporan PDF yang menyematkan foto.

Dokumentasi ini sengaja menyebut perilaku aktual; jangan menganggap lampiran JPG tersedia sampai implementasi dan pengujiannya ditambahkan.
