import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_settings.freezed.dart';
part 'dashboard_settings.g.dart';

/// What the third cell of the dashboard's status strip shows, after Link and Battery.
enum StripCell {
  /// When the device was last heard from.
  heartbeat,

  /// Running or Stopped, from the device's START / STOP events.
  state,

  /// The time of today's latest reading.
  lastReading,

  /// The waveform's sample rate, e.g. "250 Hz".
  streamRate,

  /// How many readings have a value, e.g. "24 live".
  channels,
}

/// The view types a dashboard is built from. Each has one widget, found through the view registry.
enum DashboardViewType {
  /// Main card: arc gauge, status, normal range and the 30-minute trend.
  gauge,

  /// "All readings" and a two-column grid of reading tiles.
  tiles,

  /// One large latest value with its zone bar, for devices that send a reading when used.
  spotValue,

  /// An information banner.
  note,

  /// "Today's readings" as a list with each value's zone.
  readingList,

  /// A live trace with grid paper, e.g. ECG, and a row of readings under it.
  waveform,
}

/// The `dashboard` block of a device profile.
@freezed
abstract class DashboardSettings with _$DashboardSettings {
  const factory DashboardSettings({
    @Default(StripCell.heartbeat) StripCell strip,

    /// The device connects only to send a reading; the Link cell says "On demand".
    @Default(false) bool onDemand,

    /// In screen order. Empty: a gauge for the first reading and tiles for the rest.
    @Default([]) List<DashboardView> views,

    /// The device action button at the bottom of Live, e.g. "Find band"; none when null.
    DeviceAction? action,
  }) = _DashboardSettings;

  factory DashboardSettings.fromJson(Map<String, dynamic> json) =>
      _$DashboardSettingsFromJson(json);
}

/// The dashboard's device action button (requirement 5.6), e.g. "Find band" or "Identify".
@freezed
abstract class DeviceAction with _$DeviceAction {
  const factory DeviceAction({
    /// The button's text, e.g. "Find band".
    required String label,

    /// The profile command it sends, for a one-command action.
    String? command,

    /// The profile commands it sends in order, e.g. to flash an LED; instead of [command].
    @Default([]) List<ActionStep> steps,

    /// Said once the device has done it, e.g. "The band is vibrating."
    String? done,
  }) = _DeviceAction;

  const DeviceAction._();

  factory DeviceAction.fromJson(Map<String, dynamic> json) => _$DeviceActionFromJson(json);

  /// What to send, in order; empty when the action is not available yet (a placeholder).
  List<ActionStep> get sequence => switch (command) {
    final c? => [ActionStep(command: c)],
    null => steps,
  };
}

/// One step of a device action: a profile command, its value byte when it takes one (e.g. an LED
/// level), and how long to wait after it.
@freezed
abstract class ActionStep with _$ActionStep {
  const factory ActionStep({required String command, int? value, @Default(0) int waitMs}) =
      _ActionStep;

  factory ActionStep.fromJson(Map<String, dynamic> json) => _$ActionStepFromJson(json);
}

/// One view on the dashboard and the readings that feed it.
@freezed
abstract class DashboardView with _$DashboardView {
  const factory DashboardView({
    required DashboardViewType type,

    /// The reading a gauge, spot value, reading list or waveform shows.
    String? reading,

    /// The readings a tiles view shows, in order.
    @Default([]) List<String> readings,

    /// Title of a waveform, e.g. "Live ECG · Lead I · 250 Hz".
    String? title,

    /// Text of a note.
    String? text,

    /// Middle label under a waveform, e.g. "25 mm/s · 10 mm/mV".
    String? scaleLabel,

    /// Samples per second of a waveform.
    int? sampleHz,

    /// Seconds of trace a waveform shows.
    @Default(6) int seconds,

    /// A reading whose state is shown at the top right of a waveform, e.g. "Signal good".
    String? status,

    /// Readings shown in a row under a waveform.
    @Default([]) List<String> stats,
  }) = _DashboardView;

  factory DashboardView.fromJson(Map<String, dynamic> json) => _$DashboardViewFromJson(json);
}
