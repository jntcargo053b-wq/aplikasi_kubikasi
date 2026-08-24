# Final Gradle CI audit

The workflow now uses the exact wrapper-properties rewrite strategy:

1. `flutter create --platforms=android --no-pub .` creates missing wrapper files.
2. Python rewrites any Gradle `distributionUrl` version to
   `gradle-8.14-bin.zip`.
3. The resulting properties file is printed.
4. `grep` fails the job if Gradle 8.14 is not present.
5. `./gradlew --version` runs before Flutter build.
6. Only after verification does `flutter build apk --release` run.

No dependency-validation bypass is used.
