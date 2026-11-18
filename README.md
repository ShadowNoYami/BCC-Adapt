# BCC Adapt — Adaptive Mobile Banking MVP

**Case:** BCC Bank (Банк ЦентрКредит) • **ITU HACKATHON-2026**  
**Platform:** Flutter (Android & iOS) • **Languages:** Русский / Қазақша (`RU` / `KK`)

---

## О проекте (RU)

**BCC Adapt** — интеллектуальная система детерминированной адаптации мобильного банковского интерфейса для пользователей с нарушениями зрения, мелкой моторики (включая тремор рук), когнитивной нагрузкой и возрастных клиентов.

Вместо «недоступного входа в настройки доступности» приложение с первых секунд само подстраивается под пользователя без LLM и облачной телеметрии: чувствительный профиль доступности хранится локально и зашифрованно в `flutter_secure_storage`.

### Ключевые возможности
1. **Доступный вход и Zero-Touch Audio Prompt (`WelcomeScreen`):**
   - Крупная контрастная кнопка-карточка **«Настроить удобный интерфейс и голос»** в верхней половине экрана и крупный переключатель `РУС / ҚАЗ`.
   - Если пользователь ничего не нажимает `4.5` секунды (и системный TalkBack не активен), приложение автоматически озвучивает голосовую подсказку.
2. **Интерактивная калибровка из 3 микро-тестов (`CalibrationScreen`):**
   - **Зрение и контраст:** 3 наглядные карточки баланса `50 000 ₸` (1.0×, 1.5×, 1.85×/2.0×) с переключением светлого/тёмного режима **WCAG 2.1 AAA (контраст ≥ 7:1)** и мгновенной перестройкой интерфейса в реальном времени.
   - **Моторика:** проверка точности нажатия по кнопке-мишени + честный выбор; при промахе автоматически активируется `tremorProtection`.
   - **Когнитивный режим и голос:** выбор «Только главное» vs «Все функции банка» и безопасный запрос разрешения микрофона.
3. **Детерминированный `AccessibilityProfileEngine`:**
   - Читает системные флаги устройства (`PlatformDispatcher`: масштаб текста, `accessibleNavigation`, `boldText`, `highContrast`).
   - Вычисляет единые токены интерфейса (`AdaptiveTokens` + `AppThemeBuilder`), гарантируя отсутствие `RenderFlex overflow` вплоть до **200% масштаба текста**.
4. **Adaptive Layout Reflow (`HomeScreen`):**
   - При `textScaleFactor < 1.4` и `fullBanking` — многоколоночная сетка действий и аналитика.
   - При `textScaleFactor >= 1.4` или упрощённом режиме — автоматическая перестройка в одноколоночный список крупных кнопок (`64–72 dp`: *Переводы*, *Платежи*, *История операций*) с полным скрытием баннеров и 2-строчным выводом сумм без `TextOverflow.ellipsis`.
5. **Безопасные голосовые переводы и антифрод (`TransferScreen`):**
   - **Safe Voice Intent Filler:** Push-to-Talk STT (`ru-RU` / `kk-KZ`, тайм-аут тишины `3.5 сек`) + `VoiceTransferParser` (числительные прописью на RU и KK) заполняют только черновик и **никогда** не отправляют деньги без подтверждения.
   - **TalkBack Guard:** встроенный `flutter_tts` автоматически блокируется при активном системном экранном дикторе во избежание двойной озвучки.
   - **Защита от лишнего нуля:** сумма мгновенно расшифровывается прописью (*«Сто тысяч тенге»* / *«Жүз мың теңге»*).
   - **Антифрод-пауза 5 сек + Защита от тремора:** при переводе незнакомому получателю включается предупреждение и 5-секундная блокировка подтверждения; при `tremorProtection` подтверждение требует удержания кнопки **1.5 сек** (`72 dp`, зазор ≥ `16 dp`, debounce `600 мс`).
6. **Панель настроек (`AccessibilitySettingsScreen`) и Адаптивная регистрация (`AdaptiveRegistrationScreen`):**
   - Живое превью изменений, ползунки масштаба `100%–200%`, быстрый сброс и повтор калибровки в 1 клик.

---

## About the Project (EN)

**BCC Adapt** is a deterministic adaptive mobile banking MVP built for **BCC Bank (Bank CenterCredit)** at **ITU HACKATHON-2026**. It dynamically reshapes typography, contrast (WCAG 2.1 AAA), touch target geometry, cognitive complexity, and voice assistance to make everyday banking safe and effortless for elderly users and users with visual, motor, or cognitive impairments.

### Core Highlights
- **3-Step Interactive Calibration:** Replaces complex preference forms with visual balance cards, a motor target pad, and plain-language mode selection.
- **Zero-Touch Audio Prompt & TalkBack Guard:** Automatically speaks onboarding guidance after `4.5 s` of inactivity while strictly suppressing built-in TTS whenever system TalkBack / VoiceOver is active.
- **Deterministic Accessibility Profile Engine:** Syncs OS flags via `PlatformDispatcher`, persists sensitive markers exclusively in `flutter_secure_storage`, and renders **0 overflows at up to 200% text scale**.
- **Adaptive Layout Reflow:** Switches between a rich multi-column dashboard and a focused single-column essential flow (`Переводы`, `Платежи`, `История операций`).
- **Safe Voice Intent Filler & Anti-Fraud Protection:** Push-to-Talk RU/KK parser (`VoiceTransferParser`), live amount-in-words readout, 5-second cooling-off timer for unfamiliar recipients, and `72 dp` `1.5 s` hold-to-confirm buttons for tremor protection.

---

## Технологический стек / Tech Stack
- **Framework:** Flutter `3.47+` (Dart `3.13+`), Feature-First Clean Architecture
- **State Management:** `flutter_riverpod` (`Notifier` / `AsyncNotifier`)
- **Secure Storage:** `flutter_secure_storage` (Android Keystore / iOS Keychain)
- **Voice & Permissions:** `flutter_tts`, `speech_to_text`, `permission_handler`
- **Localization & Typography:** `flutter_localizations`, `intl` (RU / KK, `₸`), `google_fonts` (`Inter` with full Cyrillic & Kazakh glyphs `Ә, І, Ң, Ғ, Ү, Ұ, Қ, Ө, Һ`)
- **Accessibility:** Native Flutter `Semantics`, `ExcludeSemantics`, `liveRegion`, WCAG 2.1 AAA palettes (`>= 7:1` contrast verified by unit tests)

---

## Запуск и тестирование / Getting Started

```bash
# 1. Установка зависимостей / Install dependencies
flutter pub get

# 2. Статический анализ и автотесты / Static analysis & automated tests (19/19 passed)
dart analyze lib test
flutter test

# 3. Запуск приложения / Run on device or emulator
flutter run
```

> **Automated Verification:** **19 / 19 tests passed** (`core_engine_test.dart`, `onboarding_ui_test.dart`, `banking_screens_test.dart`), covering WCAG 2.1 AAA contrast ratios, TalkBack Guard, RU/KK voice intent parsing, 200% scale overflow checks on `360×640`, anti-fraud 5 s countdown, and `1.5 s` hold-to-confirm.
