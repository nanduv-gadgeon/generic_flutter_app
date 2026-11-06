import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/app_config_provider.dart';
import '../../application/auth_controller.dart';
import '../../core/di/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/biometric_auth.dart';
import '../widgets/brand_header.dart';
import '../widgets/labeled_field.dart';
import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';
import '../widgets/password_field.dart';
import 'auth_form.dart';
import 'auth_validators.dart';
import 'biometric_offer_dialog.dart';

/// Email + password login, optional biometric login, links to register and forgot password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _logIn() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final auth = ref.read(authControllerProvider.notifier);
      final result = await auth.login(_email.text, _password.text);
      if (result is! LoginSuccess) {
        _showError(AuthStrings.wrongCredentials);
        return;
      }
      var enable = false;
      // Offer only when the customer has the feature (TC-CFG-007).
      final featureOn = ref.read(appConfigProvider).requireValue.features.faceIdLogin;
      if (featureOn && result.offerBiometrics && mounted) {
        final kind = await ref.read(biometricAuthProvider).kind();
        if (mounted) enable = await showBiometricOfferDialog(context, kind);
      }
      await auth.completeLogin(result.user, enableBiometrics: enable);
    });
  }

  Future<void> _logInWithBiometrics(BiometricKind kind) async {
    setState(() => _error = null);
    await _run(() async {
      final result = await ref
          .read(authControllerProvider.notifier)
          .loginWithBiometrics(reason: AuthStrings.biometricLoginReason);
      if (result is! LoginSuccess) {
        _showError(AuthStrings.biometricFailed(biometricName(kind)));
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider).requireValue;
    final biometric = config.features.faceIdLogin ? ref.watch(biometricLoginProvider).value : null;

    return Scaffold(
      body: SafeArea(
        // Fills the screen so "New here?" sits at the bottom; scrolls on small screens or with
        // large text.
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 32),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BrandHeader(brand: config.brand),
                        const SizedBox(height: 28),
                        ..._fields(),
                        if (_error case final error?) AuthErrorMessage(error),
                        const SizedBox(height: 14),
                        AuthSubmitButton(
                          label: AuthStrings.logIn,
                          busyLabel: AuthStrings.signingIn,
                          busy: _busy,
                          onPressed: _logIn,
                        ),
                        if (biometric != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _logInWithBiometrics(biometric),
                            icon: Icon(
                              biometric == BiometricKind.face
                                  ? Icons.face_outlined
                                  : Icons.fingerprint,
                            ),
                            label: Text(AuthStrings.logInWith(biometricName(biometric))),
                          ),
                        ],
                        const Spacer(),
                        if (config.features.registration) ...[
                          const SizedBox(height: 28),
                          _CreateAccountLink(enabled: !_busy),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
      validator: AuthValidators.loginPassword,
      onSubmitted: (_) => _logIn(),
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _busy ? null : () => context.push('/forgot'),
        child: const Text(AuthStrings.forgotPassword),
      ),
    ),
  ];
}

class _CreateAccountLink extends StatelessWidget {
  const _CreateAccountLink({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    // Wrap, not Row: goes onto two lines with large text instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(AuthStrings.newHere, style: TextStyle(fontSize: 15, color: muted)),
        TextButton(
          onPressed: enabled ? () => context.push('/register') : null,
          style: TextButton.styleFrom(
            textStyle: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: const Text(AuthStrings.createAccount),
        ),
      ],
    );
  }
}
