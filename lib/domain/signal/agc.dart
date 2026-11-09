import 'dart:collection';

import '../models/streaming_settings.dart';

/// Automatic gain control for the LEDs, as the profile's `agc` block describes: watches the smoothed
/// input and says when to move the LED level one step. The caller sends the level with the
/// profile's AGC commands and reports back with [applied].
class Agc {
  Agc(this._s) : _level = _s.start;

  final AgcSettings _s;
  final _recent = ListQueue<double>();
  int _level;
  DateTime? _lastChange;
  DateTime? _highSince;
  DateTime? _lowSince;

  /// The LED level now in use.
  int get level => _level;

  /// The level to change to after [input] at [now], or null to stay.
  int? feed(double input, DateTime now) {
    if (_recent.length == _s.smoothing) _recent.removeFirst();
    _recent.addLast(input);
    final last = _lastChange;
    if (last != null && now.difference(last) < Duration(milliseconds: _s.cooldownMs)) return null;

    final next = (_level + _direction(_smoothed, now) * _s.step).clamp(_s.min, _s.max);
    return next == _level ? null : next;
  }

  /// The device confirmed [level] at [now].
  void applied(int level, DateTime now) {
    _level = level;
    _lastChange = now;
  }

  double get _smoothed => _recent.reduce((a, b) => a + b) / _recent.length;

  /// +1 to raise, −1 to lower, 0 to stay.
  int _direction(double value, DateTime now) {
    final hold = Duration(milliseconds: _s.holdMs);
    if (value < _s.noContact) {
      // Nothing on the sensor: never raise from the noise floor, and come back down to start.
      _highSince = _lowSince = null;
      return _level > _s.start ? -1 : 0;
    }
    if (value > _s.high) {
      _lowSince = null;
      return now.difference(_highSince ??= now) >= hold ? -1 : 0;
    }
    if (value < _s.low) {
      _highSince = null;
      return now.difference(_lowSince ??= now) >= hold ? 1 : 0;
    }
    _highSince = _lowSince = null;
    return 0;
  }
}
