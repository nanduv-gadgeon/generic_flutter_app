import 'package:flutter/material.dart';

import 'labeled_field.dart';
import '../../l10n/l10n.dart';

/// Password input with its label above and a show / hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.enabled = true,
    this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Default: "Password".
  final String? label;

  /// Default: "Enter password".
  final String? hint;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label ?? context.l10n.commonPassword,
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscured,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint ?? context.l10n.commonPasswordHint,
          suffixIcon: IconButton(
            tooltip: _obscured ? context.l10n.commonShowPassword : context.l10n.commonHidePassword,
            icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
        ),
      ),
    );
  }
}
