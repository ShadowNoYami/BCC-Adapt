import 'dart:convert';

import 'package:bcc_adapt/core/accessibility/application/accessibility_profile_notifier.dart';
import 'package:bcc_adapt/core/accessibility/data/accessibility_profile_repository.dart';
import 'package:bcc_adapt/core/accessibility/data/system_accessibility_source.dart';
import 'package:bcc_adapt/core/accessibility/domain/accessibility_profile.dart';
import 'package:bcc_adapt/core/l10n/money_formatter.dart';
import 'package:bcc_adapt/core/routing/app_router.dart';
import 'package:bcc_adapt/core/storage/secure_key_value_store.dart';
import 'package:bcc_adapt/core/theme/app_palette.dart';
import 'package:bcc_adapt/core/theme/app_theme_builder.dart';
import 'package:bcc_adapt/core/theme/contrast_checker.dart';
import 'package:bcc_adapt/core/voice/application/voice_accessibility_service.dart';
import 'package:bcc_adapt/core/voice/domain/amount_in_words.dart';
import 'package:bcc_adapt/features/accessibility_settings/presentation/accessibility_settings_screen.dart';
import 'package:bcc_adapt/features/banking/data/mock_bank_repository.dart';
import 'package:bcc_adapt/features/banking/presentation/home_screen.dart';
import 'package:bcc_adapt/features/banking/presentation/transfer_screen.dart';
import 'package:bcc_adapt/features/onboarding/presentation/calibration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyVoiceService extends VoiceAccessibilityService {
  final List<String> spokenTexts = [];
  int micPermissionRequests = 0;

  @override
  Future<bool> speak(
    String text, {
    required AccessibilityProfile profile,
    BuildContext? context,
    bool force = false,
  }) async {
    final mqAccessible =
        context != null &&
        context.mounted &&
        MediaQuery.accessibleNavigationOf(context);
    if (!VoiceAccessibilityService.canSpeak(
      profile: profile,
      mediaQueryAccessibleNavigation: mqAccessible,
      force: force,
    )) {
      return false;
    }
    spokenTexts.add(text);
    return true;
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<bool> requestMicrophonePermission() async {
    micPermissionRequests += 1;
    return false;
  }
}

InMemorySecureKeyValueStore _seededStore(AccessibilityProfile profile) {
  return InMemorySecureKeyValueStore({
    AccessibilityProfileRepository.storageKey: jsonEncode(profile.toJson()),
  });
}

Widget _wrapApp({
  required Widget home,
  required InMemorySecureKeyValueStore store,
  _SpyVoiceService? voiceSpy,
}) {
  AppThemeBuilder.useGoogleFonts = false;
  return ProviderScope(
    overrides: [
      secureKeyValueStoreProvider.overrideWithValue(store),
      systemAccessibilitySourceProvider.overrideWithValue(
        FakeSystemAccessibilitySource(),
      ),
      if (voiceSpy != null)
        voiceAccessibilityServiceProvider.overrideWithValue(voiceSpy),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final profile = ref.watch(currentAccessibilityProfileProvider);
        return MaterialApp(
          theme: AppThemeBuilder.build(profile),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: home,
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    AppThemeBuilder.useGoogleFonts = false;
  });

  group('Phase 4 Inclusive UX & FinTech Precision Regression', () {
    test('MoneyFormatter and AmountInWords match to exact tiyn without rounding', () {
      expect(MoneyFormatter.format(245800), '245\u00A0800\u00A0₸');
      expect(MoneyFormatter.format(100.50), '100,50\u00A0₸');
      expect(MoneyFormatter.format(-100.50), '−100,50\u00A0₸');
      expect(MoneyFormatter.format(100.05), '100,05\u00A0₸');
      expect(MoneyFormatter.format(245699.50), '245\u00A0699,50\u00A0₸');

      expect(AmountInWords.format(100.50, localeCode: 'ru'), 'Сто тенге 50 тиын');
      expect(AmountInWords.format(100.50, localeCode: 'kk'), 'Жүз теңге 50 тиын');
    });

    testWidgets(
      'Transfer of 100,50 ₸ preserves exact tiyns across form, receipt, Home balance and history',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final store = _seededStore(
          AccessibilityProfile.standard.copyWith(isOnboardingCompleted: true),
        );
        await tester.pumpWidget(
          _wrapApp(store: store, home: const HomeScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Переводы'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Дочь Алия'));
        await tester.pumpAndSettle();

        final amountField = find.byType(TextField).last;
        await tester.ensureVisible(amountField);
        await tester.enterText(amountField, '100,50');
        await tester.pumpAndSettle();

        // Exact tiyn representation & amount in words on draft
        expect(find.text('Сто тенге 50 тиын'), findsOneWidget);
        expect(find.textContaining('245\u00A0699,50\u00A0₸'), findsOneWidget);
        expect(find.textContaining('101\u00A0₸'), findsNothing);

        final confirmBtn = find.text('Подтвердить перевод');
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Receipt shows 100,50 ₸ and updated balance 245 699,50 ₸
        expect(find.text('Перевод отправлен'), findsOneWidget);
        expect(find.text('100,50\u00A0₸'), findsOneWidget);
        expect(find.text('Сто тенге 50 тиын'), findsOneWidget);
        expect(find.textContaining('245\u00A0699,50\u00A0₸'), findsOneWidget);
        expect(find.textContaining('101\u00A0₸'), findsNothing);

        // Return to HomeScreen and verify balance + transaction history
        await tester.tap(find.text('Вернуться на Главную'));
        await tester.pumpAndSettle();

        expect(find.text('245\u00A0699,50\u00A0₸'), findsOneWidget);
        final txHistoryAmount = find.text('−100,50\u00A0₸');
        await tester.ensureVisible(txHistoryAmount);
        expect(txHistoryAmount, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen in fullBanking at 2.0x keeps secondary services reachable via ExpansionTile while simplifiedEssential hides them',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final store = _seededStore(
          const AccessibilityProfile(
            textScaleFactor: 2.0,
            cognitiveMode: CognitiveMode.fullBanking,
            isOnboardingCompleted: true,
          ),
        );
        await tester.pumpWidget(
          _wrapApp(store: store, home: const HomeScreen()),
        );
        await tester.pumpAndSettle();

        final expandServices = find.text('Все услуги банка');
        await tester.ensureVisible(expandServices);
        expect(expandServices, findsOneWidget);
        expect(find.text('Мой банк'), findsNothing);

        await tester.tap(expandServices);
        await tester.pumpAndSettle();

        expect(find.text('Мой банк'), findsOneWidget);
        expect(find.text('Кэшбэк'), findsOneWidget);
        expect(find.text('Депозиты'), findsOneWidget);

        final myBankTile = find.text('Мой банк');
        await tester.ensureVisible(myBankTile);
        await tester.tap(myBankTile);
        await tester.pumpAndSettle();
        expect(find.text('Закрыть'), findsOneWidget);
        await tester.tap(find.text('Закрыть'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        await container
            .read(accessibilityProfileProvider.notifier)
            .setCognitiveMode(CognitiveMode.simplifiedEssential);
        await tester.pumpAndSettle();

        expect(find.text('Все услуги банка'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Recalibration launched from Settings with fromSettings: true pops back and preserves isOnboardingCompleted',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final store = _seededStore(
          AccessibilityProfile.standard.copyWith(isOnboardingCompleted: true),
        );
        await tester.pumpWidget(
          _wrapApp(store: store, home: const AccessibilitySettingsScreen()),
        );
        await tester.pumpAndSettle();

        final recalibrateBtn = find.text('Подобрать удобный вид заново');
        await tester.ensureVisible(recalibrateBtn);
        await tester.tap(recalibrateBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CalibrationScreen), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CalibrationScreen)),
        );
        expect(
          container
              .read(currentAccessibilityProfileProvider)
              .isOnboardingCompleted,
          isTrue,
        );

        await tester.ensureVisible(find.text('Далее'));
        await tester.tap(find.text('Далее'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Далее'));
        await tester.tap(find.text('Далее'));
        await tester.pumpAndSettle();

        final saveReturnBtn = find.text('Сохранить и вернуться');
        expect(saveReturnBtn, findsOneWidget);
        expect(find.text('Ко входу в банк'), findsNothing);
        await tester.ensureVisible(saveReturnBtn);
        await tester.tap(saveReturnBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
        expect(
          container
              .read(currentAccessibilityProfileProvider)
              .isOnboardingCompleted,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Quick reset button on AccessibilitySettingsScreen works without scrolling and supports Undo SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const initialAdapted = AccessibilityProfile(
          textScaleFactor: 2.0,
          contrastMode: ContrastMode.highContrastDark,
          motorLevel: MotorAssistanceLevel.tremorProtection,
          cognitiveMode: CognitiveMode.guidedStepByStep,
          voiceAssistantEnabled: true,
          isOnboardingCompleted: true,
        );
        final store = _seededStore(initialAdapted);
        await tester.pumpWidget(
          _wrapApp(store: store, home: const AccessibilitySettingsScreen()),
        );
        await tester.pumpAndSettle();

        final quickResetBtn = find.byKey(
          const ValueKey('quick_reset_accessibility'),
        );
        expect(quickResetBtn, findsOneWidget);
        // Must be visible immediately without scrolling!
        expect(tester.getRect(quickResetBtn).bottom, lessThanOrEqualTo(640.0));

        await tester.tap(quickResetBtn);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AccessibilitySettingsScreen)),
        );
        final afterReset = container.read(currentAccessibilityProfileProvider);
        expect(afterReset.textScaleFactor, 1.0);
        expect(afterReset.contrastMode, ContrastMode.standard);
        expect(afterReset.motorLevel, MotorAssistanceLevel.standard);
        expect(afterReset.cognitiveMode, CognitiveMode.fullBanking);
        expect(afterReset.voiceAssistantEnabled, isFalse);
        expect(afterReset.isOnboardingCompleted, isTrue);
        expect(
          container
              .read(mockBankRepositoryProvider)
              .primaryAccount
              .balanceTenge,
          245800,
        );
        expect(find.text('Обычный режим BCC уже активен'), findsOneWidget);

        // Undo restores the exact previous profile
        final undoBtn = find.text('Отменить');
        expect(undoBtn, findsOneWidget);
        await tester.tap(undoBtn);
        await tester.pumpAndSettle();

        expect(
          container.read(currentAccessibilityProfileProvider),
          initialAdapted,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Standard palette satisfies WCAG AA contrast and VoiceAssistantToggle in Settings never requests microphone',
      (tester) async {
        const p = AppPalette.standardBcc;
        expect(ContrastChecker.meetsAA(p.onPrimary, p.primary), isTrue);
        expect(ContrastChecker.meetsAA(p.primary, p.surface), isTrue);
        expect(ContrastChecker.meetsAA(p.onSurfaceMuted, p.surfaceVariant), isTrue);
        expect(ContrastChecker.ratio(p.border, p.surfaceVariant), greaterThanOrEqualTo(3.0));

        final spy = _SpyVoiceService();
        final store = _seededStore(
          AccessibilityProfile.standard.copyWith(isOnboardingCompleted: true),
        );
        await tester.pumpWidget(
          _wrapApp(
            store: store,
            voiceSpy: spy,
            home: const AccessibilitySettingsScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final voiceSwitch = find.byType(Switch);
        await tester.ensureVisible(voiceSwitch);
        await tester.tap(voiceSwitch);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AccessibilitySettingsScreen)),
        );
        expect(
          container
              .read(currentAccessibilityProfileProvider)
              .voiceAssistantEnabled,
          isTrue,
        );
        expect(spy.micPermissionRequests, 0);

        await tester.tap(voiceSwitch);
        await tester.pumpAndSettle();
        expect(
          container
              .read(currentAccessibilityProfileProvider)
              .voiceAssistantEnabled,
          isFalse,
        );
        expect(spy.micPermissionRequests, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TransferScreen handles partial/unrecognized voice input and HoldToConfirm early release + code fallback',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spy = _SpyVoiceService();
        final store = _seededStore(
          const AccessibilityProfile(
            motorLevel: MotorAssistanceLevel.tremorProtection,
            cognitiveMode: CognitiveMode.guidedStepByStep,
            voiceAssistantEnabled: true,
            isOnboardingCompleted: true,
          ),
        );
        await tester.pumpWidget(
          _wrapApp(store: store, voiceSpy: spy, home: const TransferScreen()),
        );
        await tester.pumpAndSettle();

        // Select Aliya, then test unrecognized voice command
        await tester.tap(find.text('Дочь Алия'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Заполнить голосом'));
        await tester.tap(find.text('Заполнить голосом'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransferScreen)),
        );
        container
            .read(voiceSessionProvider.notifier)
            .simulateVoiceInput('Привет банк');
        await tester.pumpAndSettle();

        expect(find.textContaining('Не удалось расслышать'), findsOneWidget);
        expect(find.text('Повторить'), findsOneWidget);

        // Partial voice recognition (amount only): preserves recipient until Apply
        container
            .read(voiceSessionProvider.notifier)
            .simulateVoiceInput('Перевести 3500 тенге');
        await tester.pumpAndSettle();

        expect(find.textContaining('Распознана только сумма'), findsOneWidget);
        await tester.ensureVisible(find.text('Применить'));
        await tester.tap(find.text('Применить'));
        await tester.pumpAndSettle();
        expect(find.text('Три тысячи пятьсот тенге'), findsOneWidget);

        // Early release on Hold-to-Confirm shows helpful hint
        final holdLabel = find.text('Подтвердить перевод');
        await tester.ensureVisible(holdLabel);
        final shortGesture = await tester.startGesture(
          tester.getCenter(holdLabel),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await shortGesture.up();
        await tester.pumpAndSettle();

        expect(
          find.text('Не отпускайте палец — удерживайте кнопку 1,5 секунды'),
          findsOneWidget,
        );

        // Code confirmation fallback completes transfer in 1 tap
        final codeFallback = find.text('Подтвердить без удержания (по коду)');
        await tester.ensureVisible(codeFallback);
        await tester.tap(codeFallback);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Подтвердить кодом 4829'));
        await tester.pumpAndSettle();
        expect(find.text('Перевод отправлен'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
