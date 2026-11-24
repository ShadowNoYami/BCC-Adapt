import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../accessibility/application/accessibility_profile_notifier.dart';
import '../../accessibility/domain/accessibility_profile.dart';
import '../domain/speech_text_normalizer.dart';
import '../domain/voice_transfer_parser.dart';

enum VoiceListeningStatus {
  idle,
  initializing,
  listening,
  completed,
  permissionDenied,
  unavailable,
  error,
}

@immutable
class VoiceSessionState {
  const VoiceSessionState({
    this.status = VoiceListeningStatus.idle,
    this.recognizedText = '',
    this.isFinalResult = false,
    this.isSpeaking = false,
    this.soundLevel = 0.0,
    this.errorMessage,
    this.parsedIntent,
  });

  final VoiceListeningStatus status;
  final String recognizedText;
  final bool isFinalResult;
  final bool isSpeaking;
  final double soundLevel;
  final String? errorMessage;
  final VoiceTransferIntent? parsedIntent;

  bool get isListening => status == VoiceListeningStatus.listening;

  VoiceSessionState copyWith({
    VoiceListeningStatus? status,
    String? recognizedText,
    bool? isFinalResult,
    bool? isSpeaking,
    double? soundLevel,
    String? errorMessage,
    bool clearError = false,
    VoiceTransferIntent? parsedIntent,
    bool clearIntent = false,
  }) {
    return VoiceSessionState(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
      isFinalResult: isFinalResult ?? this.isFinalResult,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      soundLevel: soundLevel ?? this.soundLevel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      parsedIntent: clearIntent ? null : (parsedIntent ?? this.parsedIntent),
    );
  }
}

/// Safe voice accessibility service with TalkBack Guard and Push-to-Talk STT.
class VoiceAccessibilityService {
  VoiceAccessibilityService({
    FlutterTts? tts,
    SpeechToText? stt,
    VoiceTransferParser? parser,
    SpeechTextNormalizer? normalizer,
  }) : _tts = tts ?? FlutterTts(),
       _stt = stt ?? SpeechToText(),
       _parser = parser ?? const VoiceTransferParser(),
       _normalizer = normalizer ?? const SpeechTextNormalizer() {
    if (kIsWeb) unawaited(_preloadWebVoices());
  }

  /// Silence timeout before Push-to-Talk automatically finalises.
  static const Duration silenceTimeout = Duration(milliseconds: 3500);

  /// Maximum duration of a single Push-to-Talk session.
  static const Duration maxListenDuration = Duration(seconds: 30);

  /// Comfortable human speech rate for mobile TTS engines (Android / iOS).
  static const double mobileSpeechRate = 0.48;

  /// Comfortable human speech rate for Web Speech API.
  static const double webSpeechRate = 0.95;

  /// Slightly warm pitch that sounds natural without monotone robotics.
  static const double naturalPitch = 1.03;

  static const Map<String, int> _voiceQualityWeights = {
    'neural': 100,
    'natural': 95,
    'wavenet': 90,
    'premium': 85,
    'enhanced': 80,
    'aigul': 75,
    'daulet': 75,
    'dariya': 75,
    'svetlana': 75,
    'google': 50,
    'network': 35,
    'online': 30,
    'multilingual': 25,
  };

  final FlutterTts _tts;
  final SpeechToText _stt;
  final VoiceTransferParser _parser;
  final SpeechTextNormalizer _normalizer;

  bool _ttsInitialized = false;
  bool _sttInitialized = false;
  String? _currentTtsLocale;
  Map<String, String>? _selectedVoice;

  /// Pure TalkBack Guard check (unit-testable without platform channels).
  ///
  /// Built-in TTS is strictly blocked whenever:
  /// * `MediaQuery.accessibleNavigationOf(context)` is true, OR
  /// * `profile.screenReaderActive` is true, OR
  /// * `profile.voiceAssistantEnabled` is false (unless `force` is true for
  ///   explicit user-tapped "Read aloud" buttons, which still obey the
  ///   screen-reader block).
  static bool canSpeak({
    required AccessibilityProfile profile,
    bool mediaQueryAccessibleNavigation = false,
    bool force = false,
  }) {
    if (mediaQueryAccessibleNavigation || profile.screenReaderActive) {
      return false;
    }
    return force || profile.voiceAssistantEnabled;
  }

  /// Speaks [text] aloud if and only if the Anti-Conflict Rule (TalkBack Guard)
  /// permits it. Returns `true` if speech was actually triggered.
  Future<bool> speak(
    String text, {
    required AccessibilityProfile profile,
    BuildContext? context,
    bool force = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final mqAccessible =
        context != null &&
        context.mounted &&
        MediaQuery.accessibleNavigationOf(context);

    if (!canSpeak(
      profile: profile,
      mediaQueryAccessibleNavigation: mqAccessible,
      force: force,
    )) {
      return false;
    }

    try {
      // Never speak while the microphone is listening.
      if (_stt.isListening) {
        await _stt.stop();
      }
      await stopSpeaking();
      final normalized = _normalizer.normalize(
        trimmed,
        localeCode: profile.localeCode,
      );
      if (normalized.isEmpty) return false;
      if (!await _ensureTtsConfigured(profile.localeCode)) return false;
      await _tts.speak(normalized);
      return true;
    } catch (e, st) {
      debugPrint('VoiceAccessibilityService.speak error: $e\n$st');
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    if (!_ttsInitialized) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('VoiceAccessibilityService.stopSpeaking error: $e');
    }
  }

  /// Requests microphone permission safely via `permission_handler`.
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final request = Permission.microphone.request();
      final result = await (kIsWeb
          ? request.timeout(
              const Duration(seconds: 8),
              onTimeout: () => PermissionStatus.denied,
            )
          : request);
      return result.isGranted;
    } catch (e) {
      debugPrint('Microphone permission check failed: $e');
      return false;
    }
  }

  /// Starts a Push-to-Talk listening session with a 3.5 s silence timeout
  /// and automatic `ru-RU` / `kk-KZ` locale selection.
  Future<VoiceListeningStatus> startListening({
    required String localeCode,
    required void Function(String text, bool isFinal) onResult,
    void Function(double soundLevel)? onSoundLevel,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    final granted = await requestMicrophonePermission();
    if (!granted) {
      return VoiceListeningStatus.permissionDenied;
    }

    try {
      await stopSpeaking();
      if (!_sttInitialized) {
        _sttInitialized = await _stt.initialize(
          onStatus: onStatus,
          onError: (SpeechRecognitionError err) => onError?.call(err.errorMsg),
        );
      }
      if (!_sttInitialized || !_stt.isAvailable) {
        return VoiceListeningStatus.unavailable;
      }

      final sttLocale = await _resolveSttLocaleId(localeCode);

      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevel,
        listenOptions: SpeechListenOptions(
          localeId: sttLocale,
          pauseFor: silenceTimeout,
          listenFor: maxListenDuration,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
      return VoiceListeningStatus.listening;
    } catch (e, st) {
      debugPrint('VoiceAccessibilityService.startListening error: $e\n$st');
      onError?.call(e.toString());
      return VoiceListeningStatus.error;
    }
  }

  Future<void> stopListening() async {
    try {
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (e) {
      debugPrint('VoiceAccessibilityService.stopListening error: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_stt.isListening) {
        await _stt.cancel();
      }
    } catch (e) {
      debugPrint('VoiceAccessibilityService.cancelListening error: $e');
    }
  }

  /// Guarantees both active TTS speech (`flutter_tts.stop()`) and active STT
  /// microphone listening (`speech_to_text.stop()`) are interrupted immediately
  /// when closing a screen or switching routes.
  Future<void> stopAll() async {
    await stopSpeaking();
    await stopListening();
  }

  VoiceTransferIntent parseTransferIntent(
    String recognizedText, {
    String localeCode = 'ru',
  }) {
    return _parser.parse(recognizedText, localeCode: localeCode);
  }

  Future<void> _preloadWebVoices() async {
    try {
      // Chromium loads voices asynchronously after the first query.
      await _tts.getVoices;
    } catch (e) {
      debugPrint('Could not preload browser voices: $e');
    }
  }

  /// Selects the most natural / neural TTS voice for [localeCode] (`'kk'` or
  /// `'ru'`) from the raw list returned by `FlutterTts.getVoices`.
  ///
  /// When [localeCode] is `'kk'` and the device has no installed Kazakh voice,
  /// falls back softly to the highest-quality multilingual or Russian voice —
  /// because [SpeechTextNormalizer] converts all digits into Kazakh words first,
  /// the utterance still sounds natural and fully Kazakh.
  static Map<String, String>? selectBestVoice(
    Iterable<dynamic> rawVoices, {
    required String localeCode,
  }) {
    final isKk = localeCode == 'kk';
    final parsed = <_VoiceCandidate>[];

    for (final item in rawVoices) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      final locale = (item['locale'] ?? item['lang'] ?? '').toString().trim();
      if (name.isEmpty || locale.isEmpty) continue;
      final identifier = (item['identifier'] ?? '').toString().trim();
      final quality = (item['quality'] ?? '').toString().trim();
      parsed.add(
        _VoiceCandidate(
          name: name,
          locale: locale,
          identifier: identifier,
          quality: quality,
        ),
      );
    }

    if (parsed.isEmpty) return null;

    final primary = <_VoiceCandidate>[];
    final fallback = <_VoiceCandidate>[];

    for (final voice in parsed) {
      final normLocale = voice.normalizedLocale;
      if (isKk) {
        if (normLocale == 'kk' || normLocale.startsWith('kk-')) {
          primary.add(voice);
        } else if (normLocale == 'ru' ||
            normLocale.startsWith('ru-') ||
            voice.meta.contains('multilingual')) {
          fallback.add(voice);
        }
      } else {
        if (normLocale == 'ru' || normLocale.startsWith('ru-')) {
          primary.add(voice);
        } else if (voice.meta.contains('multilingual')) {
          fallback.add(voice);
        }
      }
    }

    final candidates = primary.isNotEmpty ? primary : fallback;
    if (candidates.isEmpty) return null;

    _VoiceCandidate best = candidates.first;
    var bestScore = _scoreVoice(best, localeCode: localeCode);
    for (var i = 1; i < candidates.length; i++) {
      final candidate = candidates[i];
      final score = _scoreVoice(candidate, localeCode: localeCode);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }

    return {'name': best.name, 'locale': best.locale};
  }

  static int _scoreVoice(
    _VoiceCandidate voice, {
    required String localeCode,
  }) {
    final meta = voice.meta;
    var score = 0;

    for (final entry in _voiceQualityWeights.entries) {
      if (meta.contains(entry.key)) {
        score += entry.value;
      }
    }

    final normLocale = voice.normalizedLocale;
    if (localeCode == 'kk' && normLocale == 'kk-kz') {
      score += 20;
    } else if (normLocale == 'ru-ru') {
      score += 20;
    }

    if (meta.contains('espeak')) score -= 80;
    if (meta.contains('legacy')) score -= 30;
    if (meta.contains('compact')) score -= 20;

    return score;
  }

  Future<bool> _ensureTtsConfigured(String localeCode) async {
    final normalizedLocale = localeCode == 'kk' ? 'kk' : 'ru';
    final needsConfigure =
        !_ttsInitialized ||
        _currentTtsLocale != normalizedLocale ||
        (kIsWeb && _selectedVoice == null);

    if (!needsConfigure) {
      return true;
    }

    final bestVoice = await _findBestInstalledVoice(normalizedLocale);

    String effectiveLocale;
    if (bestVoice != null) {
      effectiveLocale = bestVoice['locale']!;
    } else if (normalizedLocale == 'kk') {
      final kkAvailable = await _isLanguageAvailableSafe('kk-KZ');
      if (kkAvailable == true) {
        effectiveLocale = 'kk-KZ';
      } else {
        // Soft fallback to Russian voice when kk-KZ is absent on the device.
        final ruAvailable = await _isLanguageAvailableSafe('ru-RU');
        if (kIsWeb && ruAvailable != true) {
          return false;
        }
        effectiveLocale = 'ru-RU';
      }
    } else {
      final ruAvailable = await _isLanguageAvailableSafe('ru-RU');
      if (kIsWeb && ruAvailable != true) {
        return false;
      }
      effectiveLocale = 'ru-RU';
    }

    await _tts.setLanguage(effectiveLocale);
    if (bestVoice != null) {
      try {
        await _tts.setVoice(bestVoice);
      } catch (e) {
        debugPrint('VoiceAccessibilityService.setVoice fallback: $e');
      }
    }

    // Apply warm human prosody after language/voice selection so engines that
    // reset rate/pitch on locale switches preserve natural pacing.
    await _tts.setSpeechRate(kIsWeb ? webSpeechRate : mobileSpeechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(naturalPitch);

    _ttsInitialized = true;
    _currentTtsLocale = normalizedLocale;
    _selectedVoice = bestVoice;
    return true;
  }

  Future<Map<String, String>?> _findBestInstalledVoice(
    String localeCode,
  ) async {
    try {
      final raw = await _tts.getVoices;
      if (raw is Iterable) {
        return selectBestVoice(raw, localeCode: localeCode);
      }
    } catch (e) {
      debugPrint('VoiceAccessibilityService.getVoices failed: $e');
    }
    return null;
  }

  Future<bool?> _isLanguageAvailableSafe(String localeTag) async {
    try {
      final available = await _tts.isLanguageAvailable(localeTag);
      if (available is bool) return available;
      if (available is num) return available > 0;
    } catch (e) {
      debugPrint('VoiceAccessibilityService.isLanguageAvailable failed: $e');
    }
    return null;
  }

  Future<String> _resolveSttLocaleId(String localeCode) async {
    final preferred = localeCode == 'kk' ? 'kk-KZ' : 'ru-RU';
    final fallback = localeCode == 'kk' ? 'kk_KZ' : 'ru_RU';
    try {
      final locales = await _stt.locales();
      for (final l in locales) {
        final id = l.localeId.replaceAll('_', '-').toLowerCase();
        if (id == preferred.toLowerCase()) return l.localeId;
      }
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith(localeCode.toLowerCase())) {
          return l.localeId;
        }
      }
    } catch (_) {
      // Ignore and return preferred code.
    }
    return fallback.replaceAll('_', '-');
  }

  void dispose() {
    unawaited(stopSpeaking());
    unawaited(cancelListening());
  }
}

/// Riverpod notifier managing the reactive Push-to-Talk + TTS session state.
class VoiceSessionNotifier extends Notifier<VoiceSessionState> {
  VoiceAccessibilityService get _service =>
      ref.read(voiceAccessibilityServiceProvider);

  @override
  VoiceSessionState build() => const VoiceSessionState();

  Future<bool> speak(
    String text, {
    BuildContext? context,
    bool force = false,
  }) async {
    final profile = ref.read(currentAccessibilityProfileProvider);
    state = state.copyWith(isSpeaking: true, clearError: true);
    final spoken = await _service.speak(
      text,
      profile: profile,
      context: context,
      force: force,
    );
    if (ref.mounted) state = state.copyWith(isSpeaking: false);
    return spoken;
  }

  Future<void> stopSpeaking() async {
    await _service.stopSpeaking();
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> startPushToTalk() async {
    final profile = ref.read(currentAccessibilityProfileProvider);
    state = state.copyWith(
      status: VoiceListeningStatus.initializing,
      recognizedText: '',
      isFinalResult: false,
      clearError: true,
      clearIntent: true,
    );

    final status = await _service.startListening(
      localeCode: profile.localeCode,
      onResult: (words, isFinal) {
        final intent = _service.parseTransferIntent(
          words,
          localeCode: profile.localeCode,
        );
        state = state.copyWith(
          status: isFinal
              ? VoiceListeningStatus.completed
              : VoiceListeningStatus.listening,
          recognizedText: words,
          isFinalResult: isFinal,
          parsedIntent: intent,
        );
      },
      onSoundLevel: (level) => state = state.copyWith(soundLevel: level),
      onStatus: (rawStatus) {
        if (rawStatus == 'done' || rawStatus == 'notListening') {
          if (state.status == VoiceListeningStatus.listening) {
            state = state.copyWith(
              status: VoiceListeningStatus.completed,
              isFinalResult: true,
            );
          }
        }
      },
      onError: (msg) {
        state = state.copyWith(
          status: VoiceListeningStatus.error,
          errorMessage: msg,
        );
      },
    );

    if (status != VoiceListeningStatus.listening) {
      state = state.copyWith(status: status);
    } else if (state.status == VoiceListeningStatus.initializing) {
      state = state.copyWith(status: VoiceListeningStatus.listening);
    }
  }

  Future<void> stopPushToTalk() async {
    await _service.stopListening();
    if (state.status == VoiceListeningStatus.listening) {
      state = state.copyWith(
        status: VoiceListeningStatus.completed,
        isFinalResult: true,
      );
    }
  }

  /// Interrupts both active speech and active microphone listening on route
  /// transitions or screen disposal.
  Future<void> stopAll() async {
    final wasListening =
        state.status == VoiceListeningStatus.listening ||
        state.status == VoiceListeningStatus.initializing;
    await _service.stopAll();
    if (state.isSpeaking || wasListening) {
      state = state.copyWith(
        isSpeaking: false,
        status: wasListening ? VoiceListeningStatus.idle : state.status,
      );
    }
  }

  void simulateVoiceInput(String phrase) {
    final profile = ref.read(currentAccessibilityProfileProvider);
    final intent = _service.parseTransferIntent(
      phrase,
      localeCode: profile.localeCode,
    );
    state = state.copyWith(
      status: VoiceListeningStatus.completed,
      recognizedText: phrase,
      isFinalResult: true,
      parsedIntent: intent,
      clearError: true,
    );
  }

  void resetSession() {
    state = const VoiceSessionState();
  }
}

class _VoiceCandidate {
  const _VoiceCandidate({
    required this.name,
    required this.locale,
    required this.identifier,
    required this.quality,
  });

  final String name;
  final String locale;
  final String identifier;
  final String quality;

  String get normalizedLocale => locale.replaceAll('_', '-').toLowerCase();

  String get meta => '$name $identifier $quality $locale'.toLowerCase();
}

final voiceTransferParserProvider = Provider<VoiceTransferParser>(
  (ref) => const VoiceTransferParser(),
);

final speechTextNormalizerProvider = Provider<SpeechTextNormalizer>(
  (ref) => const SpeechTextNormalizer(),
);

final voiceAccessibilityServiceProvider = Provider<VoiceAccessibilityService>((
  ref,
) {
  final service = VoiceAccessibilityService(
    parser: ref.watch(voiceTransferParserProvider),
    normalizer: ref.watch(speechTextNormalizerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, VoiceSessionState>(
      VoiceSessionNotifier.new,
    );
