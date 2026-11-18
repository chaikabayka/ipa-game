# Сборка Pirate Arena для iPhone (.ipa)

## Что установлено на этом ПК

| Что | Куда |
|---|---|
| Godot 4.7.2 (движок) | `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe` |
| Консольная версия (для скриптов/CI) | `C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` |
| Шаблоны экспорта (iOS, Android, Windows, Web, macOS, Linux) | `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| Git for Windows 2.56.1 | `C:\Program Files\Git\cmd\git.exe` |
| Сам проект | эта папка |

Ярлык **Godot 4.7.2** лежит на рабочем столе. Открыть проект: запустить Godot → **Import** → выбрать `project.godot`.

## Главное ограничение

`.ipa` — это собранный и подписанный ARM-бинарник для iOS. Собрать его **на Windows нельзя**: нужен Xcode, а Xcode есть только под macOS. Движок тут ни при чём — это правило Apple.

Поэтому схема такая:

```
Windows: правишь игру в Godot → git push на GitHub
GitHub Actions (бесплатный macOS-раннер): Godot экспортирует Xcode-проект → xcodebuild собирает .app → zip в .ipa
Windows: качаешь .ipa из артефактов → Sideloadly подписывает твоим Apple ID и ставит на iPhone
```

Нужны только аккаунт GitHub (бесплатно) и Apple ID (бесплатно, но подпись живёт 7 дней).

## Шаг 1. Проверка на Windows

Экспорт Xcode-проекта работает локально — это уже проверено:

```powershell
cd 'C:\Users\user\Documents\Проект по умолчанию'
& 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --export-release "iOS" "build\ios\PirateArena"
```

Получится:

```
build/ios/PirateArena.xcodeproj        ← проект для Xcode (схема PirateArena)
build/ios/PirateArena/                 ← Info.plist, entitlements, иконки, lproj
build/ios/PirateArena.xcframework      ← движок
build/ios/MoltenVK.xcframework         ← Vulkan→Metal
build/ios/PirateArena.pck              ← ресурсы игры
```

Последняя строка вывода будет: `Сборку .ipa можно выполнить только в macOS. Выполняется выход из проекта Xcode без сборки пакета.` — это ровно то, что нужно: проект собран, дальше его собирает macOS.

В редакторе то же самое: **Project → Export → iOS → Export Project**, путь `build/ios/PirateArena`.

## Шаг 2. Автоматическая сборка .ipa на GitHub

В проекте уже лежит `.github/workflows/ios.yml`. Он:

1. Ставит Godot 4.7.2 + шаблоны экспорта на macOS-раннер.
2. Делает `--import`, чтобы создался кэш ресурсов.
3. Экспортирует Xcode-проект из `project.godot`.
4. Собирает `xcodebuild` **без подписи** (`CODE_SIGNING_ALLOWED=NO`).
5. Пакует `Payload/PirateArena.app` в `PirateArena-unsigned.ipa` и отдаёт артефактом.

Почему без подписи: подпись требует сертификат Apple Developer ($99/год). Неподписанный `.ipa` ставится через Sideloadly/AltStore — они подписывают его твоим бесплатным Apple ID уже на Windows.

```powershell
cd 'C:\Users\user\Documents\Проект по умолчанию'
# репозиторий уже инициализирован и первый коммит сделан
# создай пустой репозиторий на github.com, затем:
git remote add origin https://github.com/ТВОЙ_ЛОГИН/pirate-arena.git
git branch -M main
git push -u origin main
```

Дальше на GitHub: **Actions → iOS build → Run workflow**. Через ~10 минут внизу страницы запуска появится артефакт `PirateArena-ipa` → внутри `PirateArena-unsigned.ipa`.

Публичный репозиторий — macOS-минуты бесплатны без лимита. Приватный — 2000 минут в месяц (одна сборка ≈ 10 минут).

## Шаг 3. Установка на iPhone с Windows

1. Скачай **Sideloadly** (sideloadly.io) или **AltStore** — работают на Windows.
2. Подключи iPhone кабелем, нажми «Доверять».
3. Перетащи `PirateArena-unsigned.ipa` в Sideloadly, введи свой Apple ID (обычный, бесплатный).
4. Sideloadly подпишет и установит игру.
5. На iPhone: **Настройки → Основные → VPN и управление устройством → довериться своему Apple ID**.

Ограничения бесплатного Apple ID: подпись живёт **7 дней**, максимум 3 приложения и 10 App ID в неделю. Платный ($99/год) снимает это и даёт TestFlight.

## Если появится Mac

```bash
# Team ID можно оставить пустым — Xcode подставит из аккаунта
godot --headless --path . --export-release "iOS" build/ios/PirateArena.ipa
open build/ios/PirateArena.xcodeproj   # или собрать в Xcode: Product → Archive → Distribute
```

В экспорт-пресете `iOS` для подписи нужно заменить заглушку `application/app_store_team_id="ABCDE12345"` на свой настоящий Team ID (он же нужен CI, если захочешь подписывать в облаке).

## Что подкрутить под iPhone

`project.godot`:

- `display/window/handheld/orientation="sensor_landscape"` — ландшафт, ок.
- `renderer/rendering_method.mobile="gl_compatibility"` — мобильный рендер, ок.
- `textures/vram_compression/import_etc2_astc=true` — включено, память не раздувается.

`export_presets.cfg` → пресет `iOS`:

- `application/bundle_identifier="com.piratearena.game"` — поменяй на свой, если хочешь.
- `application/app_store_team_id` — заглушка `ABCDE12345`; для подписи нужен реальный.
- `application/min_ios_version="13.0"` — можно поднять, iPhone 6s и новее тянут.

Тач-управление уже есть: `scripts/touch_controls.gd` подключается в `game.gd`, на iPhone появятся стик и кнопка огня. `pointing/emulate_touch_from_mouse=true` — чтобы отлаживать мышью.

## Частые ошибки

| Симптом | Причина |
|---|---|
| `Шаблоны экспорта не найдены ... ios.zip` | шаблоны не той версии; версия папки должна совпадать с версией движка (`4.7.2.stable`) |
| `Не указан App Store Team ID` | пустой `application/app_store_team_id` в пресете |
| `Целевая папка не существует` | путь экспорта — это **папка** (`build/ios/PirateArena`), а не файл `.ipa` |
| `Signing for "PirateArena" requires a development team` | в CI не пробросили `CODE_SIGNING_ALLOWED=NO` |
| `.ipa` не ставится, «Untrusted Developer» | не доверился Apple ID в настройках iPhone |
| Через 7 дней перестало запускаться | истекла бесплатная подпись — переустанови через Sideloadly |
