#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo "Flutter doit être présent dans PATH."; exit 1; }
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
flutter create --no-pub --platforms=android --org com.tdg --project-name diraasa "$tmp_dir/bootstrap"
cp "$tmp_dir/bootstrap/android/gradlew" android/gradlew
cp "$tmp_dir/bootstrap/android/gradlew.bat" android/gradlew.bat
cp "$tmp_dir/bootstrap/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/
cp "$tmp_dir/bootstrap/android/local.properties" android/local.properties
chmod +x android/gradlew
flutter pub get
flutter analyze
flutter test
echo "Sources préparées et contrôles Flutter réussis."
echo "Pour compiler sans appareil : flutter build apk --debug"
echo "Pour exécuter : connectez un téléphone Android (débogage USB) ou démarrez un émulateur."
flutter devices
echo "Puis : flutter run -d <identifiant_android>"
