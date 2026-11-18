import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../accessibility/application/accessibility_profile_notifier.dart';
import '../../accessibility/domain/accessibility_profile.dart';
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
  })  : _tts = tts ?? FlutterTts(),
        _stt = stt ?? SpeechToText(),
        _parser = parser ?? const VoiceTransferParser();

  /// Silence timeout before Push-to-Talk automatically finalises.
  static const Duration silenceTimeout = Duration(milliseconds: 3500);

  /// Maximum duration of a single Push-to-Talk session.
  static const Duration maxListenDuration = Duration(seconds: 30);

  final FlutterTts _tts;
  final SpeechToText _stt;
  final VoiceTransferParser _parser;

  bool _ttsInitialized = false;
  bool _sttInitialized = false;
  String? _currentTtsLocale;

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

    final mqAccessible = context != null &&
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
      await _ensureTtsConfigured(profile.localeCode);
      await _tts.stop();
      await _tts.speak(trimmed);
      return true;
    } catch (e, st) {
      debugPrint('VoiceAccessibilityService.speak error: $e\n$st');
      return false;
    }
  }

  Future<void> stopSpeaking() async {
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
      final result = await Permission.microphone.request();
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

  Future<void> _ensureTtsConfigured(String localeCode) async {
    final targetLocale = localeCode == 'kk' ? 'kk-KZ' : 'ru-RU';
    if (!_ttsInitialized) {
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsInitialized = true;
    }
    if (_currentTtsLocale != targetLocale) {
      await _tts.setLanguage(targetLocale);
      _currentTtsLocale = targetLocale;
    }
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
    _tts.stop();
    _stt.cancel();
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
    state = state.copyWith(isSpeaking: false);
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
    final wasListening = state.status == VoiceListeningStatus.listening ||
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

final voiceTransferParserProvider = Provider<VoiceTransferParser>(
  (ref) => const VoiceTransferParser(),
);

final voiceAccessibilityServiceProvider = Provider<VoiceAccessibilityService>((
  ref,
) {
  final service = VoiceAccessibilityService(
    parser: ref.watch(voiceTransferParserProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, VoiceSessionState>(
  VoiceSessionNotifier.new,
);
