import 'package:flutter/material.dart';

import '../../features/accessibility_settings/presentation/accessibility_settings_screen.dart';
import '../../features/banking/domain/bank_models.dart';
import '../../features/banking/presentation/home_screen.dart';
import '../../features/banking/presentation/transfer_screen.dart';
import '../../features/onboarding/presentation/adaptive_registration_screen.dart';
import '../../features/onboarding/presentation/calibration_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';

/// Named route table connecting all 6 BCC Adapt screens.
abstract final class AppRoutes {
  static const String home = '/';
  static const String welcome = '/welcome';
  static const String calibration = '/calibration';
  static const String registration = '/registration';
  static const String transfer = '/transfer';
  static const String accessibilitySettings = '/accessibility';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      welcome => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WelcomeScreen(),
        ),
      calibration => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CalibrationScreen(),
        ),
      registration => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AdaptiveRegistrationScreen(),
        ),
      transfer => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => TransferScreen(
            initialContact: settings.arguments is QuickContact
                ? settings.arguments as QuickContact
                : null,
          ),
        ),
      accessibilitySettings => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const AccessibilitySettingsScreen(),
        ),
      _ => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        ),
    };
  }
}

/// Navigator observer that guarantees active TTS speech and STT microphone
/// listening are interrupted whenever a route is pushed, popped, or replaced.
class VoiceRouteObserver extends NavigatorObserver {
  VoiceRouteObserver(this._onRouteTransition);

  final VoidCallback _onRouteTransition;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _onRouteTransition();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRouteTransition();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onRouteTransition();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRouteTransition();
  }
}
