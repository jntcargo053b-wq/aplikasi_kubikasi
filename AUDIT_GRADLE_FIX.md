# Gradle CI fix audit

Reported runner error: Flutter sees Gradle 8.7.0 but requires >= 8.14.0.

Correction:
1. Keep Flutter's Android scaffold generation because the repository has no
   committed wrapper.
2. Explicitly rewrite `android/gradle/wrapper/gradle-wrapper.properties` to
   `gradle-8.14-bin.zip` using Python in the GitHub runner.
3. Verify the property contains `gradle-8.14-bin.zip`.
4. Run `./gradlew --version` from `android` before `flutter build apk`.
5. Do not use `--android-skip-build-dependency-validation`.

This makes the build fail early with a clear error if the wrapper is not actually
8.14, instead of reaching Flutter's plugin check with 8.7.
