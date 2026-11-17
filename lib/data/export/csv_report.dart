import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/export/export_rows.dart';
import '../../domain/services/export_service.dart';

/// The CSV of [request]: a header, then one row per stored reading with its day's status, and a
/// "No data" row for a day without readings (see [exportRows]). UTF-8 with a byte order mark, so
/// spreadsheets show "°C" and "SpO₂". Made on another isolate: a week of readings sent every
/// second is hundreds of thousands of rows.
Future<Uint8List> csvReport(ExportRequest request, List<Sample> samples) {
  final text = request.text;
  final table = [
    [
      text.csvDate,
      text.csvTime,
      text.csvReading,
      text.csvValue,
      text.csvUnit,
      text.csvDayStatus,
    ].map(safeText).toList(),
    for (final r in exportRows(request, samples))
      [r.date, r.time, safeText(r.reading), r.value, safeText(r.unit), safeText(r.dayStatus)],
  ];
  return Isolate.run(() => csvBytes(table));
}

/// [table] as CSV bytes: UTF-8 with a byte order mark, fields quoted only when needed.
Uint8List csvBytes(List<List<String>> table) =>
    Uint8List.fromList(utf8.encode(Csv(addBom: true).encode(table)));

/// [text] that a spreadsheet will not run as a formula: one starting with `=`, `+`, `-`, `@`, a
/// tab or a carriage return gets a leading apostrophe (OWASP, CSV injection). Only for text
/// fields; numbers such as "-2.5" are left as they are.
String safeText(String text) => text.isNotEmpty && '=+-@\t\r'.contains(text[0]) ? "'$text" : text;
