import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/device_profiles_provider.dart';
import '../../application/device_settings_provider.dart';
import '../../application/devices_provider.dart';
import '../../core/config/device_profile_registry.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/models/device_profile.dart';
import '../../domain/services/device_service.dart';
import '../add_device/add_device_screen.dart';
import '../devices/remove_device_sheet.dart';
import '../strings/add_device_strings.dart';
import '../strings/common_strings.dart';
import '../strings/device_settings_strings.dart';
import '../strings/remove_device_strings.dart';
import '../widgets/form_widgets.dart';
import '../widgets/labeled_field.dart';
import 'device_settings_sections.dart';
import 'heartbeat_card.dart';

/// Device settings (requirements §8, mockup screen 25): rename, connection and heartbeat details,
/// sampling interval, alert switches and Remove device. Full screen, without the tab bar.
class DeviceSettingsScreen extends ConsumerStatefulWidget {
  const DeviceSettingsScreen({super.key, required this.deviceId});

  final int deviceId;

  static const path = '/device/:id/settings';
  static String route(int deviceId) => '/device/$deviceId/settings';

  @override
  ConsumerState<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();

  /// The name as last saved; the field starts with it.
  String? _savedName;
  String? _nameError;

  /// Set once Remove is confirmed, so the device disappearing is not shown as "not found".
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onNameFocus);
  }

  @override
  void dispose() {
    _nameFocus
      ..removeListener(_onNameFocus)
      ..dispose();
    _name.dispose();
    super.dispose();
  }

  void _onNameFocus() {
    if (!_nameFocus.hasFocus) _saveName();
  }

  /// A save that has not finished yet. Done and the focus loss that follows it, or Back, may all
  /// ask to save; they share this one.
  Future<bool>? _saving;

  /// Saves a changed, valid name; an invalid one shows the message and is not saved. True when the
  /// screen may be left: the name is unchanged or was saved.
  Future<bool> _saveName() => _saving ??= _save().whenComplete(() => _saving = null);

  Future<bool> _save() async {
    final saved = _savedName;
    final name = _name.text.trim();
    if (saved == null || name == saved) {
      if (_nameError != null && mounted) setState(() => _nameError = null);
      return true;
    }
    final ok = await ref
        .read(deviceSettingsControllerProvider.notifier)
        .rename(widget.deviceId, name);
    if (ok) _savedName = name;
    if (mounted) setState(() => _nameError = ok ? null : AddDeviceStrings.enterDeviceName);
    return ok;
  }

  /// The header's Back and the phone's back (gesture or button): saves a changed name first. An
  /// invalid name keeps the screen open with its message (TC-DST-003); the old name stays saved.
  Future<void> _back() async {
    if (!await _saveName() || !mounted) return;
    context.canPop() ? context.pop() : context.go(AddDeviceScreen.deviceRoute(widget.deviceId));
  }

  Future<void> _remove(DeviceDetails device) async {
    final confirmed = await confirmRemoveDevice(context, name: device.name);
    if (!confirmed || !mounted) return;
    setState(() => _removing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(deviceSettingsControllerProvider.notifier).remove(device);
    } catch (_) {
      if (!mounted) return;
      setState(() => _removing = false);
      messenger.showSnackBar(const SnackBar(content: Text(RemoveDeviceStrings.removeFailed)));
      return;
    }
    if (!mounted) return;
    context.go('/home');
    messenger.showSnackBar(const SnackBar(content: Text(RemoveDeviceStrings.removed)));
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(deviceDetailsProvider(widget.deviceId));
    final device = details.value;
    if (device != null && _savedName == null) {
      _savedName = device.name;
      _name.text = device.name;
    }

    final Widget body;
    if (_removing || (details.isLoading && !details.hasValue)) {
      body = Center(
        child: Semantics(
          label: _removing ? DeviceSettingsStrings.removing : CommonStrings.loading,
          child: const CircularProgressIndicator(),
        ),
      );
    } else if (device == null) {
      body = const Center(child: Text(DeviceSettingsStrings.notFound, textAlign: TextAlign.center));
    } else {
      body = _Content(
        device: device,
        profile: _profileOf(device),
        now: ref.watch(clockProvider)(),
        nameField: _nameField(),
        onAlertChanged: (key, on) => ref
            .read(deviceSettingsControllerProvider.notifier)
            .setAlert(device.id, key, enabled: on),
        onRemove: () => _remove(device),
      );
    }

    // The phone's back goes through [_back] too, so it saves the name or stays on a bad one.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleBackButton(onPressed: _back),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: const Text(
                          DeviceSettingsStrings.title,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DeviceProfile? _profileOf(DeviceDetails device) {
    try {
      return ref.watch(deviceProfileRegistryProvider).value?.byId(device.profileId);
    } on UnknownDeviceTypeException {
      return null;
    }
  }

  Widget _nameField() => LabeledField(
    label: AddDeviceStrings.deviceName,
    child: TextField(
      controller: _name,
      focusNode: _nameFocus,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.words,
      onSubmitted: (_) => _saveName(),
      decoration: InputDecoration(errorText: _nameError),
    ),
  );
}

/// The scrolling part under the header, top to bottom as in the mockup.
class _Content extends StatelessWidget {
  const _Content({
    required this.device,
    required this.profile,
    required this.now,
    required this.nameField,
    required this.onAlertChanged,
    required this.onRemove,
  });

  final DeviceDetails device;

  /// Null when the config no longer has this device type.
  final DeviceProfile? profile;
  final DateTime now;
  final Widget nameField;
  final void Function(String readingKey, bool enabled) onAlertChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final danger = tokens?.danger ?? Theme.of(context).colorScheme.error;
    const gap = SizedBox(height: 16);
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        nameField,
        gap,
        const SectionHeading(DeviceSettingsStrings.connection),
        const SizedBox(height: 8),
        ConnectionCard(device: device, typeLabel: profile?.label ?? device.profileId),
        gap,
        const SectionHeading(DeviceSettingsStrings.heartbeat),
        const SizedBox(height: 8),
        HeartbeatCard(
          device: device,
          settings: profile?.heartbeatOrDefault ?? const HeartbeatSettings(),
          now: now,
        ),
        gap,
        const SectionHeading(DeviceSettingsStrings.sampling),
        const SizedBox(height: 8),
        const SamplingControl(),
        if (device.alerts.isNotEmpty) ...[
          gap,
          const SectionHeading(DeviceSettingsStrings.alerts),
          const SizedBox(height: 8),
          AlertsCard(
            alerts: device.alerts,
            readings: profile?.readings ?? const [],
            onChanged: onAlertChanged,
          ),
        ],
        gap,
        OutlinedButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
          label: const Text(RemoveDeviceStrings.remove),
          style: OutlinedButton.styleFrom(
            foregroundColor: danger,
            side: BorderSide(color: danger, width: 1.5),
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
            ),
          ),
        ),
      ],
    );
  }
}
