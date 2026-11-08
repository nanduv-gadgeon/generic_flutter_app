import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../core/di/services.dart';
import '../../../domain/models/device_profile.dart';
import '../../../domain/models/new_device.dart';
import '../../strings/add_device_strings.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/labeled_field.dart';
import '../add_device_parts.dart';
import '../add_device_validators.dart';
import '../device_key_card.dart';

/// Step 4 when saved (screen 12): the alert settings the device starts with, its name, and the
/// way to its dashboard. The device key card shows only with the cloud (Phase 2).
class DoneStep extends ConsumerStatefulWidget {
  const DoneStep({super.key, required this.onFinished});

  /// Called with the device id once the name is saved.
  final ValueChanged<int> onFinished;

  @override
  ConsumerState<DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends ConsumerState<DoneStep> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final done = ref.read(addDeviceControllerProvider).phase as Done;
    _name = TextEditingController(text: done.device.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final id = await ref.read(addDeviceControllerProvider.notifier).finish(_name.text);
    widget.onFinished(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addDeviceControllerProvider);
    final device = (state.phase as Done).device;
    final profile = state.profile!;
    final cloud = ref.watch(cloudRegistrationAvailableProvider);
    final tokens = tokensOf(context);

    return Form(
      key: _form,
      child: StepLayout(
        button: PrimaryButton(
          label: AddDeviceStrings.goToDashboard,
          busyLabel: AddDeviceStrings.saving,
          busy: _busy,
          onPressed: _finish,
        ),
        children: [
          StatusCircle(
            icon: Icons.check,
            size: 76,
            iconSize: 36,
            background: tokens?.okBg,
            foreground: tokens?.ok,
          ),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: const Text(
              AddDeviceStrings.doneHeading,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AddDeviceStrings.doneBody(profile.label, state.transport!, cloud: cloud),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens?.muted),
          ),
          if (cloud) ...[const SizedBox(height: 18), DeviceKeyCard(deviceKey: device.deviceKey)],
          if (device.alerts.isNotEmpty) ...[
            const SizedBox(height: 18),
            _AlertsCard(profile: profile, device: device),
          ],
          const SizedBox(height: 18),
          LabeledField(
            label: AddDeviceStrings.deviceName,
            child: TextFormField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              validator: AddDeviceValidators.deviceName,
              onFieldSubmitted: (_) => _finish(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The alert limits the device starts with: the config defaults, or the cloud's suggestion.
class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.profile, required this.device});

  final DeviceProfile profile;
  final AddedDevice device;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final border = BorderSide(color: tokens?.border ?? Colors.grey);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.auto_awesome_outlined, size: 18, color: tokens?.accent),
                ),
                const SizedBox(width: 10),
                // The badge drops below the title with large text.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          AddDeviceStrings.alertSettings,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens?.soft,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          device.suggestedAlerts
                              ? AddDeviceStrings.suggestedByCloud
                              : AddDeviceStrings.defaultSettings,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tokens?.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final rule in device.alerts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border(top: border)),
              child: _AlertRow(rule: rule, reading: _readingFor(rule.key)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Text(
              AddDeviceStrings.changeLater,
              style: TextStyle(fontSize: 12, color: tokens?.muted),
            ),
          ),
        ],
      ),
    );
  }

  Reading? _readingFor(String key) => profile.readings.where((r) => r.key == key).firstOrNull;
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.rule, required this.reading});

  final AlertRule rule;
  final Reading? reading;

  @override
  Widget build(BuildContext context) {
    final label = AddDeviceStrings.alertLabel(reading?.label ?? rule.key, rule);
    final value = AddDeviceStrings.alertValue(rule, reading?.unit ?? '');
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tokensOf(context)?.accent,
            ),
          ),
        ],
      ),
    );
  }
}
