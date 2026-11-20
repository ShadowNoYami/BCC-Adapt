import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/accessibility/application/accessibility_profile_notifier.dart';
import 'core/l10n/app_strings.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme_builder.dart';
import 'core/voice/application/voice_accessibility_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: BccAdaptApp(),
    ),
  );
}

/// Root application widget wired to [accessibilityProfileProvider] and
/// [AppThemeBuilder].
///
/// Waits for the initial profile read from secure storage before mounting the
/// main [Navigator], then starts on [AppRoutes.home] if
/// `isOnboardingCompleted == true` or [AppRoutes.welcome] otherwise.
class BccAdaptApp extends ConsumerStatefulWidget {
  const BccAdaptApp({super.key});

  @override
  ConsumerState<BccAdaptApp> createState() => _BccAdaptAppState();
}

class _BccAdaptAppState extends ConsumerState<BccAdaptApp> {
  String? _resolvedInitialRoute;
  late final VoiceRouteObserver _voiceRouteObserver;

  @override
  void initState() {
    super.initState();
    _voiceRouteObserver = VoiceRouteObserver(() {
      ref.read(voiceSessionProvider.notifier).stopAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(accessibilityProfileProvider);
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final theme = AppThemeBuilder.build(profile);

    if (_resolvedInitialRoute == null && !asyncProfile.isLoading) {
      _resolvedInitialRoute = profile.isOnboardingCompleted
          ? AppRoutes.home
          : AppRoutes.welcome;
    }

    if (_resolvedInitialRoute == null) {
      return MaterialApp(
        title: strings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      key: const ValueKey('bcc_adapt_navigator_app'),
      title: strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: Locale(profile.localeCode),
      supportedLocales: const [
        Locale('ru'),
        Locale('kk'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Text scale is already applied deterministically inside AppThemeBuilder
        // (1.0 .. 2.0, step 0.25) so we pin MediaQuery.textScaler to 1.0 to
        // prevent double-scaling.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: _resolvedInitialRoute,
      onGenerateInitialRoutes: (name) => [
        AppRoutes.onGenerateRoute(RouteSettings(name: name)),
      ],
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [_voiceRouteObserver],
    );
  }
}
