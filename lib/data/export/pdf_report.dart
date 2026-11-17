import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/export/export_rows.dart';
import '../../domain/history/summary_chart.dart';
import '../../domain/models/reading.dart';
import '../../domain/services/export_service.dart';

/// The PDF report of [request] (requirement 6.6, "Charts and daily summary"): a title, then for
/// each charted reading its 7-day bars (as on History's summary) and a table of each day's Min /
/// Average / Max with its status in words, so days with missing data are marked. [regular] and
/// [bold] are the app's font (TrueType), so units such as "°C" print.
Future<Uint8List> pdfReport(
  ExportRequest request, {
  required ByteData regular,
  required ByteData bold,
}) {
  final text = request.text;
  final colours = request.colours;
  final doc = pw.Document(
    title: text.reportTitle,
    theme: pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold)),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => [
        pw.Text(
          text.reportTitle,
          style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(text.reportSubtitle, style: const pw.TextStyle(fontSize: 12)),
        pw.Text(text.reportMade, style: _muted(colours, 9)),
        pw.SizedBox(height: 4),
        pw.Text(text.reportNote, style: _muted(colours, 9)),
        for (final reading in request.charted) ..._section(request, reading),
      ],
    ),
  );
  return doc.save();
}

List<pw.Widget> _section(ExportRequest request, Reading reading) {
  final text = request.text;
  final chart = summaryChart(reading, request.days, request.summaries, request.now);
  final unit = text.units[reading.key] ?? reading.unit;
  final title = text.chartTitles[reading.key] ?? reading.label;
  return [
    pw.SizedBox(height: 20),
    pw.Text(
      unit.isEmpty ? title : '$title ($unit)',
      style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 8),
    _bars(request, reading, chart),
    pw.SizedBox(height: 8),
    _table(request, reading, chart),
  ];
}

/// One bar per day, as on History's summary: today in the brand colour, values out of range in
/// the warning colour, a day without data as a dashed box with "No data" over it.
pw.Widget _bars(ExportRequest request, Reading reading, SummaryChart chart) {
  final text = request.text;
  final colours = request.colours;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      for (final day in chart.days)
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                day.value == null ? text.noData : plainValue(reading, day.value!),
                style: day.value == null
                    ? pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(colours.danger))
                    : _muted(colours, 7),
              ),
              pw.SizedBox(height: 3),
              if (day.value case final value?)
                pw.Container(
                  width: 18,
                  height: 10 + barFraction(chart, value) * 60,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(_barColour(colours, day)),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                )
              else
                pw.Container(
                  width: 18,
                  height: 24,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor.fromInt(colours.danger),
                      style: pw.BorderStyle.dashed,
                    ),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
              pw.SizedBox(height: 3),
              pw.Text(text.barLabels[day.day.start] ?? '', style: _muted(colours, 8)),
            ],
          ),
        ),
    ],
  );
}

int _barColour(ExportColours colours, SummaryDay day) {
  if (day.flag != SummaryFlag.none) return colours.warn;
  return day.isToday ? colours.primary : colours.barSoft;
}

/// The PDF table of [reading]: Date, Min, Average, Max and the status in words, oldest day
/// first; a day without data has "–" and Missing.
List<List<String>> reportTableRows(ExportRequest request, Reading reading, SummaryChart chart) {
  final text = request.text;
  String figure(double v) => plainValue(reading, v);
  return [
    for (final day in chart.days)
      if (request.summaries[day.day.start]?[reading.key] case final s?)
        [
          text.dayLabels[day.day.start] ?? '',
          figure(s.min),
          figure(s.avg),
          figure(s.max),
          text.rowStatus[rowStatus(day)] ?? '',
        ]
      else
        [
          text.dayLabels[day.day.start] ?? '',
          '–',
          '–',
          '–',
          text.rowStatus[SummaryRowStatus.missing] ?? '',
        ],
  ];
}

pw.Widget _table(ExportRequest request, Reading reading, SummaryChart chart) {
  final text = request.text;
  final colours = request.colours;
  return pw.TableHelper.fromTextArray(
    headers: [
      text.columnDate,
      text.columnMin,
      text.columnAverage,
      text.columnMax,
      text.columnStatus,
    ],
    data: reportTableRows(request, reading, chart),
    headerStyle: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 9),
    headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(colours.barSoft)),
    border: pw.TableBorder.all(color: PdfColor.fromInt(colours.border), width: 0.5),
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  );
}

pw.TextStyle _muted(ExportColours colours, double size) =>
    pw.TextStyle(fontSize: size, color: PdfColor.fromInt(colours.muted));
