import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/data/db/app_database.dart';
import 'package:generic_flutter_app/data/export/local_export_service.dart';
import 'package:generic_flutter_app/domain/services/export_service.dart';
import 'package:generic_flutter_app/domain/services/file_sharer.dart';

import '../../fixtures/export_fixtures.dart';
import '../../fixtures/test_db.dart';

/// Records what was shared and what the file held at that moment.
class _FakeSharer implements FileSharer {
  _FakeSharer({this.fails = false});

  final bool fails;
  final shared = <(String, String)>[];
  Uint8List? content;

  @override
  Future<void> shareFile(String path, {required String mimeType}) async {
    shared.add((path, mimeType));
    content = File(path).readAsBytesSync();
    if (fails) throw StateError('share sheet failed');
  }
}

/// Export from a real (in-memory) database with made-up readings: the file is made, shared and
/// deleted.
void main() {
  late AppDatabase db;
  late Directory temp;
  late int deviceId;

  setUp(() async {
    db = memoryDatabase();
    temp = await Directory.systemTemp.createTemp('export_test');
    addTearDown(() => temp.delete(recursive: true));
    final userId = await db.usersDao.insertUser(fakeUser());
    deviceId = await db.devicesDao.addDevice(fakeDevice(userId));
  });

  LocalExportService service(FileSharer sharer) => LocalExportService(
    db,
    sharer: sharer,
    tempDir: () async => temp,
    fonts: () async => (
      regular: ByteData.sublistView(
        File('assets/fonts/Nunito/Nunito-Regular.ttf').readAsBytesSync(),
      ),
      bold: ByteData.sublistView(File('assets/fonts/Nunito/Nunito-Bold.ttf').readAsBytesSync()),
    ),
  );

  Future<void> addReading(String key, double value, DateTime at) => db.readingsDao.addAll([
    ReadingsCompanion.insert(
      deviceId: deviceId,
      key: key,
      value: value,
      atMs: at.toUtc().millisecondsSinceEpoch,
    ),
  ]);

  ExportRequest request(ExportFormat format) {
    final r = exportRequest(format: format);
    return ExportRequest(
      deviceId: deviceId,
      deviceName: r.deviceName,
      readings: r.readings,
      charted: r.charted,
      days: r.days,
      summaries: r.summaries,
      now: r.now,
      format: format,
      text: r.text,
      colours: r.colours,
    );
  }

  test('CSV: the window\'s readings, shared as text/csv, then deleted', () async {
    await addReading('hr', 72, DateTime(2026, 10, 21, 9));
    await addReading('hr', 99, DateTime(2026, 10, 19, 9)); // before the window
    final sharer = _FakeSharer();

    await service(sharer).exportAndShare(request(ExportFormat.csv));

    final (path, mime) = sharer.shared.single;
    expect(path, endsWith('history-20261026.csv'));
    expect(mime, 'text/csv');
    final text = utf8.decode(sharer.content!.skip(3).toList());
    expect(text, contains('2026-10-21,09:00:00,Heart rate,72,bpm,Partial'));
    expect(text, isNot(contains(',99,')));
    expect(File(path).existsSync(), isFalse, reason: 'deleted after sharing');
  });

  test('PDF: shared as application/pdf, then deleted', () async {
    final sharer = _FakeSharer();

    await service(sharer).exportAndShare(request(ExportFormat.pdf));

    final (path, mime) = sharer.shared.single;
    expect(path, endsWith('history-20261026.pdf'));
    expect(mime, 'application/pdf');
    expect(String.fromCharCodes(sharer.content!.take(5)), '%PDF-');
    expect(File(path).existsSync(), isFalse);
  });

  test('the file is deleted when sharing fails too', () async {
    final sharer = _FakeSharer(fails: true);

    await expectLater(service(sharer).exportAndShare(request(ExportFormat.csv)), throwsStateError);

    expect(File(sharer.shared.single.$1).existsSync(), isFalse);
  });
}
