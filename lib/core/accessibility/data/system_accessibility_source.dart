import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/system_accessibility_flags.dart';

/// Source of OS accessibility settings + change notifications.
abstract interface class SystemAccessibilitySource {
  SystemAccessibilityFlags read();

  /// Device UI language code (e.g. `ru`, `kk`, `en`).
  String readLanguageCode();

  /// Subscribes to OS-level changes. Returns an unsubscribe callback.
  VoidCallback listen(VoidCallback onChanged);
}

/// Production source based on [PlatformDispatcher] + [WidgetsBindingObserver].
///
/// We observe through [WidgetsBinding] instead of overriding
/// `platformDispatcher.onAccessibilityFeaturesChanged`, because the framework
/// itself relies on that callback.
class PlatformSystemAccessibilitySource implements SystemAccessibilitySource {
  const PlatformSystemAccessibilitySource();

  PlatformDispatcher get _dispatcher =>
      WidgetsBinding.instance.platformDispatcher;

  @override
  SystemAccessibilityFlags read() {
    final features = _dispatcher.accessibilityFeatures;
    return SystemAccessibilityFlags(
      textScaleFactor: _dispatcher.textScaleFactor,
      accessibleNavigation: features.accessibleNavigation,
      boldText: features.boldText,
      highContrast: features.highContrast,
    );
  }

  @override
  String readLanguageCode() => _dispatcher.locale.languageCode;

  @override
  VoidCallback listen(VoidCallback onChanged) {
    final observer = _A11yObserver(onChanged);
    WidgetsBinding.instance.addObserver(observer);
    return () => WidgetsBinding.instance.removeObserver(observer);
  }
}

class _A11yObserver with WidgetsBindingObserver {
  _A11yObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didChangeAccessibilityFeatures() => onChanged();

  @override
  void didChangeTextScaleFactor() => onChanged();
}

/// Static source for tests / previews.
class FakeSystemAccessibilitySource implements SystemAccessibilitySource {
  FakeSystemAccessibilitySource({
    this.flags = SystemAccessibilityFlags.none,
    this.languageCode = 'ru',
  });

  SystemAccessibilityFlags flags;
  String languageCode;
  final List<VoidCallback> _listeners = [];

  /// Simulates the user toggling a setting in OS settings.
  void emit(SystemAccessibilityFlags next) {
    flags = next;
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  @override
  SystemAccessibilityFlags read() => flags;

  @override
  String readLanguageCode() => languageCode;

  @override
  VoidCallback listen(VoidCallback onChanged) {
    _listeners.add(onChanged);
    return () => _listeners.remove(onChanged);
  }
}

final systemAccessibilitySourceProvider = Provider<SystemAccessibilitySource>(
  (ref) => const PlatformSystemAccessibilitySource(),
);
