/// An IIR filter made of second-order sections, each row `[b0, b1, b2, a0, a1, a2]` (as scipy's
/// `sos`), run in Direct Form II transposed. Keeps state: use one per signal.
class SosFilter {
  SosFilter(List<List<double>> sections) : _sections = [for (final row in sections) _Biquad(row)];

  final List<_Biquad> _sections;

  double filter(double input) {
    var out = input;
    for (final section in _sections) {
      out = section.process(out);
    }
    return out;
  }
}

class _Biquad {
  _Biquad(List<double> row)
    : _b0 = row[0] / row[3],
      _b1 = row[1] / row[3],
      _b2 = row[2] / row[3],
      _a1 = row[4] / row[3],
      _a2 = row[5] / row[3];

  final double _b0;
  final double _b1;
  final double _b2;
  final double _a1;
  final double _a2;
  double _z1 = 0;
  double _z2 = 0;

  double process(double x) {
    final y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }
}
