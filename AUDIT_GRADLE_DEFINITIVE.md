# Definitive Gradle CI fix

The previous approach edited `distributionUrl` after `flutter create`, but the
runner still reached Flutter with Gradle 8.7.0. The new workflow no longer relies
on that edit alone.

It now:
1. Runs Flutter Android scaffold generation if the repository lacks wrapper files.
2. Installs Gradle **8.14** with `gradle/actions/setup-gradle@v4`.
3. Runs `gradle wrapper --gradle-version 8.14 --distribution-type bin` inside
   `android`, which generates the wrapper jar/scripts/properties from Gradle 8.14.
4. Runs `./gradlew --version` and therefore proves the exact wrapper used by
   the subsequent Flutter build is 8.14.
5. Only then runs `flutter pub get`, analyze, test, and `flutter build apk`.

No `--android-skip-build-dependency-validation` bypass is used.
