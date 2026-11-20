import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/alerts_provider.dart';
import 'package:generic_flutter_app/core/config/app_config.dart';
import 'package:generic_flutter_app/core/theme/app_theme.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:generic_flutter_app/presentation/alerts/alerts_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fixtures/l10n.dart';

const _theme = ThemeConfig(
  primary: '#123456',
  accent: '#ABCDEF',
  font: 'TestFont',
  cornerRadius: 20,
  cornerRadiusSmall: 12,
  mode: ThemeModeSetting.light,
);

/// Saturday 24 Oct 2026, 12:00 on the phone's clock.
final _now = DateTime(2026, 10, 24, 12);

const _hr = Reading(key: 'hr', label: 'Heart rate', unit: 'bpm', icon: ReadingIcon.pulse);

AlertListItem _item(
  AlertKind kind, {
  required DateTime at,
  bool read = false,
  Reading? reading,
  String device = 'Test band',
}) => (
  alert: RaisedAlert(
    id: at.millisecondsSinceEpoch,
    deviceId: 1,
    kind: kind,
    key: reading?.key ?? (kind == AlertKind.batteryLow ? 'battery' : null),
    value: kind == AlertKind.batteryLow ? 12 : 115,
    limit: kind == AlertKind.batteryLow ? 15 : 110,
    at: at,
    read: read,
  ),
  deviceName: device,
  reading: reading,
  offlineAfterMissed: 3,
);

final _mixed = [
  _item(AlertKind.above, at: _now.subtract(const Duration(minutes: 10)), reading: _hr),
  _item(AlertKind.batteryLow, at: DateTime(2026, 10, 24, 7, 10)),
  _item(AlertKind.offline, at: DateTime(2026, 10, 23, 18, 40), read: true),
];

const _filters = ['All', 'Readings', 'Device events', 'Episodes', 'Channels', 'Device health'];

const _mixedTitles = [
  'Heart rate above 110 bpm',
  'Battery low (12%)',
  'Missed 3 heartbeats – device offline',
];

/// Pumps the Alerts tab with [items]; returns how often Mark all read ran.
Future<List<int>> _pump(
  WidgetTester tester, {
  List<AlertListItem> items = const [],
  Object? error,
  Future<void> Function()? markAllRead,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <int>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertListProvider.overrideWith(
          (ref) => error == null ? Stream.value(items) : Stream.error(error),
        ),
        minuteTickProvider.overrideWith((ref) => Stream.value(_now)),
        markAllAlertsReadProvider.overrideWithValue(() async {
          calls.add(1);
          await markAllRead?.call();
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(_theme, brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: AlertsScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('no alerts: the empty card, and Mark all read is off', (tester) async {
    await _pump(tester);

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('Alerts from your devices will show here.'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });

  testWidgets('shows each alert with its title, device, time and source, newest first', (
    tester,
  ) async {
    await _pump(tester, items: _mixed);

    final titles = [
      'Heart rate above 110 bpm',
      'Battery low (12%)',
      'Missed 3 heartbeats – device offline',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget);
    }
    expect(
      [for (final t in titles) tester.getTopLeft(find.text(t)).dy],
      orderedEquals(
        [
          ...[for (final t in titles) tester.getTopLeft(find.text(t)).dy],
        ]..sort(),
      ),
    );
    expect(find.text('Test band · 10 min ago'), findsOneWidget);
    expect(find.text('Test band · Today, 07:10'), findsOneWidget);
    expect(find.text('Test band · Yesterday, 18:40'), findsOneWidget);
    expect(find.text('THRESHOLD'), findsOneWidget);
    expect(find.text('DEVICE HEALTH'), findsNWidgets(2));
    expect(find.text('No alerts'), findsNothing);
  });

  testWidgets('unread alerts are announced as unread; read ones are not', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, items: _mixed);

    final unread = find.bySemanticsLabel(RegExp('Unread'));
    expect(unread, findsNWidgets(2));
    expect(
      find.bySemanticsLabel(RegExp('Heart rate above 110 bpm.*Threshold.*Unread', dotAll: true)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('device offline.*Unread', dotAll: true)), findsNothing);
    semantics.dispose();
  });

  testWidgets('Mark all read marks them and says so', (tester) async {
    final calls = await _pump(tester, items: _mixed);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(calls, [1]);
    expect(find.text('All alerts marked as read'), findsOneWidget);
  });

  testWidgets('Mark all read is off when every alert is read', (tester) async {
    await _pump(tester, items: [_item(AlertKind.offline, at: _now, read: true)]);

    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
  });

  testWidgets('Mark all read failing says so', (tester) async {
    await _pump(tester, items: _mixed, markAllRead: () async => throw Exception('db'));

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't mark the alerts as read. Try again."), findsOneWidget);
    expect(find.text('All alerts marked as read'), findsNothing);
  });

  testWidgets('alerts that cannot be loaded say so', (tester) async {
    await _pump(tester, error: Exception('db'));

    expect(find.text("Couldn't load your alerts. Try again later."), findsOneWidget);
  });

  testWidgets('a long list scrolls to the oldest alert', (tester) async {
    final many = [
      for (var i = 0; i < 30; i++)
        _item(
          AlertKind.above,
          at: _now.subtract(Duration(hours: i * 3)),
          reading: _hr,
        ),
    ];
    await _pump(tester, items: many);

    await tester.scrollUntilVisible(
      find.text('Test band · Wed 21 Oct, 06:00'),
      300,
      // The first is the list; the filter row scrolls sideways inside it.
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Test band · Wed 21 Oct, 06:00'), findsOneWidget);
  });

  testWidgets('shows the six filters with All picked', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, items: _mixed);

    for (final label in _filters) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(tester.getSemantics(find.text('All')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.text('Readings')), isSemantics(isSelected: false));
    semantics.dispose();
  });

  // filter -> titles shown
  final filtered = <String, List<String>>{
    'Readings': ['Heart rate above 110 bpm'],
    'Device health': ['Battery low (12%)', 'Missed 3 heartbeats – device offline'],
    'All': [
      'Heart rate above 110 bpm',
      'Battery low (12%)',
      'Missed 3 heartbeats – device offline',
    ],
  };
  for (final MapEntry(key: filter, value: titles) in filtered.entries) {
    testWidgets('the $filter filter shows only its alerts', (tester) async {
      await _pump(tester, items: _mixed);
      await tester.tap(find.text('Readings'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(filter));
      await tester.tap(find.text(filter));
      await tester.pumpAndSettle();

      for (final title in _mixedTitles) {
        expect(find.text(title), titles.contains(title) ? findsOneWidget : findsNothing);
      }
    });
  }

  for (final filter in ['Device events', 'Episodes', 'Channels']) {
    testWidgets('$filter, with no such alerts, says there are none of this type', (tester) async {
      await _pump(tester, items: _mixed);

      await tester.ensureVisible(find.text(filter));
      await tester.tap(find.text(filter));
      await tester.pumpAndSettle();

      expect(find.text('No alerts'), findsOneWidget);
      expect(find.text('No alerts of this type yet.'), findsOneWidget);
      expect(find.text('Heart rate above 110 bpm'), findsNothing);
    });
  }

  testWidgets('Mark all read under a filter still marks every alert', (tester) async {
    final calls = await _pump(
      tester,
      items: [
        _item(AlertKind.above, at: _now, reading: _hr, read: true),
        _item(AlertKind.offline, at: _now),
      ],
    );
    await tester.tap(find.text('Readings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(calls, [1], reason: 'an unread alert under another filter keeps it on');
  });

  // (brightness, size, text scale) a user may have
  final layouts = <(Brightness, Size, double)>[
    (Brightness.dark, const Size(390, 844), 1),
    (Brightness.light, const Size(320, 568), 2),
    (Brightness.dark, const Size(320, 568), 2),
  ];
  for (final (brightness, size, scale) in layouts) {
    testWidgets('lays out in ${brightness.name} at ${size.width}×${size.height}, text ×$scale', (
      tester,
    ) async {
      await _pump(tester, items: _mixed, brightness: brightness, size: size, textScale: scale);

      expect(tester.takeException(), isNull);
      expect(find.text('Heart rate above 110 bpm'), findsOneWidget);
    });
  }
}
