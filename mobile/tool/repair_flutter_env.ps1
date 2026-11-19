# Repairs the "dispose isn't defined for TextEditingController" /
# "Undefined class ValueNotifier" analyzer errors. Those errors appear even in
# files that were never changed, which means the Flutter SDK or the analyzer's
# package cache is out of sync — not the app code.
# Run from the mobile folder:  powershell -ExecutionPolicy Bypass -File tool\repair_flutter_env.ps1

$ErrorActionPreference = "Stop"
Write-Host "1/6 Current Flutter:" -ForegroundColor Cyan
flutter --version

Write-Host "2/6 Switching to the stable channel and repairing the SDK..." -ForegroundColor Cyan
flutter channel stable
flutter upgrade --force

Write-Host "3/6 Removing stale build + analyzer caches..." -ForegroundColor Cyan
flutter clean
if (Test-Path ".dart_tool") { Remove-Item -Recurse -Force ".dart_tool" }

Write-Host "4/6 Repairing the pub cache (re-downloads packages)..." -ForegroundColor Cyan
flutter pub cache repair

Write-Host "5/6 Getting packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "6/6 Analyzing..." -ForegroundColor Cyan
flutter analyze --no-fatal-infos
Write-Host "Done. In VS Code run: Ctrl+Shift+P -> 'Dart: Restart Analysis Server'." -ForegroundColor Green
