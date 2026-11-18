import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../core/accessibility/domain/accessibility_profile.dart';
import '../../core/theme/adaptive_tokens.dart';

enum AdaptiveButtonVariant { primary, secondary, outlined }

/// Adaptive button that automatically adjusts its dimensions, spacing, border
/// thickness and repeat-tap debounce based on [AccessibilityProfile.motorLevel].
///
/// * `standard`: minimum height `52 dp`
/// * `enlargedTargets`: minimum size `64x64 dp`, generous padding, bold border
///   in high-contrast modes
/// * `tremorProtection`: minimum size `72x72 dp`, minimum `16 dp` separation
///   from adjacent interactive elements, and a `600 ms` debounce filter
///
/// Button labels always wrap (`softWrap: true`) without ellipsis.
class AdaptiveActionButton extends ConsumerStatefulWidget {
  const AdaptiveActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.icon,
    this.variant = AdaptiveButtonVariant.primary,
    this.minHeightOverride,
    this.expandWidth = true,
    this.applyTremorSpacing = true,
    this.semanticLabel,
    this.semanticHint,
    this.nowProvider,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AdaptiveButtonVariant variant;
  final double? minHeightOverride;
  final bool expandWidth;
  final bool applyTremorSpacing;
  final String? semanticLabel;
  final String? semanticHint;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<AdaptiveActionButton> createState() =>
      _AdaptiveActionButtonState();
}

class _AdaptiveActionButtonState extends ConsumerState<AdaptiveActionButton> {
  static const Duration _tremorDebounce = Duration(milliseconds: 600);
  DateTime? _lastTapTime;

  void _handleTap(AccessibilityProfile profile, AdaptiveTokens tokens) {
    final callback = widget.onPressed;
    if (callback == null) return;

    if (profile.motorLevel == MotorAssistanceLevel.tremorProtection) {
      final now = (widget.nowProvider ?? DateTime.now)();
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!) < _tremorDebounce) {
        return;
      }
      _lastTapTime = now;
    }

    if (tokens.hapticFeedback) {
      HapticFeedback.selectionClick();
    }
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final motorMinSize = switch (profile.motorLevel) {
      MotorAssistanceLevel.standard => 52.0,
      MotorAssistanceLevel.enlargedTargets => 64.0,
      MotorAssistanceLevel.tremorProtection => 72.0,
    };

    final minHeight = widget.minHeightOverride != null
        ? math.max(motorMinSize, widget.minHeightOverride!)
        : motorMinSize;

    final EdgeInsetsGeometry innerPadding = switch (profile.motorLevel) {
      MotorAssistanceLevel.standard => const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      MotorAssistanceLevel.enlargedTargets => const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
      MotorAssistanceLevel.tremorProtection => const EdgeInsets.symmetric(
          horizontal: 26,
          vertical: 20,
        ),
    };

    // 8 dp on all sides guarantees >= 16 dp between any two adjacent buttons.
    final outerMargin =
        widget.applyTremorSpacing &&
                profile.motorLevel == MotorAssistanceLevel.tremorProtection
            ? const EdgeInsets.all(8)
            : EdgeInsets.zero;

    final Color bg;
    final Color fg;
    final BorderSide side;

    switch (widget.variant) {
      case AdaptiveButtonVariant.primary:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        side = profile.isHighContrast
            ? BorderSide(color: scheme.outline, width: tokens.borderWidth)
            : BorderSide.none;
      case AdaptiveButtonVariant.secondary:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        side = BorderSide(
          color: scheme.outline,
          width: profile.isHighContrast ? tokens.borderWidth : 1.5,
        );
      case AdaptiveButtonVariant.outlined:
        bg = scheme.surface;
        fg = profile.isHighContrast ? scheme.onSurface : tokens.accentText;
        side = BorderSide(
          color: profile.isHighContrast ? scheme.outline : scheme.primary,
          width: profile.isHighContrast ? tokens.borderWidth : 1.5,
        );
    }

    final isDisabled = widget.onPressed == null;
    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.surfaceContainerHighest.withValues(alpha: 0.6);
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurfaceVariant;
        }
        return fg;
      }),
      minimumSize: WidgetStateProperty.all(
        Size(
          widget.expandWidth ? double.infinity : motorMinSize,
          minHeight,
        ),
      ),
      padding: WidgetStateProperty.all(innerPadding),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cornerRadius),
          side: side,
        ),
      ),
      elevation: WidgetStateProperty.all(
        profile.isHighContrast || widget.variant != AdaptiveButtonVariant.primary
            ? 0
            : 1,
      ),
    );

    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: isDisabled ? scheme.onSurfaceVariant : fg,
      fontWeight: FontWeight.w700,
    );

    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isDisabled ? scheme.onSurfaceVariant : fg.withValues(alpha: 0.9),
    );

    final content = Row(
      mainAxisSize: widget.expandWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          ExcludeSemantics(
            child: Icon(
              widget.icon,
              size: tokens.iconSize,
              color: isDisabled ? scheme.onSurfaceVariant : fg,
            ),
          ),
          SizedBox(width: tokens.spacingUnit * 1.5),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: widget.icon != null && widget.subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: labelStyle,
                softWrap: true,
                textAlign: widget.icon != null && widget.subtitle != null
                    ? TextAlign.start
                    : TextAlign.center,
              ),
              if (widget.subtitle != null) ...[
                SizedBox(height: tokens.spacingUnit * 0.5),
                Text(
                  widget.subtitle!,
                  style: subtitleStyle,
                  softWrap: true,
                  textAlign: widget.icon != null
                      ? TextAlign.start
                      : TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: outerMargin,
      child: Semantics(
        button: true,
        enabled: !isDisabled,
        label: widget.semanticLabel ?? widget.label,
        hint: widget.semanticHint,
        child: ElevatedButton(
          onPressed: isDisabled ? null : () => _handleTap(profile, tokens),
          style: style,
          child: content,
        ),
      ),
    );
  }
}
