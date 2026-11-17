import 'dart:math' as math;

import '../decoder/decoded_packet.dart';
import '../models/streaming_settings.dart';
import 'sos_filter.dart';

/// Whether a finger is on the sensor, for profiles with a `finger` block.
enum SensorContact {
  /// Nothing on the sensor: no results.
  none,

  /// A finger is on, but the filters and windows are still filling: no results yet.
  settling,

  /// Results are being given.
  ok,
}

/// Which part of the finger rule the latest sample pair met, for diagnostics. Never a value.
enum FingerCheck {
  ok,

  /// Infrared DC level below `minDcIr`: not enough light coming back.
  lightTooLow,

  /// Light is fine, but the infrared AC spread is below `minAcIr`: no pulse seen.
  pulseTooSmall,
}

/// Whether a finger is on the sensor, from the infrared DC level and AC spread.
bool hasFinger(double dcIr, double acIr, FingerSettings finger) =>
    dcIr >= finger.minDcIr && acIr >= finger.minAcIr;

/// SpO₂, heart rate and perfusion index from red and infrared PPG samples, as the profile's
/// `signal.ppgOximetry` block describes. Not clinically validated.
///
/// Feed it the decoder's samples; it uses the [PpgOximetrySettings.red] and
/// [PpgOximetrySettings.ir] ones, paired in the order they arrive, and returns results once per
/// [PpgOximetrySettings.emitEvery] pairs. With a [PpgOximetrySettings.finger] block it gives results
/// only while [contact] is [SensorContact.ok], and forgets its averages when the finger is lifted.
/// Values are passed on, never logged.
class PpgOximetry {
  PpgOximetry(this._s)
    : _bandPassRed = SosFilter(_s.bandPass),
      _bandPassIr = SosFilter(_s.bandPass),
      _lowPassRed = SosFilter(_s.lowPass),
      _lowPassIr = SosFilter(_s.lowPass);

  final PpgOximetrySettings _s;
  final SosFilter _bandPassRed;
  final SosFilter _bandPassIr;
  final SosFilter _lowPassRed;
  final SosFilter _lowPassIr;

  final _acRed = <double>[];
  final _acIr = <double>[];
  final _dcRed = <double>[];
  final _dcIr = <double>[];
  final _peakBuffer = <double>[];
  final _spo2Values = <int>[];
  final _heartRates = <int>[];

  /// Whether the latest pair gave an SpO₂ within the limits. SpO₂ is given only then, so the
  /// average of earlier values is not repeated while the signal is bad (e.g. a finger coming off).
  bool _spo2Now = false;

  /// The latest pair's SpO₂, kept for averaging per result ([Spo2AverageOf.results]).
  int _spo2Latest = 0;

  /// Whether the latest heart-rate search found a pulse, for [Spo2Settings.needsPulse].
  bool _pulseNow = false;
  double? _red;
  double? _ir;
  int _pairs = 0;

  /// Sample pairs since the finger was put on the sensor.
  int _withFinger = 0;

  /// The finger rule's outcome for the latest pair; null without a `finger` block or before the
  /// first pair. For diagnostics only.
  FingerCheck? get lastCheck => _lastCheck;
  FingerCheck? _lastCheck;

  /// Null when the profile has no `finger` block (results are always given).
  SensorContact? get contact {
    final finger = _s.finger;
    if (finger == null) return null;
    if (_withFinger == 0) return SensorContact.none;
    return _withFinger < finger.settleSeconds * _s.sampleRateHz
        ? SensorContact.settling
        : SensorContact.ok;
  }

  /// Results to pass on after [sample]; empty most of the time.
  List<Sample> feed(Sample sample) {
    if (sample.key == _s.red) {
      _red = sample.value;
    } else if (sample.key == _s.ir) {
      _ir = sample.value;
    } else {
      return const [];
    }
    final red = _red;
    final ir = _ir;
    if (red == null || ir == null) return const [];
    _red = _ir = null;
    _pair(red, ir);
    _trackFinger();
    if (++_pairs % _s.emitEvery != 0) return const [];
    final gated = contact;
    return gated == null || gated == SensorContact.ok ? _results(sample.at) : const [];
  }

  void _pair(double red, double ir) {
    final irBand = _bandPassIr.filter(ir);
    _keep(_acRed, _bandPassRed.filter(red), _s.window);
    _keep(_acIr, irBand, _s.window);
    _keep(_dcRed, _lowPassRed.filter(red), _s.window);
    _keep(_dcIr, _lowPassIr.filter(ir), _s.window);

    _spo2Latest = _spo2();
    _spo2Now = _spo2Latest > 0;
    if (_spo2Now && _s.spo2.averageOf == Spo2AverageOf.pairs) {
      _keep(_spo2Values, _spo2Latest, _s.spo2.average);
    }

    final hr = _s.heartRate;
    _peakBuffer.add(irBand);
    if (_peakBuffer.length > hr.buffer) {
      final bpm = _heartRate(_peakBuffer.sublist(0, hr.window));
      _pulseNow = bpm != null;
      if (bpm != null) _keep(_heartRates, bpm, hr.average);
      _peakBuffer.removeRange(0, hr.step);
    }
  }

  void _trackFinger() {
    final finger = _s.finger;
    if (finger == null) return;
    final dcIr = _mean(_dcIr);
    final acIr = _stdDev(_acIr);
    _lastCheck = dcIr < finger.minDcIr
        ? FingerCheck.lightTooLow
        : acIr < finger.minAcIr
        ? FingerCheck.pulseTooSmall
        : FingerCheck.ok;
    if (hasFinger(dcIr, acIr, finger)) {
      _withFinger++;
    } else if (_withFinger > 0) {
      // Lifted: values from before are stale, so start the averages and peak search again.
      _withFinger = 0;
      _pulseNow = false;
      _spo2Values.clear();
      _heartRates.clear();
      _peakBuffer.clear();
    }
  }

  List<Sample> _results(DateTime at) {
    final dcRed = _mean(_dcRed);
    final dcIr = _mean(_dcIr);
    final spo2Ok = _spo2Now && (_pulseNow || !_s.spo2.needsPulse);
    if (spo2Ok && _s.spo2.averageOf == Spo2AverageOf.results) {
      _keep(_spo2Values, _spo2Latest, _s.spo2.average);
    }
    return [
      if (spo2Ok && _spo2Values.isNotEmpty) Sample(_s.spo2.key, _average(_spo2Values), at),
      if (_heartRates.isNotEmpty) Sample(_s.heartRate.key, _average(_heartRates), at),
      if (dcRed != 0)
        if (_perfusion(_stdDev(_acRed) / dcRed * 100) case final pi?)
          Sample(_s.perfusion.red, pi, at),
      if (dcIr != 0)
        if (_perfusion(_stdDev(_acIr) / dcIr * 100) case final pi?) Sample(_s.perfusion.ir, pi, at),
    ];
  }

  /// [pi], or null (not given) when it is above the profile's limit, e.g. while a finger comes
  /// off the sensor. SpO₂ uses its own ratio of the signals, so it is not changed by this.
  double? _perfusion(double pi) => switch (_s.perfusion.max) {
    final max? when pi > max => null,
    _ => pi,
  };

  /// a·R² + b·R + c, rounded; 0 (left out of the average) when there is no signal yet or the
  /// result is outside the profile's limits, e.g. while a finger comes off the sensor.
  int _spo2() {
    final dcRed = _mean(_dcRed);
    final dcIr = _mean(_dcIr);
    final acIr = _stdDev(_acIr);
    if (dcRed == 0 || dcIr == 0 || acIr == 0) return 0;
    final r = (_stdDev(_acRed) / dcRed) / (acIr / dcIr);
    final [a, b, c] = _s.spo2.coefficients;
    final spo2 = (a * r * r + b * r + c).round();
    return spo2 < _s.spo2.min || spo2 > _s.spo2.max ? 0 : spo2;
  }

  /// Beats per minute from the first two peaks of the inverted signal, or null when there are
  /// fewer than 3 peaks or the result is out of range.
  int? _heartRate(List<double> window) {
    final hr = _s.heartRate;
    final n = hr.neighbours;
    final flipped = [for (final v in window) -v];
    final positive = flipped.where((v) => v > 0).toList();
    if (positive.isEmpty) return null;
    final threshold = _mean(positive);

    final peaks = <int>[];
    var dipped = false;
    for (var i = n; i < flipped.length - n; i++) {
      final item = flipped[i];
      if (item < 0) dipped = true;
      var isPeak = item > threshold;
      for (var k = 1; isPeak && k <= n; k++) {
        isPeak = flipped[i - k] < item && item > flipped[i + k];
      }
      // A new peak counts only after the signal has dipped below zero since the last one.
      if (!isPeak || (peaks.isNotEmpty && !dipped)) continue;
      peaks.add(i);
      dipped = false;
    }
    if (peaks.length < 3) return null;
    final gap = peaks[1] - peaks[0];
    final bpm = (_s.sampleRateHz / gap * 60).round();
    return bpm < hr.min || bpm > hr.max ? null : bpm;
  }

  static void _keep<T>(List<T> list, T value, int max) {
    list.add(value);
    if (list.length > max) list.removeAt(0);
  }

  static double _average(List<int> values) =>
      (values.reduce((a, b) => a + b) / values.length).roundToDouble();

  static double _mean(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  static double _stdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = _mean(values);
    var sum = 0.0;
    for (final v in values) {
      sum += (v - mean) * (v - mean);
    }
    return math.sqrt(sum / values.length);
  }
}
