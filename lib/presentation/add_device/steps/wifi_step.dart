import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/add_device/add_device_controller.dart';
import '../../../domain/models/device_profile.dart';
import '../../../domain/transport/wifi_provisioner.dart';
import '../../strings/add_device_strings.dart';
import '../../strings/common_strings.dart';
import '../../widgets/form_widgets.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/password_field.dart';
import '../add_device_parts.dart';
import '../add_device_validators.dart';

/// Step 3, Wi‑Fi: the home network's name and password, and how to send them to the device.
///
/// The password stays in this form's controller until sent; it is never stored or logged.
class WifiStep extends ConsumerStatefulWidget {
  const WifiStep({super.key});

  @override
  ConsumerState<WifiStep> createState() => _WifiStepState();
}

class _WifiStepState extends ConsumerState<WifiStep> {
  final _form = GlobalKey<FormState>();
  final _network = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _network.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    ref
        .read(addDeviceControllerProvider.notifier)
        .submitWifi(WifiCredentials(ssid: _network.text, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addDeviceControllerProvider);
    final controller = ref.read(addDeviceControllerProvider.notifier);
    final methods = state.profile!.wifi!.setup;
    final tokens = tokensOf(context);
    final error = state.error;

    return Form(
      key: _form,
      child: StepLayout(
        button: PrimaryButton(label: AddDeviceStrings.connectDevice, onPressed: _submit),
        children: [
          const StepHeading(AddDeviceStrings.wifiHeading, AddDeviceStrings.wifiFormBody),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens?.soft,
              borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.memory_outlined, size: 22, color: tokens?.accent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    AddDeviceStrings.wifiInstructions,
                    style: TextStyle(fontSize: 14, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          if (methods.length > 1) ...[
            const SizedBox(height: 18),
            LabeledField(
              label: AddDeviceStrings.setupMethod,
              child: SegmentedButton<WifiSetupMethod>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: WifiSetupMethod.ble,
                    icon: Icon(Icons.bluetooth),
                    label: Text(AddDeviceStrings.setupOverBluetooth),
                  ),
                  ButtonSegment(
                    value: WifiSetupMethod.softap,
                    icon: Icon(Icons.wifi_tethering),
                    label: Text(AddDeviceStrings.setupOverHotspot),
                  ),
                ],
                selected: {?state.setupMethod},
                onSelectionChanged: (s) => controller.selectSetupMethod(s.single),
              ),
            ),
          ],
          const SizedBox(height: 18),
          LabeledField(
            label: AddDeviceStrings.network,
            child: TextFormField(
              controller: _network,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              validator: AddDeviceValidators.network,
              decoration: const InputDecoration(hintText: AddDeviceStrings.networkHint),
            ),
          ),
          const SizedBox(height: 14),
          PasswordField(
            controller: _password,
            label: AddDeviceStrings.wifiPassword,
            hint: CommonStrings.password,
            autofillHints: const [],
            validator: AddDeviceValidators.wifiPassword,
            onSubmitted: (_) => _submit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            ErrorMessage(AddDeviceStrings.error(error)),
          ],
        ],
      ),
    );
  }
}
