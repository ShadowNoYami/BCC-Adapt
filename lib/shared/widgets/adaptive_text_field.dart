import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/adaptive_tokens.dart';

/// Moves the label above the field and lets the value wrap at large scales.
class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.externalLabel,
    required this.keyboardType,
    this.focusNode,
    this.errorText,
    this.prefixIcon,
    this.suffixText,
    this.inputFormatters = const [],
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool externalLabel;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final String? errorText;
  final IconData? prefixIcon;
  final String? suffixText;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.titleMedium;
    final hasError = errorText != null && errorText!.trim().isNotEmpty;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: externalLabel ? null : 1,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.singleLineFormatter,
        ...inputFormatters,
      ],
      style: textStyle?.copyWith(fontWeight: FontWeight.w600),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: externalLabel ? null : label,
        hintText: hint,
        hintMaxLines: externalLabel ? 2 : 1,
        prefixIcon: prefixIcon == null || externalLabel
            ? null
            : Icon(prefixIcon, size: tokens.iconSize),
        suffixText: suffixText,
        errorText: hasError ? '' : null,
        errorStyle: hasError ? const TextStyle(fontSize: 0, height: 0.01) : null,
      ),
    );

    final Widget labeledField = !externalLabel
        ? field
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Text(
                  label,
                  style: textStyle?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(height: tokens.spacingUnit),
              Semantics(label: label, child: field),
            ],
          );

    if (!hasError) return labeledField;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        labeledField,
        SizedBox(height: tokens.spacingUnit * 0.75),
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: tokens.iconSize * 0.9,
                ),
              ),
              SizedBox(width: tokens.spacingUnit * 0.75),
              Expanded(
                child: Text(
                  errorText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
