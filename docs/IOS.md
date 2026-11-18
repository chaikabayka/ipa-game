# Сборка Pirate Arena для iPhone (.ipa)

## Что уже установлено на этом ПК

| Что | Куда |
|---|---|
| Godot 4.7.2 (сам движок) | `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe` |
| Консольная версия (для скриптов/CI) | `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` |
| Шаблоны экспорта (все платформы, включая iOS) | `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| Сам проект | эта папка |

Открыть проект: запустить `Godot_v4.7.2-stable_win64.exe` → **Import** → выбрать `project.godot` в этой папке.

## Главное ограничение

`.ipa` — это подписанный бинарник для ARM-процессора Apple. Его **невозможно собрать на Windows**: нужен Xcode, а Xcode существует только под macOS. Это ограничение Apple, а не движка.

Схема, которая работает без своего Mac:

```
Windows: правишь игру в Godot → git push на GitHub
GitHub Actions (бесплатный macOS-раннер): Godot экспортирует Xcode-проект → xcodebuild собирает .app → zip в .ipa
Windows: скачиваешь .ipa из артефактов → Sideloadly подписывает твоим Apple ID и ставит на iPhone
```

Итого тебе нужны: аккаунт GitHub (бесплатно) и Apple ID (бесплатно, но подпись живёт 7 дней).

## Шаг 1. Локальная проверка (Windows)

Экспорт Xcode-проекта без сборки — работает прямо здесь:

```powershell
& 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release "iOS" "build\ios\PirateArena.xcodeproj"
```

Или в редакторе: **Project → Export → iOS → Export Project**, путь `build/ios/PirateArena.xcodeproj`.
Получится папка с `.xcodeproj`, `Info.plist`, `PirateArena.entitlements` и `PirateArena-iPhone/` — это ровно то, что съест Xcode на Mac или CI.

## Шаг 2. Автоматическая сборка .ipa на GitHub

Файл `.github/workflows/ios.yml` уже лежит в проекте. Что он делает:

1. Ставит Godot 4.7.2 и шаблоны экспорта на macOS-раннер.
2. Экспортирует Xcode-проект из твоего `project.godot`.
3. Собирает `xcodebuild` **без подписи** (`CODE_SIGNING_ALLOWED=NO`).
4. Пакует `Payload/PirateArena.app` в `PirateArena-unsigned.ipa` и отдаёт артефактом.

Почему без подписи: подпись требует сертификат Apple Developer ($99/год). Неподписанный `.ipa` прекрасно ставится через Sideloadly/AltStore — они подписывают его твоим бесплатным Apple ID уже на Windows.

Порядок действий:

```powershell
git init
git add .
git commit -m "Pirate Arena + iOS build"
# создай пустой репозиторий на github.com, потом:
git remote add origin https://github.com/ТВОЙ_ЛОГИН/pirate-arena.git
git branch -M main
git push -u origin main
```

Дальше на GitHub: **Actions → iOS build → Run workflow**. Через ~10 минут внизу страницы запуска будет артефакт `PirateArena-ipa` → внутри `PirateArena-unsigned.ipa`.

Для публичного репозитория macOS-раннеры бесплатны без лимита по минутам; для приватного — 2000 минут в месяц (одна сборка ≈ 10 минут).

## Шаг 3. Установка на iPhone с Windows

1. Скачай **Sideloadly** (sideloadly.io) или **AltStore** — оба работают на Windows.
2. Подключи iPhone кабелем, доверься компьютеру.
3. Перетащи `PirateArena-unsigned.ipa` в Sideloadly, введи свой Apple ID (бесплатный).
4. Sideloadly подпишет и установит приложение.
5. На iPhone: **Настройки → Основные → VPN и управление устройством → доверять своему Apple ID**.

Ограничения бесплатного Apple ID: подпись действует **7 дней** (потом приложение перестаёт запускаться — надо переустановить), максимум 3 приложения и 10 App ID в неделю. Платный аккаунт ($99/год) снимает это и даёт TestFlight/App Store.

## Если появится Mac

```bash
# один раз
cp -R "~/Library/Application Support/Godot/export_templates" ~/Library/Application\ Support/Godot/   # шаблоны
# экспорт сразу в подписанный .ipa
godot --headless --path . --export-release "iOS" build/ios/PirateArena.ipa
```

В экспорт-пресете `iOS` тогда достаточно указать `Team ID` и `Export Method = Development / Ad-Hoc / App Store`.

## Что подкрутить под iPhone

`project.godot`:

- `display/window/handheld/orientation="sensor_landscape"` — уже ландшафт, ок.
- `renderer/rendering_method.mobile="gl_compatibility"` — уже правильный рендер для мобилок (Metal-совместимый путь).
- `textures/vram_compression/import_etc2_astc=true` — уже включено, текстуры не будут раздувать память.

Экспорт-пресет `iOS` -> `application/bundle_identifier` — сейчас `com.piratearena.game`, поменяй, если хочешь свой (Apple не любит чужие `com.*`).

Тач-управление уже есть: `scripts/touch_controls.gd` подключается в `game.gd`. На iPhone стик и кнопка стрельбы появятся сами, `pointing/emulate_touch_from_mouse=true` для отладки мышью уже стоит.

## Частые ошибки

| Симптом | Причина |
|---|---|
| `No export template found at .../ios.zip` | шаблоны не установлены или версия движка ≠ версии шаблонов |
| `xcodebuild: error: Signing for "PirateArena" requires a development team` | в CI не пробросили `CODE_SIGNING_ALLOWED=NO` |
| `.ipa` не ставится, «Untrusted Developer» | не доверился Apple ID в настройках iPhone |
| Приложение не запускается через 7 дней | истекла бесплатная подпись, переустанови |
