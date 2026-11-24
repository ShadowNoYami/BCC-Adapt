import 'package:bcc_adapt/core/accessibility/domain/accessibility_profile.dart';
import 'package:bcc_adapt/core/l10n/app_strings.dart';
import 'package:bcc_adapt/core/l10n/money_formatter.dart';
import 'package:bcc_adapt/core/voice/application/voice_accessibility_service.dart';
import 'package:bcc_adapt/core/voice/domain/amount_in_words.dart';
import 'package:bcc_adapt/core/voice/domain/speech_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _FakeFlutterTts implements FlutterTts {
  _FakeFlutterTts({
    this.availableVoices = const [],
    this.availableLanguages = const {},
  });

  final List<Map<String, String>> availableVoices;
  final Set<String> availableLanguages;

  final List<String> spoken = [];
  String? lastLanguage;
  Map<String, String>? lastVoice;
  double? lastSpeechRate;
  double? lastPitch;
  double? lastVolume;

  @override
  Future<dynamic> get getVoices async => availableVoices;

  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      availableLanguages.contains(language);

  @override
  Future<dynamic> setLanguage(String language) async {
    lastLanguage = language;
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    lastVoice = voice;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    lastSpeechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    lastPitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    lastVolume = volume;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return 1;
  }

  @override
  Future<dynamic> stop() async => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSpeechToText implements SpeechToText {
  @override
  bool get isListening => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const normalizer = SpeechTextNormalizer();
  final asciiDigits = RegExp(r'[0-9]');

  group('SpeechTextNormalizer — Kazakh (kk)', () {
    test('converts tenge amounts including tiyns into full Kazakh words with zero ASCII digits', () {
      final balance = normalizer.normalize('245\u00A0800\u00A0₸', localeCode: 'kk');
      expect(balance, 'екі жүз қырық бес мың сегіз жүз теңге');
      expect(asciiDigits.hasMatch(balance), isFalse);

      final withTiyn = normalizer.normalize('100,50 ₸', localeCode: 'kk');
      expect(withTiyn, 'жүз теңге елу тиын');
      expect(asciiDigits.hasMatch(withTiyn), isFalse);

      final fifteenK = normalizer.normalize('15 000 ₸', localeCode: 'kk');
      expect(fifteenK, 'он бес мың теңге');
      expect(asciiDigits.hasMatch(fifteenK), isFalse);

      final fullBalancePrompt = const AppStrings('kk').speakBalanceTemplate(
        MoneyFormatter.format(245800, localeCode: 'kk'),
        AmountInWords.format(245800, localeCode: 'kk'),
      );
      final normalizedBalancePrompt = normalizer.normalize(
        fullBalancePrompt,
        localeCode: 'kk',
      );
      expect(
        normalizedBalancePrompt,
        contains('екі жүз қырық бес мың сегіз жүз теңге'),
      );
      expect(asciiDigits.hasMatch(normalizedBalancePrompt), isFalse);
    });

    test('converts percentages into Kazakh words with zero ASCII digits', () {
      expect(normalizer.normalize('200%', localeCode: 'kk'), 'екі жүз пайыз');
      expect(normalizer.normalize('150%', localeCode: 'kk'), 'жүз елу пайыз');
      expect(normalizer.normalize('100%', localeCode: 'kk'), 'жүз пайыз');

      final deposit = normalizer.normalize(
        'BCC Рахмет депозиті — жылдық 14.5% дейін',
        localeCode: 'kk',
      );
      expect(deposit, contains('он төрт бүтін бес пайыз'));
      expect(asciiDigits.hasMatch(deposit), isFalse);
    });

    test('converts fractional/whole seconds and step progress into Kazakh numerals', () {
      final timer = normalizer.normalize('1,5 сек', localeCode: 'kk');
      expect(timer, 'бір бүтін бес секунд');
      expect(asciiDigits.hasMatch(timer), isFalse);

      final fiveSec = normalizer.normalize('Тексеруге 5 сек', localeCode: 'kk');
      expect(fiveSec, 'Тексеруге бес секунд');
      expect(asciiDigits.hasMatch(fiveSec), isFalse);

      final ruStep = normalizer.normalize('Шаг 1 из 3', localeCode: 'kk');
      expect(ruStep, 'үштен бірінші қадам');
      expect(asciiDigits.hasMatch(ruStep), isFalse);

      final slashStep = normalizer.normalize('1 / 3', localeCode: 'kk');
      expect(slashStep, 'үштен бірінші қадам');
      expect(asciiDigits.hasMatch(slashStep), isFalse);

      final kkStep = normalizer.normalize('1-қадам, барлығы 3', localeCode: 'kk');
      expect(kkStep, 'үштен бірінші қадам');
      expect(asciiDigits.hasMatch(kkStep), isFalse);
    });

    test('spells out phone numbers digit by digit in Kazakh with natural pauses', () {
      final phone = normalizer.normalize('+7 707 999 88 77', localeCode: 'kk');
      expect(
        phone,
        'плюс жеті, жеті нөл жеті, тоғыз тоғыз тоғыз, сегіз сегіз, жеті жеті',
      );
      expect(asciiDigits.hasMatch(phone), isFalse);

      final eightPhone = normalizer.normalize(
        '8 777 999 88 77 нөміріне 60000 теңге жібер',
        localeCode: 'kk',
      );
      expect(eightPhone, contains('сегіз, жеті жеті жеті'));
      expect(eightPhone, contains('алпыс мың теңге'));
      expect(asciiDigits.hasMatch(eightPhone), isFalse);
    });

    test('converts any remaining integers and complex mixed Kazakh text without leaving 0-9', () {
      final mixed = normalizer.normalize(
        'Қалдық: 245 800 ₸ • 100,50 ₸\nМасштаб: 200% • Таймер: 1,5 сек\nНөмір: +7 707 999 88 77\nКод: 4829',
        localeCode: 'kk',
      );
      expect(asciiDigits.hasMatch(mixed), isFalse);
      expect(mixed, contains('екі жүз қырық бес мың сегіз жүз теңге'));
      expect(mixed, contains('жүз теңге елу тиын'));
      expect(mixed, contains('екі жүз пайыз'));
      expect(mixed, contains('бір бүтін бес секунд'));
      expect(mixed, contains('плюс жеті, жеті нөл жеті'));
      expect(mixed, contains('төрт мың сегіз жүз жиырма тоғыз'));
    });
  });

  group('SpeechTextNormalizer — Russian (ru) & Natural Pauses', () {
    test('expands Russian currency, percent, seconds, phone prefix and ЖКХ', () {
      expect(
        normalizer.normalize('Баланс: 245\u00A0800\u00A0₸', localeCode: 'ru'),
        'Баланс: 245 800 тенге',
      );
      expect(
        normalizer.normalize('Масштаб 200%', localeCode: 'ru'),
        'Масштаб 200 процентов',
      );
      expect(
        normalizer.normalize('Удерживайте кнопку 1,5 сек', localeCode: 'ru'),
        'Удерживайте кнопку полторы секунды',
      );
      expect(
        normalizer.normalize('На проверку 5 сек', localeCode: 'ru'),
        'На проверку 5 секунд',
      );
      expect(
        normalizer.normalize('Телефон +7 707 999 88 77', localeCode: 'ru'),
        'Телефон плюс семь 707 999 88 77',
      );
      expect(
        normalizer.normalize('Оплата ЖКХ', localeCode: 'ru'),
        'Оплата коммунальные услуги',
      );
    });

    test('turns line breaks, bullet markers and spaced slashes into clean punctuation pauses', () {
      final paused = normalizer.normalize(
        'Переводы • Платежи\nЯзык / Тіл\nИстория.',
        localeCode: 'ru',
      );
      expect(paused, 'Переводы, Платежи. Язык, Тіл. История.');
    });
  });

  group('VoiceAccessibilityService — Natural Voice Selection & Prosody', () {
    test('prefers neural / natural Kazakh and Russian voices over basic voices', () {
      final voices = [
        {'name': 'kk-kz-espeak', 'locale': 'kk-KZ'},
        {'name': 'kk-kz-x-kkc-local', 'locale': 'kk-KZ'},
        {'name': 'Microsoft Aigul Online (Natural) - Kazakh', 'locale': 'kk-KZ'},
        {'name': 'ru-ru-compact', 'locale': 'ru-RU'},
        {'name': 'Google русский Neural', 'locale': 'ru-RU'},
      ];

      final bestKk = VoiceAccessibilityService.selectBestVoice(
        voices,
        localeCode: 'kk',
      );
      expect(bestKk?['name'], 'Microsoft Aigul Online (Natural) - Kazakh');

      final bestRu = VoiceAccessibilityService.selectBestVoice(
        voices,
        localeCode: 'ru',
      );
      expect(bestRu?['name'], 'Google русский Neural');
    });

    test('falls back softly to natural Russian voice when kk-KZ is absent', () {
      final voicesWithoutKk = [
        {'name': 'en-US-Neural', 'locale': 'en-US'},
        {'name': 'ru-ru-x-ruf-local', 'locale': 'ru-RU'},
        {'name': 'Microsoft Svetlana Online (Natural) - Russian', 'locale': 'ru-RU'},
      ];

      final fallback = VoiceAccessibilityService.selectBestVoice(
        voicesWithoutKk,
        localeCode: 'kk',
      );
      expect(fallback?['name'], 'Microsoft Svetlana Online (Natural) - Russian');
      expect(fallback?['locale'], 'ru-RU');
    });

    test('speak() normalizes Kazakh text and configures natural prosody on FlutterTts', () async {
      final fakeTts = _FakeFlutterTts(
        availableVoices: const [
          {'name': 'ru-ru-x-dfc-local', 'locale': 'ru-RU'},
          {'name': 'kk-kz-neural-aigul', 'locale': 'kk-KZ'},
        ],
        availableLanguages: const {'kk-KZ', 'ru-RU'},
      );
      final service = VoiceAccessibilityService(
        tts: fakeTts,
        stt: _FakeSpeechToText(),
      );

      final ok = await service.speak(
        'Қалдық: 245 800 ₸, масштаб 200%, таймер 1,5 сек',
        profile: AccessibilityProfile.standard.copyWith(
          localeCode: 'kk',
          voiceAssistantEnabled: true,
        ),
      );

      expect(ok, isTrue);
      expect(fakeTts.lastLanguage, 'kk-KZ');
      expect(fakeTts.lastVoice?['name'], 'kk-kz-neural-aigul');
      expect(fakeTts.lastSpeechRate, VoiceAccessibilityService.mobileSpeechRate);
      expect(fakeTts.lastPitch, VoiceAccessibilityService.naturalPitch);
      expect(fakeTts.spoken, hasLength(1));
      expect(asciiDigits.hasMatch(fakeTts.spoken.first), isFalse);
      expect(fakeTts.spoken.first, contains('екі жүз қырық бес мың сегіз жүз теңге'));
      expect(fakeTts.spoken.first, contains('екі жүз пайыз'));
      expect(fakeTts.spoken.first, contains('бір бүтін бес секунд'));
    });
  });
}
