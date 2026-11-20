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
  final IconData? prefixIcon;
  final String? suffixText;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdaptiveTokens.of(context);
    final textStyle = Theme.of(context).textTheme.titleMedium;
    final field = TextField(
      controller: controller,
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
      ),
    );

    if (!externalLabel) return field;

    return Column(
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
  }
}
