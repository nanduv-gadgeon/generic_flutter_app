import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../core/di/services.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/dial_code.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/photo_picker.dart';
import '../../domain/validation/auth_rules.dart';
import '../widgets/form_widgets.dart';
import '../auth/auth_validators.dart';
import '../auth/mobile_number_field.dart';
import '../strings/auth_strings.dart';
import '../strings/common_strings.dart';
import '../strings/profile_strings.dart';
import '../widgets/labeled_field.dart';
import '../widgets/user_avatar.dart';
import 'photo_source_sheet.dart';

/// Edit profile: photo, full name and mobile number; the email is shown read-only. Saves, then
/// goes back to Profile.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  static const route = '/profile/edit';

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthUser _user;
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late DialCode _dialCode;
  PhotoChange _photo = const KeepPhoto();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only reachable while logged in (the router's guard).
    _user = ref.read(authControllerProvider).requireValue!;
    final region = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final (code, number) = splitMobileNumber(_user.mobile, preferred: defaultDialCode(region));
    _dialCode = code;
    _name = TextEditingController(text: _user.name);
    _mobile = TextEditingController(text: number);
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The photo shown now: picked but not yet saved, removed, or the saved one.
  String? get _shownPhoto => switch (_photo) {
    NewPhoto(:final pickedPath) => pickedPath,
    RemovePhoto() => null,
    KeepPhoto() => _user.photoPath,
  };

  Future<void> _changePhoto() async {
    final action = await showPhotoSourceSheet(context, hasPhoto: _shownPhoto != null);
    switch (action) {
      case null:
        return;
      case PhotoAction.remove:
        setState(() => _photo = const RemovePhoto());
      case PhotoAction.camera || PhotoAction.gallery:
        final source = action == PhotoAction.camera ? PhotoSource.camera : PhotoSource.gallery;
        final path = await ref.read(photoPickerProvider).pick(source);
        if (path != null && mounted) setState(() => _photo = NewPhoto(path));
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            ProfileChanges(
              name: _name.text,
              mobile: fullMobileNumber(_dialCode, _mobile.text),
              photo: _photo,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(ProfileStrings.profileSaved)));
      context.pop();
    } catch (_) {
      if (mounted) setState(() => _error = ProfileStrings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).extension<AppTokens>()?.accent;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          // SafeArea already clears the status bar; the mockup's 56 px top included it.
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleBackButton(onPressed: () => context.pop()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          ProfileStrings.editProfile,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: UserAvatar(name: _name.text, photoPath: _shownPhoto, size: 88),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _changePhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text(ProfileStrings.changePhoto),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 40),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ..._fields(),
                if (_error case final error?) ...[const SizedBox(height: 12), ErrorMessage(error)],
                const SizedBox(height: 26),
                PrimaryButton(
                  label: ProfileStrings.saveChanges,
                  busyLabel: ProfileStrings.saving,
                  busy: _busy,
                  onPressed: _save,
                ),
              ],
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
        // Keeps the initials in the avatar in step with the name.
        onChanged: (_) => setState(() {}),
      ),
    ),
    const SizedBox(height: 18),
    // The email is the login, so it is shown but cannot be edited (greyed out by the theme).
    LabeledField(
      label: CommonStrings.email,
      child: TextFormField(initialValue: _user.email, enabled: false),
    ),
    const SizedBox(height: 18),
    MobileNumberField(
      controller: _mobile,
      dialCode: _dialCode,
      enabled: !_busy,
      onDialCodeChanged: (code) => setState(() => _dialCode = code),
    ),
  ];
}
