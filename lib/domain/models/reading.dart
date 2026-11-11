import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading.freezed.dart';
part 'reading.g.dart';

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
  play,
  list,
  alert,
  vibrate,
  ecg,
}

/// How a reading's status looks: always shown with a word too, never by colour alone.
enum StatusKind { ok, warn, danger }

/// How a value is written: a number, or hours as "7h 12m".
enum ReadingFormat { number, hoursMinutes }

/// Where a reading's value comes from: the device's data, or worked out from today's device
/// events (log types START / STOP / ERROR).
enum ReadingSource { device, eventsRunTimeToday, eventsSessionsToday, eventsErrorsToday }

/// A value the device measures, e.g. heart rate in bpm.
@freezed
abstract class Reading with _$Reading {
  const factory Reading({
    required String key,
    required String label,

    /// A shorter label where space is tight, e.g. "HR" on a device card; [label] when not set.
    String? shortLabel,
    required String unit,
    required ReadingIcon icon,
    @Default(0) int decimals,

    /// Normal range; readings outside it show High or Low. Not set together with [goal].
    @NormalRangeConverter() NormalRange? normal,

    /// Daily target shown as progress (steps, sleep, active time).
    double? goal,

    /// Ends of the dashboard gauge and range bar. Missing: [normal] widened by half its span.
    @NormalRangeConverter() NormalRange? scale,

    /// Named bands in rising order, e.g. Normal / High / Fever; the last has no [ReadingZone.below].
    @Default([]) List<ReadingZone> zones,

    /// Names for coded values, e.g. `"1": Sinus rhythm` for an ECG rhythm reading.
    @Default({}) Map<String, ReadingState> states,

    /// A second reading shown after this one as "a/b", e.g. diastolic after systolic pressure.
    String? pair,
    @Default(ReadingFormat.number) ReadingFormat format,
    @Default(ReadingSource.device) ReadingSource source,
  }) = _Reading;

  factory Reading.fromJson(Map<String, dynamic> json) => _$ReadingFromJson(json);
}

/// One band of a reading: values below [below] (or any value, for the last band).
@freezed
abstract class ReadingZone with _$ReadingZone {
  const factory ReadingZone({double? below, required String label, required StatusKind kind}) =
      _ReadingZone;

  factory ReadingZone.fromJson(Map<String, dynamic> json) => _$ReadingZoneFromJson(json);
}

/// The name and look of one coded value.
@freezed
abstract class ReadingState with _$ReadingState {
  const factory ReadingState({required String label, required StatusKind kind}) = _ReadingState;

  factory ReadingState.fromJson(Map<String, dynamic> json) => _$ReadingStateFromJson(json);
}

/// Inclusive range, written `[low, high]` in the config file.
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
