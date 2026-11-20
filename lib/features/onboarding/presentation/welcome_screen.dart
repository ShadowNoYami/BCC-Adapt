import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/adaptive_tokens.dart';
import '../../../core/voice/application/voice_accessibility_service.dart';
import '../../../shared/widgets/adaptive_action_button.dart';
import '../../../shared/widgets/bcc_logo.dart';
import '../../../shared/widgets/voice_guide_header.dart';

/// Screen 1: Accessible entry screen solving the "inaccessible onboarding"
/// problem.
///
/// Features a dominant high-contrast hero button-card in the upper half of the
/// screen, a prominent `РУС / ҚАЗ` switcher, a standard-mode skip button at
/// the bottom, and a Zero-Touch Audio Prompt that speaks a welcome instruction
/// after 4.5 seconds of inactivity (respecting TalkBack Guard).
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({
    super.key,
    this.zeroTouchDelay = const Duration(milliseconds: 4500),
  });

  /// Delay before the Zero-Touch Audio Prompt fires. Overridable in tests.
  final Duration zeroTouchDelay;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Timer? _promptTimer;
  bool _hasInteracted = false;
  late final VoiceAccessibilityService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceAccessibilityServiceProvider);
    _scheduleZeroTouchPrompt();
  }

  void _scheduleZeroTouchPrompt() {
    _promptTimer?.cancel();
    _promptTimer = Timer(widget.zeroTouchDelay, _onZeroTouchTimeout);
  }

  Future<void> _onZeroTouchTimeout() async {
    // Browsers require a user gesture before starting speech.
    if (!mounted || _hasInteracted || kIsWeb) return;
    final profile = ref.read(currentAccessibilityProfileProvider);
    final mqAccessible = MediaQuery.accessibleNavigationOf(context);
    if (profile.screenReaderActive || mqAccessible) return;

    final strings = ref.read(appStringsProvider);
    await ref
        .read(voiceSessionProvider.notifier)
        .speak(
          strings.welcomeZeroTouchVoicePrompt,
          context: context,
          force: true,
        );
  }

  void _cancelZeroTouchPrompt() {
    if (_hasInteracted) return;
    _hasInteracted = true;
    _promptTimer?.cancel();
    _promptTimer = null;
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _promptTimer = null;
    _voiceService.stopAll();
    super.dispose();
  }

  Future<void> _openCalibration() async {
    _cancelZeroTouchPrompt();
    await ref.read(voiceSessionProvider.notifier).stopAll();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.calibration);
  }

  Future<void> _continueStandard() async {
    _cancelZeroTouchPrompt();
    await ref.read(voiceSessionProvider.notifier).stopAll();
    if (!mounted) return;
    await Navigator.of(context).pushNamed(AppRoutes.registration);
  }

  Future<void> _playWelcomeHint(AppStrings strings) async {
    _cancelZeroTouchPrompt();
    final spoken = await ref
        .read(voiceSessionProvider.notifier)
        .speak(
          strings.welcomeZeroTouchVoicePrompt,
          context: context,
          force: true,
        );
    if (!spoken && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.welcomeSpeechUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _cancelZeroTouchPrompt(),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroMinHeight = math.max(
                140.0,
                math.min(constraints.maxHeight * 0.38, 280.0),
              );

              return SingleChildScrollView(
                padding: EdgeInsets.all(tokens.spacingUnit * 2),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      constraints.maxHeight - tokens.spacingUnit * 4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Bar: BCC Bank Logo + Large РУС / ҚАЗ Switcher
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: tokens.spacingUnit * 1.5,
                              runSpacing: tokens.spacingUnit * 1.5,
                              children: [
                                const BccLogo(),
                                LanguageSwitchButton(
                                  onBeforeSwitch: _cancelZeroTouchPrompt,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: tokens.spacingUnit * 2.5),

                          // Dominant Hero Button-Card (>= 110 dp, upper half)
                          _HeroAccessibilityCard(
                            minHeight: heroMinHeight,
                            title: strings.welcomeConfigureTitle,
                            subtitle: strings.welcomeConfigureSubtitle,
                            onTap: _openCalibration,
                          ),
                          SizedBox(height: tokens.spacingUnit * 2.5),

                          // Friendly greeting text
                          Text(
                            strings.welcomeTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                            softWrap: true,
                          ),
                          SizedBox(height: tokens.spacingUnit),
                          Text(
                            strings.welcomeSubtitle,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            softWrap: true,
                          ),
                          if (profile.screenReaderActive ||
                              MediaQuery.accessibleNavigationOf(context)) ...[
                            SizedBox(height: tokens.spacingUnit * 1.5),
                            Container(
                              padding: EdgeInsets.all(tokens.spacingUnit * 1.5),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outline),
                              ),
                              child: Text(
                                kIsWeb
                                    ? strings.browserAccessibilityNotice
                                    : strings.talkBackGuardActiveNotice,
                                style: theme.textTheme.bodyMedium,
                                softWrap: true,
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: tokens.spacingUnit * 1.5),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: Size(48, tokens.minTouchTarget),
                                ),
                                onPressed: () => _playWelcomeHint(strings),
                                icon: const Icon(Icons.volume_up_rounded),
                                label: Text(strings.repeatVoiceButton),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Secondary bottom action: Continue in standard mode
                      Padding(
                        padding: EdgeInsets.only(top: tokens.spacingUnit * 3),
                        child: AdaptiveActionButton(
                          label: strings.welcomeStandardModeButton,
                          variant: AdaptiveButtonVariant.outlined,
                          onPressed: _continueStandard,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroAccessibilityCard extends ConsumerWidget {
  const _HeroAccessibilityCard({
    required this.minHeight,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double minHeight;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final borderRadius = BorderRadius.circular(20);
    final iconBadgeSize = 32.0 + (profile.textScaleFactor - 1) * 8;

    return Material(
      color: scheme.primary,
      elevation: profile.isHighContrast ? 0 : 4,
      shadowColor: scheme.primary.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: profile.isHighContrast ? scheme.outline : scheme.primary,
          width: profile.isHighContrast ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (tokens.hapticFeedback) {
            HapticFeedback.mediumImpact();
          }
          onTap();
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(110.0, minHeight)),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacingUnit * 2.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eye + Ear high-contrast icon pair (decorative)
                ExcludeSemantics(
                  child: Wrap(
                    spacing: tokens.spacingUnit * 1.5,
                    runSpacing: tokens.spacingUnit,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(tokens.spacingUnit * 1.25),
                        decoration: BoxDecoration(
                          color: scheme.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: profile.isHighContrast
                              ? Border.all(color: scheme.onPrimary, width: 2)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              color: scheme.onPrimary,
                              size: iconBadgeSize,
                            ),
                            SizedBox(width: tokens.spacingUnit),
                            Icon(
                              Icons.hearing_rounded,
                              color: scheme.onPrimary,
                              size: iconBadgeSize,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacingUnit * 2),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  softWrap: true,
                ),
                SizedBox(height: tokens.spacingUnit),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.94),
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                      ),
                    ),
                    SizedBox(width: tokens.spacingUnit),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.onPrimary,
                        size: iconBadgeSize,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
