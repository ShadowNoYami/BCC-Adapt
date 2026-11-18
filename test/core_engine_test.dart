import 'package:bcc_adapt/core/accessibility/domain/accessibility_profile.dart';
import 'package:bcc_adapt/core/accessibility/domain/accessibility_rules_engine.dart';
import 'package:bcc_adapt/core/accessibility/domain/calibration_results.dart';
import 'package:bcc_adapt/core/accessibility/domain/system_accessibility_flags.dart';
import 'package:bcc_adapt/core/theme/app_palette.dart';
import 'package:bcc_adapt/core/theme/contrast_checker.dart';
import 'package:bcc_adapt/core/voice/application/voice_accessibility_service.dart';
import 'package:bcc_adapt/core/voice/domain/amount_in_words.dart';
import 'package:bcc_adapt/core/voice/domain/voice_transfer_parser.dart';
import 'package:bcc_adapt/features/banking/data/mock_bank_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessibilityProfile & RulesEngine', () {
    test('normalizes textScaleFactor to 1.0..2.0 with 0.25 step', () {
      expect(AccessibilityProfile.normalizeTextScale(0.8), 1.0);
      expect(AccessibilityProfile.normalizeTextScale(1.14), 1.25);
      expect(AccessibilityProfile.normalizeTextScale(1.6), 1.5);
      expect(AccessibilityProfile.normalizeTextScale(2.5), 2.0);
    });

    test('pre-configures profile from system flags before onboarding', () {
      const flags = SystemAccessibilityFlags(
        textScaleFactor: 1.5,
        accessibleNavigation: true,
        boldText: true,
        highContrast: true,
      );
      final adapted = AccessibilityRulesEngine.applySystemFlags(
        AccessibilityProfile.standard,
        flags,
      );
      expect(adapted.textScaleFactor, 1.5);
      expect(adapted.contrastMode, ContrastMode.highContrastLight);
      expect(adapted.motorLevel, MotorAssistanceLevel.enlargedTargets);
      expect(adapted.screenReaderActive, isTrue);
      expect(adapted.canUseBuiltInVoice, isFalse);
    });

    test('calibration rules deterministically set motor and cognitive modes', () {
      var profile = AccessibilityProfile.standard;
      profile = AccessibilityRulesEngine.applyMotor(
        profile,
        const MotorCalibrationResult(
          totalTargets: 6,
          missedTaps: 4,
          accidentalRepeatTaps: 3,
        ),
      );
      expect(profile.motorLevel, MotorAssistanceLevel.tremorProtection);
      expect(profile.requiresHoldToConfirm, isTrue);

      profile = AccessibilityRulesEngine.applyCognitive(
        profile,
        const CognitiveCalibrationResult(
          completed: true,
          durationMs: 50000,
          wrongTaps: 5,
        ),
      );
      expect(profile.cognitiveMode, CognitiveMode.guidedStepByStep);
    });
  });

  group('WCAG 2.1 AAA Contrast Verification', () {
    test('High Contrast Light meets >= 7:1 AAA threshold', () {
      const p = AppPalette.highContrastLight;
      expect(ContrastChecker.meetsAAA(p.onSurface, p.background), isTrue);
      expect(ContrastChecker.meetsAAA(p.primary, p.background), isTrue);
      expect(ContrastChecker.meetsAAA(p.onPrimary, p.primary), isTrue);
    });

    test('High Contrast Dark meets >= 7:1 AAA threshold', () {
      const p = AppPalette.highContrastDark;
      expect(ContrastChecker.meetsAAA(p.onSurface, p.background), isTrue);
      expect(ContrastChecker.meetsAAA(p.primary, p.background), isTrue);
      expect(ContrastChecker.meetsAAA(p.onPrimary, p.primary), isTrue);
      expect(ContrastChecker.meetsAAA(p.emphasis, p.background), isTrue);
    });
  });

  group('TalkBack Guard & VoiceTransferParser', () {
    test('blocks built-in TTS when screenReaderActive or accessibleNavigation', () {
      const profileWithVoice = AccessibilityProfile(
        voiceAssistantEnabled: true,
        screenReaderActive: true,
      );
      expect(
        VoiceAccessibilityService.canSpeak(profile: profileWithVoice),
        isFalse,
      );
      expect(
        VoiceAccessibilityService.canSpeak(
          profile: const AccessibilityProfile(voiceAssistantEnabled: true),
          mediaQueryAccessibleNavigation: true,
        ),
        isFalse,
      );
      expect(
        VoiceAccessibilityService.canSpeak(
          profile: const AccessibilityProfile(voiceAssistantEnabled: true),
        ),
        isTrue,
      );
    });

    test('parses Russian spoken transfer with phone number', () {
      const parser = VoiceTransferParser();
      final intent = parser.parse(
        'Перевести пять тысяч тенге на номер 8 707 123 45 67',
      );
      expect(intent.amount, 5000);
      expect(intent.normalizedPhone, '+77071234567');
      expect(intent.amountInWords, 'Пять тысяч тенге');
    });

    test('parses recipient name and digits in Russian and Kazakh', () {
      const parser = VoiceTransferParser();
      final ru = parser.parse('Отправить 15000 Арману');
      expect(ru.amount, 15000);
      expect(ru.recipientQuery, 'Арману');
      expect(ru.amountInWords, 'Пятнадцать тысяч тенге');

      final kk = parser.parse(
        'Арманға екі мың бес жүз теңге жібер',
        localeCode: 'kk',
      );
      expect(kk.amount, 2500);
      expect(kk.amountInWords, 'Екі мың бес жүз теңге');
    });

    test('formats 100 000 ₸ in words accurately', () {
      expect(AmountInWords.format(100000), 'Сто тысяч тенге');
      expect(
        AmountInWords.format(100000, localeCode: 'kk'),
        'Жүз мың теңге',
      );
    });
  });

  group('MockBankRepository', () {
    test('has #bcc карта with 245 800 ₸ and quick contacts', () {
      expect(MockBankRepository.initialPrimaryAccount.balanceTenge, 245800);
      expect(MockBankRepository.initialQuickContacts.length, 3);
    });
  });
}
