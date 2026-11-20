import 'package:bcc_adapt/core/accessibility/application/accessibility_profile_notifier.dart';
import 'package:bcc_adapt/core/accessibility/data/system_accessibility_source.dart';
import 'package:bcc_adapt/core/accessibility/domain/accessibility_profile.dart';
import 'package:bcc_adapt/core/storage/secure_key_value_store.dart';
import 'package:bcc_adapt/core/theme/app_theme_builder.dart';
import 'package:bcc_adapt/core/voice/application/voice_accessibility_service.dart';
import 'package:bcc_adapt/features/onboarding/presentation/adaptive_registration_screen.dart';
import 'package:bcc_adapt/features/onboarding/presentation/calibration_screen.dart';
import 'package:bcc_adapt/features/onboarding/presentation/welcome_screen.dart';
import 'package:bcc_adapt/main.dart';
import 'package:bcc_adapt/shared/widgets/adaptive_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyVoiceService extends VoiceAccessibilityService {
  final List<String> spokenTexts = [];

  @override
  Future<bool> speak(
    String text, {
    required AccessibilityProfile profile,
    BuildContext? context,
    bool force = false,
  }) async {
    final mqAccessible = context != null &&
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
  Future<bool> requestMicrophonePermission() async => false;
}

Widget _wrapWithApp({
  required Widget child,
  required InMemorySecureKeyValueStore store,
  _SpyVoiceService? voiceSpy,
  FakeSystemAccessibilitySource? systemSource,
}) {
  AppThemeBuilder.useGoogleFonts = false;
  return ProviderScope(
    overrides: [
      secureKeyValueStoreProvider.overrideWithValue(store),
      systemAccessibilitySourceProvider.overrideWithValue(
        systemSource ?? FakeSystemAccessibilitySource(),
      ),
      if (voiceSpy != null)
        voiceAccessibilityServiceProvider.overrideWithValue(voiceSpy),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final profile = ref.watch(currentAccessibilityProfileProvider);
        return MaterialApp(
          theme: AppThemeBuilder.build(profile),
          builder: (context, innerChild) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: innerChild ?? const SizedBox.shrink(),
            );
          },
          home: child,
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    AppThemeBuilder.useGoogleFonts = false;
  });

  group('Stage 2 Adaptive UI & 200% Scale Overflow Checks', () {
    testWidgets('WelcomeScreen renders without overflow at 200% scale on 360x640',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = InMemorySecureKeyValueStore();
      await tester.pumpWidget(
        _wrapWithApp(
          store: store,
          child: const WelcomeScreen(zeroTouchDelay: Duration(hours: 1)),
        ),
      );
      await tester.pumpAndSettle();

      // Increase text scale to 200% and switch to highContrastDark
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WelcomeScreen)),
      );
      await container.read(accessibilityProfileProvider.notifier).setTextScale(2.0);
      await container
          .read(accessibilityProfileProvider.notifier)
          .setContrastMode(ContrastMode.highContrastDark);
      await tester.pumpAndSettle();

      expect(find.text('Настроить банк для себя'), findsOneWidget);
      expect(find.text('Продолжить без настройки'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WelcomeScreen Zero-Touch Audio Prompt fires after timeout and obeys TalkBack Guard',
        (tester) async {
      final spy = _SpyVoiceService();
      final store = InMemorySecureKeyValueStore();

      await tester.pumpWidget(
        _wrapWithApp(
          store: store,
          voiceSpy: spy,
          child: const WelcomeScreen(
            zeroTouchDelay: Duration(milliseconds: 100),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(spy.spokenTexts.length, 1);
      expect(spy.spokenTexts.first, contains('Здравствуйте'));
    });

    testWidgets('CalibrationScreen all 3 steps render cleanly at 200% scale and adapt in real time',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final spy = _SpyVoiceService();
      final store = InMemorySecureKeyValueStore();

      await tester.pumpWidget(
        _wrapWithApp(
          store: store,
          voiceSpy: spy,
          child: const CalibrationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalibrationScreen)),
      );

      // Step 1: tap 3rd high-contrast card (2.0x scale)
      final maxCard = find.text('Самый крупный текст');
      await tester.ensureVisible(maxCard);
      await tester.tap(maxCard);
      await tester.pumpAndSettle();

      expect(
        container.read(currentAccessibilityProfileProvider).textScaleFactor,
        2.0,
      );
      expect(
        container.read(currentAccessibilityProfileProvider).isHighContrast,
        isTrue,
      );

      // Advance to Step 2
      final nextBtn = find.text('Далее');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Нажмите сюда'), findsOneWidget);

      // Choose tremor protection explicitly
      final tremorOption = find.text('Крупные кнопки с защитой');
      await tester.ensureVisible(tremorOption);
      await tester.tap(tremorOption);
      await tester.pumpAndSettle();

      expect(
        container.read(currentAccessibilityProfileProvider).motorLevel,
        MotorAssistanceLevel.tremorProtection,
      );

      // Advance to Step 3
      final nextBtn2 = find.text('Далее');
      await tester.ensureVisible(nextBtn2);
      await tester.tap(nextBtn2);
      await tester.pumpAndSettle();

      // Step 1 Card 3 (2.0x) auto-enabled voiceAssistantEnabled; toggle OFF then ON
      // via Switch to verify microphone permission request & graceful denial.
      expect(
        container.read(currentAccessibilityProfileProvider).voiceAssistantEnabled,
        isTrue,
      );
      final voiceSwitch = find.byType(Switch);
      await tester.ensureVisible(voiceSwitch);
      await tester.tap(voiceSwitch);
      await tester.pumpAndSettle();
      expect(
        container.read(currentAccessibilityProfileProvider).voiceAssistantEnabled,
        isFalse,
      );

      await tester.tap(voiceSwitch);
      await tester.pumpAndSettle();
      expect(
        container.read(currentAccessibilityProfileProvider).voiceAssistantEnabled,
        isTrue,
      );

      expect(find.textContaining('Микрофон недоступен'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdaptiveRegistrationScreen adapts 2-step flow and external labels at 200% scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = InMemorySecureKeyValueStore();
      await tester.pumpWidget(
        _wrapWithApp(
          store: store,
          child: const AdaptiveRegistrationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdaptiveRegistrationScreen)),
      );
      await container
          .read(accessibilityProfileProvider.notifier)
          .setCognitiveMode(CognitiveMode.simplifiedEssential);
      await container.read(accessibilityProfileProvider.notifier).setTextScale(2.0);
      await tester.pumpAndSettle();

      // Step 1 of 2: phone only visible
      expect(find.text('Шаг 1 из 2'), findsOneWidget);
      expect(find.text('Номер телефона'), findsOneWidget);
      expect(find.text('Код из SMS или ИИН'), findsNothing);

      // Fill demo data
      final fillBtn = find.text('Заполнить примером');
      await tester.ensureVisible(fillBtn);
      await tester.tap(fillBtn);
      await tester.pumpAndSettle();

      // Proceed to step 2
      final nextBtn = find.text('Далее');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Шаг 2 из 2'), findsOneWidget);
      expect(find.text('Код из SMS или ИИН'), findsOneWidget);
      expect(find.text('Войти в BCC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdaptiveActionButton enforces tremorProtection size (72dp) and 600ms debounce',
        (tester) async {
      var taps = 0;
      var fakeNow = DateTime(2026, 11, 16, 10, 0, 0);
      final store = InMemorySecureKeyValueStore();

      await tester.pumpWidget(
        _wrapWithApp(
          store: store,
          child: Scaffold(
            body: Center(
              child: AdaptiveActionButton(
                label: 'Тест кнопки',
                nowProvider: () => fakeNow,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdaptiveActionButton)),
      );
      await container
          .read(accessibilityProfileProvider.notifier)
          .setMotorLevel(MotorAssistanceLevel.tremorProtection);
      await tester.pumpAndSettle();

      final btnRect = tester.getRect(find.byType(ElevatedButton));
      expect(btnRect.height, greaterThanOrEqualTo(72.0));

      // Two rapid taps within 600ms -> only 1 counted
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      fakeNow = fakeNow.add(const Duration(milliseconds: 200));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(taps, 1);

      // Tap after 650ms -> counted
      fakeNow = fakeNow.add(const Duration(milliseconds: 650));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('BccAdaptApp starts on WelcomeScreen when onboarding not completed',
        (tester) async {
      final store = InMemorySecureKeyValueStore();
      final spy = _SpyVoiceService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureKeyValueStoreProvider.overrideWithValue(store),
            systemAccessibilitySourceProvider.overrideWithValue(
              FakeSystemAccessibilitySource(),
            ),
            voiceAccessibilityServiceProvider.overrideWithValue(spy),
          ],
          child: const BccAdaptApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(WelcomeScreen))).canPop(),
        isFalse,
      );

      // Ensure pending zero-touch timer on WelcomeScreen fires cleanly without leaking
      await tester.pump(const Duration(seconds: 5));
      expect(spy.spokenTexts.length, 1);
    });
  });
}
