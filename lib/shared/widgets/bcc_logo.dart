import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/accessibility/application/accessibility_profile_notifier.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/adaptive_tokens.dart';

/// Accessible BCC Bank brand badge that adapts cleanly to high-contrast modes
/// and scales up to 200% without clipping.
class BccLogo extends ConsumerWidget {
  const BccLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentAccessibilityProfileProvider);
    final strings = ref.watch(appStringsProvider);
    final tokens = AdaptiveTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final badgeSize = compact
        ? 38.0
        : 44.0 + (profile.textScaleFactor - 1) * 10;

    return Semantics(
      label: '${strings.bankName} — ${strings.appTitle}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(compact ? 10 : 12),
              border: profile.isHighContrast
                  ? Border.all(
                      color: scheme.outline,
                      width: tokens.borderWidth,
                    )
                  : null,
            ),
            child: Icon(
              Icons.account_balance_rounded,
              color: scheme.onPrimary,
              size: badgeSize * 0.56,
              semanticLabel: '',
            ),
          ),
          SizedBox(width: compact ? 8 : tokens.spacingUnit * 1.25),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.appTitle,
                  style: (compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                  softWrap: true,
                ),
                Text(
                  strings.bankName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
