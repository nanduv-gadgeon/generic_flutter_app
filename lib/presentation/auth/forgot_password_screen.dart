import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/validation/auth_rules.dart';
import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'auth_form.dart';
import 'auth_validators.dart';

/// Forgot password (Phase 1): email and a new password on one form. Saving asks for the phone's
/// own screen lock (Face ID, fingerprint, PIN or passcode), then goes back to login.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .resetPassword(_email.text.trim(), _password.text, reason: AuthStrings.resetReason);
      switch (result) {
        case ResetSuccess():
          messenger.showSnackBar(const SnackBar(content: Text(AuthStrings.passwordChanged)));
          if (mounted) context.go('/login');
        case NoScreenLock():
          _showError(AuthStrings.noScreenLock);
        case OwnerNotVerified():
          _showError(AuthStrings.ownerNotVerified);
        case NoAccountForEmail():
          _showError(AuthStrings.noAccountForEmail);
      }
    } catch (_) {
      _showError(AuthStrings.resetFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _back() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuthBackButton(onPressed: _back),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      AuthStrings.resetPassword,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(AuthStrings.resetSubtitle, style: TextStyle(fontSize: 15, color: muted)),
                  const SizedBox(height: 20),
                  ..._fields(),
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    AuthErrorMessage(error),
                  ],
                  const SizedBox(height: 20),
                  AuthSubmitButton(
                    label: AuthStrings.resetPassword,
                    busyLabel: AuthStrings.resettingPassword,
                    busy: _busy,
                    onPressed: _reset,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() => [
    LabeledField(
      label: CommonStrings.email,
      child: TextFormField(
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: CommonStrings.emailHint),
        validator: AuthValidators.email,
      ),
    ),
    const SizedBox(height: 14),
    PasswordField(
      controller: _password,
      enabled: !_busy,
      label: AuthStrings.newPassword,
      hint: AuthStrings.newPasswordHint(minPasswordLength),
      autofillHints: const [AutofillHints.newPassword],
      validator: AuthValidators.newPassword,
    ),
    const SizedBox(height: 14),
    PasswordField(
      controller: _confirm,
      enabled: !_busy,
      label: AuthStrings.confirmPassword,
      hint: AuthStrings.confirmPasswordHint,
      autofillHints: const [AutofillHints.newPassword],
      validator: AuthValidators.confirmPassword(() => _password.text),
      onSubmitted: (_) => _reset(),
    ),
  ];
}
