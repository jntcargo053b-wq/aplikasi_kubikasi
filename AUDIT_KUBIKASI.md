# Audit khusus

1. Preview volume/kubikasi live memakai `Listenable.merge` pada controller
   jumlah, panjang, lebar, dan tinggi; hanya area preview yang rebuild.
2. Nama dan berat tidak perlu listener untuk preview tersebut.
3. Pengirim dan tanggal berada pada satu `Pengiriman`.
4. Banyak barang dapat ditambahkan sebelum transaksi selesai.
5. Resi wajib, manual atau barcode.
6. Storage hanya menerima transaksi final yang memiliki pengirim, resi,
   dan minimal satu barang.
7. Workflow tidak menjalankan `flutter create`, sehingga project Android
   tidak ditimpa oleh scaffold baru.
8. Rumus kubikasi/volume tetap dipertahankan.
