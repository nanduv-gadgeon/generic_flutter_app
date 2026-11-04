import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/dial_code.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/validation/auth_rules.dart';
import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'auth_form.dart';
import 'auth_validators.dart';
import 'mobile_number_field.dart';

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
  DialCode _dialCode = defaultDialCode(
    WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );
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
      messenger.showSnackBar(const SnackBar(content: Text(AuthStrings.accountCreated)));
    } on EmailAlreadyUsedException {
      _showError(AuthStrings.emailInUse);
    } catch (_) {
      _showError(AuthStrings.registerFailed);
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
                      AuthStrings.createAccount,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(AuthStrings.registerSubtitle, style: TextStyle(fontSize: 15, color: muted)),
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
                    label: AuthStrings.createAccount,
                    busyLabel: AuthStrings.creatingAccount,
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
      label: AuthStrings.fullName,
      child: TextFormField(
        controller: _name,
        enabled: !_busy,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: AuthStrings.fullNameHint),
        validator: AuthValidators.name,
      ),
    ),
    const SizedBox(height: 14),
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
      onSubmitted: (_) => _register(),
    ),
  ];
}

/// The required terms checkbox (plain text until the Terms and Privacy links exist).
class _TermsField extends StatelessWidget {
  const _TermsField({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    return FormField<bool>(
      initialValue: false,
      validator: AuthValidators.terms,
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
            title: Text(AuthStrings.acceptTerms, style: TextStyle(fontSize: 14, color: muted)),
          ),
          if (field.errorText case final error?) AuthErrorMessage(error),
        ],
      ),
    );
  }
}
