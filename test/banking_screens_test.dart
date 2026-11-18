import 'package:bcc_adapt/core/accessibility/application/accessibility_profile_notifier.dart';
import 'package:bcc_adapt/core/accessibility/data/system_accessibility_source.dart';
import 'package:bcc_adapt/core/accessibility/domain/accessibility_profile.dart';
import 'package:bcc_adapt/core/routing/app_router.dart';
import 'package:bcc_adapt/core/storage/secure_key_value_store.dart';
import 'package:bcc_adapt/core/theme/app_theme_builder.dart';
import 'package:bcc_adapt/core/voice/application/voice_accessibility_service.dart';
import 'package:bcc_adapt/features/accessibility_settings/presentation/accessibility_settings_screen.dart';
import 'package:bcc_adapt/features/banking/data/mock_bank_repository.dart';
import 'package:bcc_adapt/features/banking/presentation/home_screen.dart';
import 'package:bcc_adapt/features/banking/presentation/transfer_screen.dart';
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

  group('Stage 3 Screens: Home, Transfer, Accessibility Settings', () {
    testWidgets(
        'HomeScreen switches between fullBanking grid and single-column reflow at 200% + HC Dark + Tremor',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = InMemorySecureKeyValueStore();
      final spy = _SpyVoiceService();
      await tester.pumpWidget(
        _wrapApp(
          store: store,
          voiceSpy: spy,
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Standard fullBanking: promo & secondary tiles visible
      expect(find.text('Мой банк'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Кэшбэк до 10% по #bcc карте'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Кэшбэк до 10% по #bcc карте'), findsOneWidget);

      // Apply worst-case accessibility profile
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      final notifier = container.read(accessibilityProfileProvider.notifier);
      await notifier.setTextScale(2.0);
      await notifier.setContrastMode(ContrastMode.highContrastDark);
      await notifier.setMotorLevel(MotorAssistanceLevel.tremorProtection);
      await notifier.setVoiceAssistantEnabled(true);
      await tester.pumpAndSettle();

      // Promo and secondary services hidden; only essential 3 actions shown
      expect(find.text('Мой банк'), findsNothing);
      expect(find.text('Кэшбэк до 10% по #bcc карте'), findsNothing);
      expect(find.text('Переводы'), findsOneWidget);
      expect(find.text('Платежи'), findsOneWidget);
      expect(find.text('История операций'), findsOneWidget);

      // Speak balance button works when voiceAssistantEnabled == true
      final speakBtn = find.text('Озвучить баланс');
      await tester.ensureVisible(speakBtn);
      await tester.tap(speakBtn);
      await tester.pump();
      expect(spy.spokenTexts.length, 1);
      expect(spy.spokenTexts.first, contains('245'));

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'TransferScreen fills draft via voice, shows amount in words, enforces 5s anti-fraud and 1.5s hold-to-confirm',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = InMemorySecureKeyValueStore();
      final spy = _SpyVoiceService();
      await tester.pumpWidget(
        _wrapApp(
          store: store,
          voiceSpy: spy,
          home: const TransferScreen(
            coolingOffTickDuration: Duration(milliseconds: 20),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransferScreen)),
      );
      final notifier = container.read(accessibilityProfileProvider.notifier);
      await notifier.setTextScale(2.0);
      await notifier.setContrastMode(ContrastMode.highContrastDark);
      await notifier.setMotorLevel(MotorAssistanceLevel.tremorProtection);
      await notifier.setCognitiveMode(CognitiveMode.guidedStepByStep);
      await notifier.setVoiceAssistantEnabled(true);
      await tester.pumpAndSettle();

      // 1. Simulated voice draft for Arman 5000 ₸ (trusted contact -> no stranger warning)
      final demoArmanChip = find.text('«Перевести 5000 тенге Арману»');
      await tester.ensureVisible(demoArmanChip);
      await tester.tap(demoArmanChip);
      await tester.pumpAndSettle();

      expect(find.text('Пять тысяч тенге'), findsOneWidget);
      expect(spy.spokenTexts.last, contains('Подготовлен перевод'));
      expect(find.textContaining('Внимание! Перевод незнакомому'), findsNothing);

      // 2. Simulated voice draft to unknown phone for 60 000 ₸ -> triggers 5s anti-fraud cooling-off
      final demoStrangerChip =
          find.text('«Перевести 60000 тенге на 8 777 999 88 77»');
      await tester.ensureVisible(demoStrangerChip);
      await tester.tap(demoStrangerChip);
      await tester.pump();

      expect(find.text('Шестьдесят тысяч тенге'), findsOneWidget);
      expect(find.textContaining('Внимание! Перевод незнакомому'), findsOneWidget);
      expect(find.text('Подождите 5 сек...'), findsOneWidget);

      // Wait for 5 ticks (5 * 20ms) to finish cooling-off
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Hold-to-confirm button now visible for tremorProtection
      final holdLabel = find.text('Удерживайте 1.5 сек для перевода');
      await tester.ensureVisible(holdLabel);
      expect(holdLabel, findsOneWidget);

      // Hold pointer down for 1.6 seconds to confirm transfer
      final center = tester.getCenter(holdLabel);
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();
      await tester.pumpAndSettle();

      // Transfer executed: receipt displayed and MockBankRepository balance updated (245800 - 60000 = 185800)
      expect(find.text('Перевод выполнен успешно'), findsOneWidget);
      expect(
        container.read(mockBankRepositoryProvider).primaryAccount.balanceTenge,
        185800,
      );
      expect(spy.spokenTexts.last, 'Перевод выполнен успешно');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'AccessibilitySettingsScreen renders without overflow at 200% + HC Dark + Tremor and resets cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final store = InMemorySecureKeyValueStore();
      final spy = _SpyVoiceService();
      await tester.pumpWidget(
        _wrapApp(
          store: store,
          voiceSpy: spy,
          home: const AccessibilitySettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccessibilitySettingsScreen)),
      );
      final notifier = container.read(accessibilityProfileProvider.notifier);
      await notifier.setTextScale(2.0);
      await notifier.setContrastMode(ContrastMode.highContrastDark);
      await notifier.setMotorLevel(MotorAssistanceLevel.tremorProtection);
      await notifier.setCognitiveMode(CognitiveMode.guidedStepByStep);
      await tester.pumpAndSettle();

      expect(find.text('Живое превью интерфейса'), findsOneWidget);

      // Tap "Сбросить до стандартного BCC"
      final resetBtn = find.text('Сбросить до стандартного BCC');
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      final resetProfile = container.read(currentAccessibilityProfileProvider);
      expect(resetProfile.textScaleFactor, 1.0);
      expect(resetProfile.contrastMode, ContrastMode.standard);
      expect(resetProfile.motorLevel, MotorAssistanceLevel.standard);
      expect(resetProfile.cognitiveMode, CognitiveMode.fullBanking);
      expect(tester.takeException(), isNull);
    });
  });
}
