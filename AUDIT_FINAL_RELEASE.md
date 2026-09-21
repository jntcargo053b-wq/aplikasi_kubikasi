# Final release static audit

- Keyboard-aware bottom sheets: PASS
- Live volume/kubikasi preview: PASS
- FittedBox for large preview numbers: PASS
- ExpansionTile chevron + menu: PASS
- Long text ellipsis: PASS
- Sender/date filter: PASS
- Sender filter invalid-value protection: PASS
- Search resi/sender/item, case-insensitive: PASS
- Search + filters combined: PASS
- Empty/reset UX: PASS
- Shipment/resi/scanner flow: PASS
- Missing Gradle wrapper is generated in CI: PASS
- **Gradle wrapper is explicitly pinned to 8.14**: PASS
- Java 17 and Actions v4 steps: PASS
- Analyze/test/build steps: PASS

The reported CI failure was:
Flutter requires Gradle >= 8.14 while the generated wrapper was 8.7.
The workflow now changes `distributionUrl` to Gradle 8.14 immediately after
wrapper generation and before `flutter pub get`/build.

Static audit only; a real GitHub Actions run is still the final verification.


## Post-review hardening — 2026-09-21

Implemented:
- Combined-report photo allocation uses round-robin distribution with the global 60-photo limit.
- Report photo decode/resize/JPEG encoding runs in a background isolate via Isolate.run().
- Manual backup records SHA-256 checksums for embedded photos and report logo; restore validates them when present and remains compatible with older version-1 backups.
- GitHub Actions provisions Gradle with gradle/actions/setup-gradle@v4 and generates a pinned Gradle 8.14 wrapper.
- Added a regression test for round-robin report photo allocation.

Release verification remains a real GitHub Actions run: flutter pub get, flutter analyze, flutter test, and flutter build apk --release.
