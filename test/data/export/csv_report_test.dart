import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/export/csv_report.dart';
import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';

import '../../fixtures/export_fixtures.dart';

/// The exported CSV: UTF-8 with a byte order mark, a header, the rows and "No data" days.
void main() {
  test('BOM, header, readings and the days without data', () async {
    final bytes = await csvReport(exportRequest(), [
      Sample('temp', 36.6, DateTime(2026, 10, 20, 8).toUtc()),
    ]);

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF], reason: 'UTF-8 byte order mark');
    final lines = utf8.decode(bytes.skip(3).toList()).split('\r\n');
    expect(lines.first, 'Date,Time,Reading,Value,Unit,Day status');
    expect(lines[1], '2026-10-20,08:00:00,Skin temp,36.6,°C,Partial');
    expect(lines[2], '2026-10-21,,,,,No data');
    expect(lines.where((l) => l.endsWith('No data')), hasLength(6));
  });

  test('a field with a comma or a quote is quoted', () {
    final text = utf8.decode(
      csvBytes([
        ['a, b', 'say "hi"', 'plain'],
      ]).skip(3).toList(),
    );
    expect(text, '"a, b","say ""hi""",plain');
  });

  // text -> written: a spreadsheet must not run a field as a formula (OWASP CSV injection)
  final formulas = {
    '=1+2': "'=1+2",
    '+SUM(A1)': "'+SUM(A1)",
    '-cmd': "'-cmd",
    '@x': "'@x",
    'Heart rate': 'Heart rate',
    '': '',
  };
  for (final MapEntry(key: text, value: written) in formulas.entries) {
    test('safe text: "$text"', () => expect(safeText(text), written));
  }
}
