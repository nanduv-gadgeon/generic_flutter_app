import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_profile.freezed.dart';
part 'device_profile.g.dart';

/// Every device reports its battery level, so alerts may name it without listing it as a reading.
const batteryKey = 'battery';

/// Icon on the Add device type list (mockup `10_add.png`).
enum DeviceIcon { watch, chip, patch, kit }

/// Icon on a dashboard tile or main card.
enum ReadingIcon {
  pulse,
  drop,
  heart,
  thermo,
  trend,
  moon,
  wind,
  cloud,
  dots,
  gauge,
  sun,
  flask,
  bolt,
  scale,
  battery,
}

/// How the phone reaches the device.
enum Transport { ble, wifi }

/// One entry of the config file's `deviceProfiles` list: what a device type is and what it measures.
///
/// Connection (`ble`, `wifi`), `packet`, `heartbeat`, `commands` and `dashboard` sections are added
/// by tasks 1.2.4–1.3.5.
@freezed
abstract class DeviceProfile with _$DeviceProfile {
  const factory DeviceProfile({
    required String id,
    required String label,

    /// Short list of what the device measures, shown under the label in Add device.
    required String summary,
    required DeviceIcon icon,
    required List<Transport> transports,
    required List<Reading> readings,
    required List<AlertRule> alerts,
  }) = _DeviceProfile;

  factory DeviceProfile.fromJson(Map<String, dynamic> json) => _$DeviceProfileFromJson(json);
}

/// A value the device measures, e.g. heart rate in bpm.
@freezed
abstract class Reading with _$Reading {
  const factory Reading({
    required String key,
    required String label,
    required String unit,
    required ReadingIcon icon,
    @Default(0) int decimals,

    /// Normal range; readings outside it show High or Low. Not set together with [goal].
    @NormalRangeConverter() NormalRange? normal,

    /// Daily target shown as progress (steps, sleep, active time).
    double? goal,
  }) = _Reading;

  factory Reading.fromJson(Map<String, dynamic> json) => _$ReadingFromJson(json);
}

/// Inclusive normal range, written `[low, high]` in the config file.
@freezed
abstract class NormalRange with _$NormalRange {
  const factory NormalRange({required double low, required double high}) = _NormalRange;
}

class NormalRangeConverter implements JsonConverter<NormalRange, List<dynamic>> {
  const NormalRangeConverter();

  @override
  NormalRange fromJson(List<dynamic> json) =>
      NormalRange(low: (json[0] as num).toDouble(), high: (json[1] as num).toDouble());

  @override
  List<dynamic> toJson(NormalRange range) => [range.low, range.high];
}

/// Default alert condition for a reading: exactly one of [above] or [below] is set.
@freezed
abstract class AlertRule with _$AlertRule {
  const factory AlertRule({required String key, double? above, double? below}) = _AlertRule;

  factory AlertRule.fromJson(Map<String, dynamic> json) => _$AlertRuleFromJson(json);
}
