Fix build BERAT:
- BarangItem sekarang memiliki field berat (kg/unit), JSON persistence dan copyWith.
- Form memiliki input Berat per unit yang valid dan terinisialisasi saat edit.
- Header/list memiliki kolom BERAT.
- Total row memiliki total berat = jumlah x berat per unit.
- Blok Row input yang sebelumnya malformed sudah diperbaiki.
