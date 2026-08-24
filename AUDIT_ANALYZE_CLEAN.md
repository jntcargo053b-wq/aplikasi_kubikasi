# Analyze-clean audit

Fixed the three reported analyzer issues:
1. Removed unused `../models/barang_item.dart` import from `home_screen.dart`.
2. `sheetHeight` is now actually used by the shipment form sheet.
3. `sheetHeight` is now actually used by the barang form sheet.

Retained:
- live P/L/T/Jumlah preview
- keyboard-aware sheet sizing
- Gradle 8.14 CI verification
- shipment/resi/scanner workflow
- filter/search fixes
