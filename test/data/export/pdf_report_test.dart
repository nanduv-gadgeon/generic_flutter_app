import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/export/pdf_report.dart';
import 'package:generic_flutter_app/domain/history/day_summary.dart';
import 'package:generic_flutter_app/domain/history/summary_chart.dart';
import 'package:generic_flutter_app/domain/services/export_service.dart';

import '../../fixtures/export_fixtures.dart';

ByteData _font(String name) =>
    ByteData.sublistView(File('assets/fonts/Nunito/Nunito-$name.ttf').readAsBytesSync());

/// The PDF report: a chart and a daily table per reading, missing days marked in words.
void main() {
  final day20 = DateTime(2026, 10, 20);
  final day21 = DateTime(2026, 10, 21);
  DaySummary hr(DateTime day, double avg, int hours) => DaySummary(
    deviceId: 1,
    key: 'hr',
    day: day,
    min: avg - 10,
    avg: avg,
    max: avg + 10,
    count: 100,
    hours: hours,
  );
  final summaries = {
    day20: {'hr': hr(day20, 72, 0xFFFFFF)},
    day21: {'hr': hr(day21, 105, 0xFF)},
  };

  test('makes a PDF with the reading charts', () async {
    final bytes = await pdfReport(
      exportRequest(format: ExportFormat.pdf, summaries: summaries),
      regular: _font('Regular'),
      bold: _font('Bold'),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('a PDF with no data at all is still made', () async {
    final bytes = await pdfReport(
      exportRequest(format: ExportFormat.pdf),
      regular: _font('Regular'),
      bold: _font('Bold'),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('the daily table: figures and status in words, missing days marked', () {
    final request = exportRequest(format: ExportFormat.pdf, summaries: summaries);
    final chart = summaryChart(exportHr, request.days, summaries, exportNow);

    expect(reportTableRows(request, exportHr, chart), [
      ['D20', '62', '72', '82', 'Normal'],
      ['D21', '95', '105', '115', 'High'],
      for (final d in [22, 23, 24, 25, 26]) ['D$d', '–', '–', '–', 'Missing'],
    ]);
  });
}
