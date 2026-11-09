import 'package:freezed_annotation/freezed_annotation.dart';

part 'streaming_settings.freezed.dart';
part 'streaming_settings.g.dart';

/// `streaming` block of a profile: profile command ids sent in order to start and to stop the
/// device's live data. Each one waits for its reply, if it has one.
@freezed
abstract class StreamingSettings with _$StreamingSettings {
  const factory StreamingSettings({
    required List<String> start,
    @Default([]) List<String> stop,
    @Default(2500) int replyTimeoutMs,

    /// Extra attempts when a reply does not come in time.
    @Default(1) int retries,

    /// Replies, to a command or unprompted, that mean the device has a problem.
    @Default([]) List<ReplyProblem> problems,
  }) = _StreamingSettings;

  factory StreamingSettings.fromJson(Map<String, dynamic> json) =>
      _$StreamingSettingsFromJson(json);
}

/// Something the device reports that stops or spoils its data.
enum DeviceProblem { lowBattery, charging, sensorError, transferError }

/// A reply with command id [id] and first data byte [data] (both hex) means [problem].
@freezed
abstract class ReplyProblem with _$ReplyProblem {
  const factory ReplyProblem({
    required String id,
    required String data,
    required DeviceProblem problem,
  }) = _ReplyProblem;

  factory ReplyProblem.fromJson(Map<String, dynamic> json) => _$ReplyProblemFromJson(json);
}

/// `signal` block of a profile: readings worked out on the phone from raw samples.
@freezed
abstract class SignalSettings with _$SignalSettings {
  const factory SignalSettings({PpgOximetrySettings? ppgOximetry}) = _SignalSettings;

  factory SignalSettings.fromJson(Map<String, dynamic> json) => _$SignalSettingsFromJson(json);
}

/// Pulse oximetry from red and infrared PPG samples: SpO₂, heart rate and perfusion index.
///
/// Filters are second-order sections, one row `[b0, b1, b2, a0, a1, a2]` per section.
@freezed
abstract class PpgOximetrySettings with _$PpgOximetrySettings {
  const factory PpgOximetrySettings({
    required double sampleRateHz,

    /// Reading keys of the raw red and infrared samples.
    required String red,
    required String ir,
    required List<List<double>> bandPass,
    required List<List<double>> lowPass,

    /// Samples the AC (band-pass spread) and DC (low-pass mean) are worked out over.
    required int window,

    /// Results are passed on once per this many samples.
    required int emitEvery,
    required Spo2Settings spo2,
    required HeartRateSettings heartRate,
    required PerfusionSettings perfusion,
  }) = _PpgOximetrySettings;

  factory PpgOximetrySettings.fromJson(Map<String, dynamic> json) =>
      _$PpgOximetrySettingsFromJson(json);
}

/// SpO₂ = a·R² + b·R + c with R = PI(red) / PI(ir), kept within [min, max] and averaged over the
/// last [average] values.
@freezed
abstract class Spo2Settings with _$Spo2Settings {
  const factory Spo2Settings({
    required String key,

    /// `[a, b, c]`.
    required List<double> coefficients,
    required int min,
    required int max,
    required int average,
  }) = _Spo2Settings;

  factory Spo2Settings.fromJson(Map<String, dynamic> json) => _$Spo2SettingsFromJson(json);
}

/// Heart rate from peaks in the inverted band-pass infrared signal: once [buffer] samples are
/// held, the first [window] are searched and the oldest [step] dropped. A peak is higher than its
/// [neighbours] on each side.
@freezed
abstract class HeartRateSettings with _$HeartRateSettings {
  const factory HeartRateSettings({
    required String key,
    required int buffer,
    required int window,
    required int step,
    required int neighbours,
    required int min,
    required int max,
    required int average,
  }) = _HeartRateSettings;

  factory HeartRateSettings.fromJson(Map<String, dynamic> json) =>
      _$HeartRateSettingsFromJson(json);
}

/// Reading keys of the perfusion index (AC / DC × 100) of each colour.
@freezed
abstract class PerfusionSettings with _$PerfusionSettings {
  const factory PerfusionSettings({required String red, required String ir}) = _PerfusionSettings;

  factory PerfusionSettings.fromJson(Map<String, dynamic> json) =>
      _$PerfusionSettingsFromJson(json);
}

/// `agc` block of a profile: raises or lowers the LED levels to keep the [input] signal between
/// [low] and [high], using profile commands that take the new level as their value.
@freezed
abstract class AgcSettings with _$AgcSettings {
  const factory AgcSettings({
    required String input,

    /// The input is averaged over this many samples first.
    required int smoothing,
    required double high,
    required double low,

    /// Below this nothing touches the sensor: never raise, and lower back to [start].
    required double noContact,

    /// How long the input must stay out of range before a change.
    required int holdMs,

    /// Least time between changes.
    required int cooldownMs,
    required int start,
    required int min,
    required int max,
    @Default(1) int step,

    /// Command ids sent with the new level, in order.
    required List<String> commands,
  }) = _AgcSettings;

  factory AgcSettings.fromJson(Map<String, dynamic> json) => _$AgcSettingsFromJson(json);
}
