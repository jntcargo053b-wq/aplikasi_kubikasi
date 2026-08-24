# Android Gradle audit

The runner reported:
- Gradle 8.14.0: supported but nearing Flutter's future minimum 9.1.0.
- Android Gradle Plugin 8.6.1: TOO OLD for the current Flutter stable; minimum
  reported by the runner is 8.11.1.
- Both `build.gradle` and `build.gradle.kts` existed, so the Kotlin DSL file was
  ignored.

Fixes:
1. Removed duplicate Kotlin DSL Android files so only the active Groovy build
   files remain.
2. Upgraded Android Gradle Plugin from 8.6.1 to 8.11.1 in the active Gradle
   configuration.
3. Kept Gradle 8.14 for compatibility with the current Flutter minimum.
4. Added CI verification output for the AGP declarations.
5. Did not use `--android-skip-build-dependency-validation`.

The 9.1.0 message is currently a warning, not the reported build blocker.
