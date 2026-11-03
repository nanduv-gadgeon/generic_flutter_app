import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/dial_code.dart';
import '../../domain/services/auth_service.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'auth_form.dart';
import 'mobile_number_field.dart';

const minPasswordLength = 8;

/// Creates a local account; on success the user is logged in and the router goes home.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  // Starts on the phone's region; the user can pick another.
  DialCode _dialCode = defaultDialCode(WidgetsBinding.instance.platformDispatcher.locale);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _mobile, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    // Captured now: on success the router replaces this screen.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            RegistrationData(
              name: _name.text,
              email: _email.text.trim(),
              mobile: fullMobileNumber(_dialCode, _mobile.text),
              password: _password.text,
              termsAccepted: true,
            ),
          );
      messenger.showSnackBar(const SnackBar(content: Text('Account created')));
    } on EmailAlreadyUsedException {
      _showError('An account with this email already exists.');
    } catch (_) {
      _showError('Could not create your account. Try again.');
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
                    child: _BackButton(onPressed: _back),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      'Create account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Register to add and monitor your devices.',
                    style: TextStyle(fontSize: 15, color: muted),
                  ),
                  const SizedBox(height: 20),
                  ..._fields(),
                  const SizedBox(height: 14),
                  _TermsField(enabled: !_busy),
                  if (_error case final error?) ...[
                    const SizedBox(height: 8),
                    AuthErrorMessage(error),
                  ],
                  const SizedBox(height: 20),
                  AuthSubmitButton(
                    label: 'Create account',
                    busyLabel: 'Creating account',
                    busy: _busy,
                    onPressed: _register,
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
      label: 'Full name',
      child: TextFormField(
        controller: _name,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: 'Your name'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
      ),
    ),
    const SizedBox(height: 14),
    LabeledField(
      label: 'Email',
      child: TextFormField(
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: 'you@example.com'),
        validator: (v) =>
            emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address.',
      ),
    ),
    const SizedBox(height: 14),
    MobileNumberField(
      controller: _mobile,
      dialCode: _dialCode,
      enabled: !_busy,
      onDialCodeChanged: (code) => setState(() => _dialCode = code),
    ),
    const SizedBox(height: 14),
    PasswordField(
      controller: _password,
      enabled: !_busy,
      hint: 'At least $minPasswordLength characters',
      autofillHints: const [AutofillHints.newPassword],
      validator: (v) => (v ?? '').length < minPasswordLength
          ? 'Use at least $minPasswordLength characters.'
          : null,
    ),
    const SizedBox(height: 14),
    PasswordField(
      controller: _confirm,
      enabled: !_busy,
      label: 'Confirm password',
      hint: 'Re-enter password',
      autofillHints: const [AutofillHints.newPassword],
      validator: (v) => v == _password.text ? null : 'Passwords do not match.',
      onSubmitted: (_) => _register(),
    ),
  ];
}

/// The 44 px round back button from the mockup.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_left, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: tokens?.surface,
        side: tokens == null ? null : BorderSide(color: tokens.border),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// "I agree to the Terms and Privacy Policy" (plain text until the links exist), required.
class _TermsField extends StatelessWidget {
  const _TermsField({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    return FormField<bool>(
      initialValue: false,
      validator: (v) => v == true ? null : 'Accept the terms to continue.',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: field.value,
            enabled: enabled,
            onChanged: (v) => field.didChange(v),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(
              'I agree to the Terms and Privacy Policy',
              style: TextStyle(fontSize: 14, color: muted),
            ),
          ),
          if (field.errorText case final error?) AuthErrorMessage(error),
        ],
      ),
    );
  }
}
