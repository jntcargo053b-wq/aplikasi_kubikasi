# Audit & Implementasi Share Report

## Format
- PDF per resi: rincian kubikasi + foto tertanam.
- PDF rekap/filter: seluruh pengiriman yang diterima dari HomeScreen, dengan foto tertanam.
- Excel per resi/rekap: data kubikasi; foto dikirim sebagai attachment JPG terkompresi.

## Urutan laporan
ExportService **tidak melakukan sort ulang**. Urutan `List<Pengiriman>` dipertahankan persis seperti yang dikirim HomeScreen, sehingga mengikuti filter dan mode sort yang sedang terlihat di layar (Terbaru, Terlama, atau Pengirim A-Z).

## Optimasi foto
- Foto asli tidak pernah diubah.
- Salinan report maksimal 1400 px pada sisi terpanjang.
- JPEG quality 82.
- Decode/resize/encode menggunakan `compute()` agar tidak memblokir UI isolate.
- PDF dan attachment Excel sama-sama menggunakan salinan foto terkompresi.

## Batas foto rekap
- Maksimum 60 foto per laporan gabungan.
- Budget dialokasikan round-robin antar-resi agar tidak greedy berdasarkan urutan tanggal.
- Jika total foto melebihi batas, setiap resi mendapat kesempatan berdasarkan jumlah foto yang tersedia; catatan laporan menyebutkan bahwa sebagian foto dapat tidak disertakan.

## Catatan Excel
Foto tidak di-embed ke dalam XLSX. File Excel dibagikan bersama attachment JPG terkompresi agar ukuran share intent lebih aman dan foto tetap mudah digunakan oleh aplikasi tujuan share.
