import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/decoder/decoded_packet.dart';
import '../../domain/export/export_rows.dart';
import '../../domain/services/export_service.dart';
import '../../domain/services/file_sharer.dart';
import '../db/app_database.dart';
import 'csv_report.dart';
import 'pdf_report.dart';

/// Loads the report's font: regular and bold TrueType.
typedef FontLoader = Future<({ByteData regular, ByteData bold})> Function();

/// [ExportService] over the local database: reads the device's readings of the days asked for,
/// makes the CSV or PDF in a temporary folder, opens the share sheet and deletes the file
/// afterwards (architecture: exports are made only on request and removed after sharing).
/// Makes no network calls. Readings are health data: never logged.
class LocalExportService implements ExportService {
  LocalExportService(
    this._db, {
    required this._sharer,
    required this._tempDir,
    required this._fonts,
  });

  final AppDatabase _db;
  final FileSharer _sharer;
  final Future<Directory> Function() _tempDir;
  final FontLoader _fonts;

  @override
  Future<void> exportAndShare(ExportRequest request) async {
    final bytes = switch (request.format) {
      ExportFormat.csv => await csvReport(request, await _samples(request)),
      ExportFormat.pdf => await _pdf(request),
    };
    final file = File('${(await _tempDir()).path}/${fileName(request)}');
    await file.writeAsBytes(bytes, flush: true);
    try {
      await _sharer.shareFile(file.path, mimeType: mimeTypeOf(request.format));
    } finally {
      try {
        await file.delete();
      } on FileSystemException catch (e) {
        // The OS clears its temporary folder anyway.
        debugPrint('Export: could not delete the file: ${e.runtimeType}');
      }
    }
  }

  Future<List<Sample>> _samples(ExportRequest request) async {
    final rows = await _db.readingsDao.between(
      request.deviceId,
      request.days.first.start.toUtc().millisecondsSinceEpoch,
      request.days.last.end.toUtc().millisecondsSinceEpoch,
    );
    return [
      for (final r in rows)
        Sample(r.key, r.value, DateTime.fromMillisecondsSinceEpoch(r.atMs, isUtc: true)),
    ];
  }

  Future<Uint8List> _pdf(ExportRequest request) async {
    final fonts = await _fonts();
    return pdfReport(request, regular: fonts.regular, bold: fonts.bold);
  }
}

/// "history-20261026.csv": named by the day it was made. The device's name is left out, as it
/// may hold characters a file name cannot.
String fileName(ExportRequest request) {
  final day = isoDate(request.now).replaceAll('-', '');
  return 'history-$day.${request.format.name}';
}

/// Where the bundled font [family] keeps its regular or bold TrueType file.
String reportFontPath(String family, {required bool bold}) =>
    'assets/fonts/$family/$family-${bold ? 'Bold' : 'Regular'}.ttf';

String mimeTypeOf(ExportFormat format) => switch (format) {
  ExportFormat.csv => 'text/csv',
  ExportFormat.pdf => 'application/pdf',
};
