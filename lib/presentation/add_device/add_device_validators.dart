import '../../domain/validation/device_rules.dart';
import '../../l10n/app_localizations.dart';

/// Form field validators for Add device: each pairs a rule from `device_rules.dart` with its
/// message in the phone's language. Return null when the value is valid.
/// Use `AddDeviceValidators(context.l10n).network`.
final class AddDeviceValidators {
  const AddDeviceValidators(this._l10n);

  final AppLocalizations _l10n;

  String? deviceName(String? v) =>
      isValidDeviceName(v ?? '') ? null : _l10n.addDeviceEnterDeviceName;

  String? network(String? v) => isValidSsid(v ?? '') ? null : _l10n.addDeviceEnterNetwork;

  String? wifiPassword(String? v) =>
      isValidWifiPassword(v ?? '') ? null : _l10n.addDeviceWifiPasswordLength;
}
