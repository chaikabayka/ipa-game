# Экспорт Xcode-проекта для iOS на Windows.
# .ipa на Windows собрать нельзя — нужен macOS/CI (см. docs/IOS.md).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'

if (-not (Test-Path $godot)) { throw "Godot не найден: $godot" }

New-Item -ItemType Directory -Force -Path (Join-Path $root 'build\ios') | Out-Null

& $godot --headless --path $root --export-release 'iOS'
if ($LASTEXITCODE -ne 0) { throw "Экспорт завершился с кодом $LASTEXITCODE" }

Write-Host ''
Write-Host "Готово: $(Join-Path $root 'build\ios\PirateArena.xcodeproj')" -ForegroundColor Green
Write-Host 'Этот проект собирается в .ipa только на macOS или в GitHub Actions.'
