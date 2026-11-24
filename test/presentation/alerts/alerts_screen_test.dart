import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/alerts/alert.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'alerts_test_app.dart';

const _filters = ['All', 'Readings', 'Device events', 'Episodes', 'Channels', 'Device health'];

const _mixedTitles = [
  'Heart rate above 110 bpm',
  'Battery low (12%)',
  'Missed 3 heartbeats – device offline',
];

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('no alerts: the empty card, and Mark all read is off', (tester) async {
    await pumpAlerts(tester);

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('No alerts'), findsOneWidget);
    expect(find.text('Alerts from your devices will show here.'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Mark all read')).onPressed,
      isNull,
    );
  });

  testWidgets('shows each alert with its title, device, time and source, newest first', (
    tester,
  ) async {
    await pumpAlerts(tester, items: mixedAlerts);

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

  testWidgets('screen readers hear the exact time, not "10 min ago"', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAlerts(tester, items: mixedAlerts);

    expect(
      find.bySemanticsLabel(
        RegExp(
          'Heart rate above 110 bpm.*Test band, Saturday, October 24, 2026 at 11:50',
          dotAll: true,
        ),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('min ago')), findsNothing);
    semantics.dispose();
  });

  testWidgets("times use the 24-hour clock, as in the mockup, whatever the phone's setting", (
    tester,
  ) async {
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
    final day = alertsNow.subtract(const Duration(days: 1, hours: 5));
    await pumpAlerts(tester, items: [alertItem(AlertKind.offline, at: day)]);

    expect(find.text('Test band · Yesterday, 07:00'), findsOneWidget);
  });

  testWidgets('unread alerts are announced as unread; read ones are not', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAlerts(tester, items: mixedAlerts);

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
    final calls = await pumpAlerts(tester, items: mixedAlerts);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(calls.markAllRead, 1);
    expect(find.text('All alerts marked as read'), findsOneWidget);
  });

  testWidgets('Mark all read is off when every alert is read', (tester) async {
    await pumpAlerts(tester, items: [alertItem(AlertKind.offline, at: alertsNow, read: true)]);

    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Mark all read')).onPressed,
      isNull,
    );
  });

  testWidgets('Mark all read failing says so', (tester) async {
    await pumpAlerts(tester, items: mixedAlerts, markAllRead: () async => throw Exception('db'));

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't mark the alerts as read. Try again."), findsOneWidget);
    expect(find.text('All alerts marked as read'), findsNothing);
  });

  testWidgets('alerts that cannot be loaded say so', (tester) async {
    await pumpAlerts(tester, error: Exception('db'));

    expect(find.text("Couldn't load your alerts. Try again later."), findsOneWidget);
  });

  testWidgets('a long list scrolls to the oldest alert', (tester) async {
    final many = [
      for (var i = 0; i < 30; i++)
        alertItem(
          AlertKind.above,
          at: alertsNow.subtract(Duration(hours: i * 3)),
          reading: hrReading,
        ),
    ];
    await pumpAlerts(tester, items: many);

    await tester.scrollUntilVisible(
      find.text('Test band · Tue 20 Oct, 21:00'),
      300,
      // The first is the list; the filter row scrolls sideways inside it.
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Test band · Tue 20 Oct, 21:00'), findsOneWidget);
  });

  testWidgets('shows the six filters with All picked', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAlerts(tester, items: mixedAlerts);

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
      await pumpAlerts(tester, items: mixedAlerts);
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
      await pumpAlerts(tester, items: mixedAlerts);

      await tester.ensureVisible(find.text(filter));
      await tester.tap(find.text(filter));
      await tester.pumpAndSettle();

      expect(find.text('No alerts'), findsOneWidget);
      expect(find.text('No alerts of this type yet.'), findsOneWidget);
      expect(find.text('Heart rate above 110 bpm'), findsNothing);
    });
  }

  testWidgets('Mark all read under a filter still marks every alert', (tester) async {
    final calls = await pumpAlerts(
      tester,
      items: [
        alertItem(AlertKind.above, at: alertsNow, reading: hrReading, read: true),
        alertItem(AlertKind.offline, at: alertsNow),
      ],
    );
    await tester.tap(find.text('Readings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(calls.markAllRead, 1, reason: 'an unread alert under another filter keeps it on');
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
      await pumpAlerts(
        tester,
        items: mixedAlerts,
        brightness: brightness,
        size: size,
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Heart rate above 110 bpm'), findsOneWidget);
    });
  }
}
