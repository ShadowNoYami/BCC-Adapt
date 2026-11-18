import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../core/accessibility/domain/accessibility_profile.dart';
import '../../core/theme/adaptive_tokens.dart';

/// Adaptive card container supporting standard and WCAG 2.1 AAA high-contrast
/// modes (`highContrastLight` / `highContrastDark`) with explicit `2px`
/// borders and clear surface separation.
class AdaptiveCard extends ConsumerStatefulWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.semanticLabel,
    this.semanticHint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  ConsumerState<AdaptiveCard> createState() => _AdaptiveCardState();
}

class _AdaptiveCardState extends ConsumerState<AdaptiveCard> {
  static const Duration _tremorDebounce = Duration(milliseconds: 600);
  DateTime? _lastTapTime;

  void _handleTap(AccessibilityProfile profile, AdaptiveTokens tokens) {
    final callback = widget.onTap;
    if (callback == null) return;

    if (profile.motorLevel == MotorAssistanceLevel.tremorProtection) {
      final now = DateTime.now();
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
    final scheme = Theme.of(context).colorScheme;

    final isHc = profile.isHighContrast;
    final resolvedBorderWidth = widget.selected
        ? (isHc ? 3.5 : 2.5)
        : (isHc ? tokens.borderWidth : 1.0);

    final resolvedBorderColor = widget.borderColor ??
        (widget.selected
            ? (profile.isDark ? tokens.emphasis : scheme.primary)
            : (isHc ? scheme.outline : scheme.outlineVariant));

    final resolvedBg = widget.backgroundColor ??
        (widget.selected && !isHc
            ? scheme.primaryContainer
            : (isHc ? scheme.surfaceContainer : scheme.surface));

    final effectivePadding = widget.padding ??
        EdgeInsets.all(tokens.spacingUnit * 2);

    final outerMargin = widget.margin ??
        (profile.motorLevel == MotorAssistanceLevel.tremorProtection &&
                widget.onTap != null
            ? const EdgeInsets.symmetric(vertical: 8)
            : EdgeInsets.zero);

    final borderRadius = BorderRadius.circular(tokens.cornerRadius);

    Widget content = Container(
      constraints: BoxConstraints(
        minHeight: widget.onTap != null ? profile.minTouchTarget : 0,
      ),
      padding: effectivePadding,
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = InkWell(
        borderRadius: borderRadius,
        onTap: () => _handleTap(profile, tokens),
        child: content,
      );
    }

    return Padding(
      padding: outerMargin,
      child: Semantics(
        container: true,
        button: widget.onTap != null,
        selected: widget.selected,
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        child: Material(
          color: resolvedBg,
          elevation: isHc ? 0 : (widget.selected ? 2 : 0.5),
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: resolvedBorderColor,
              width: resolvedBorderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}
