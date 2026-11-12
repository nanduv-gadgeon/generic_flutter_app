import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/device_profile.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';
import 'package:generic_flutter_app/presentation/device_settings/device_settings_sections.dart';
import 'package:generic_flutter_app/presentation/strings/device_settings_strings.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/ief_profile.dart';
import '../../fixtures/l10n.dart';
import '../../fixtures/ppg_motion_profile.dart';
import 'device_settings_test_app.dart';

Finder _row(String label, String value) => find.byWidgetPredicate(
  (w) => w is InfoRow && w.label == label && w.value == value,
  description: 'row "$label: $value"',
);

void main() {
  testWidgets('shows the title, the name and the section headings', (tester) async {
    await pumpSettings(tester, device: band);

    expect(find.text('Device settings'), findsOneWidget);
    expect(find.text('Device name'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Test band');
    for (final heading in ['CONNECTION', 'HEARTBEAT', 'ALERTS']) {
      expect(find.text(heading), findsOneWidget);
    }
    // The sampling interval is a row in the heartbeat card now, not its own section.
    expect(find.text('SAMPLING INTERVAL'), findsNothing);
  });

  // Every read-only row of the mockup: label -> value for [band].
  final rows = {
    'Type': 'Test device',
    'Connection': 'Bluetooth LE',
    'MAC address': 'AA:BB:CC:00:00:01',
    'Signal (RSSI)': '—',
    'Firmware': 'v1.4.2',
    'Battery': '78%',
    // The test profile has no heartbeat block: the defaults.
    'Heartbeat interval': 'Every 1 min',
    'Last heartbeat': '12 s ago',
    'Offline after': '3 missed (3 min)',
    'Device status': 'Not connected',
  };
  for (final MapEntry(key: label, value: value) in rows.entries) {
    testWidgets('row $label shows "$value"', (tester) async {
      await pumpSettings(tester, device: band);

      expect(_row(label, value), findsOneWidget);
    });
  }

  testWidgets("the heartbeat rows come from the profile's heartbeat block", (tester) async {
    await pumpSettings(
      tester,
      device: band,
      heartbeat: {'intervalSeconds': 30, 'offlineAfterMissed': 4},
    );

    expect(_row('Heartbeat interval', 'Every 30 s'), findsOneWidget);
    expect(_row('Offline after', '4 missed (2 min)'), findsOneWidget);
  });

  final statuses = <String, (ActiveLink?, String)>{
    'connected': ((deviceId: 7, status: LiveStatus.streaming, online: true), 'Online'),
    'missing heartbeats': ((deviceId: 7, status: LiveStatus.streaming, online: false), 'Offline'),
    'another device connected': (
      (deviceId: 8, status: LiveStatus.streaming, online: true),
      'Not connected',
    ),
  };
  for (final MapEntry(key: name, value: (link, text)) in statuses.entries) {
    testWidgets('device status when $name says "$text"', (tester) async {
      await pumpSettings(tester, device: band, activeLink: link);

      expect(_row('Device status', text), findsOneWidget);
    });
  }

  testWidgets('a Wi‑Fi device shows its IP address', (tester) async {
    await pumpSettings(
      tester,
      device: band.copyWith(transport: Transport.wifi, address: 'test-01', ipAddress: '10.0.0.5'),
    );

    expect(_row('Connection', 'Wi‑Fi'), findsOneWidget);
    expect(_row('IP address', '10.0.0.5'), findsOneWidget);
    expect(find.text('MAC address'), findsNothing);
  });

  testWidgets('values the phone does not have yet show a dash', (tester) async {
    await pumpSettings(
      tester,
      device: band.copyWith(firmware: null, batteryPercent: null, lastHeartbeatAt: null),
    );

    for (final label in ['Firmware', 'Battery', 'Last heartbeat']) {
      expect(_row(label, '—'), findsOneWidget, reason: label);
    }
  });

  testWidgets('each alert shows its limit and switch', (tester) async {
    await pumpSettings(tester, device: band);

    expect(find.text('Battery below 15 %', findRichText: true), findsOneWidget);
    expect(find.text('Current above 25 u', findRichText: true), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value);
    expect(switches, [true, false]);
  });

  testWidgets('turning an alert off saves it', (tester) async {
    await pumpSettings(tester, device: band);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    verify(() => devices.setAlertEnabled(7, 'battery', enabled: false)).called(1);
  });

  testWidgets('a new name is saved on Done', (tester) async {
    await pumpSettings(tester, device: band);

    await tester.enterText(find.byType(TextField), '  Kitchen band ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => devices.rename(7, 'Kitchen band')).called(1);
  });

  for (final bad in ['', '   ', 'B' * 41, '"', "'", r'#$%']) {
    testWidgets('the name "${bad.length > 12 ? '${bad.length} chars' : bad}" is not saved', (
      tester,
    ) async {
      await pumpSettings(tester, device: band);

      await tester.enterText(find.byType(TextField), bad);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Use letters or numbers, up to 40 characters.'), findsOneWidget);
      verifyNever(() => devices.rename(any(), any()));
    });
  }

  testWidgets('the unchanged name is not saved again', (tester) async {
    await pumpSettings(tester, device: band);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verifyNever(() => devices.rename(any(), any()));
  });

  testWidgets('the sampling interval is a row under Device status, from the config', (
    tester,
  ) async {
    await pumpSettings(tester, device: band);

    // The test config sets no rate, so the device decides.
    expect(_row('Sampling interval', 'Set by the device'), findsOneWidget);
    for (final option in ['1 s', '5 s', '30 s', '1 min']) {
      expect(find.text(option), findsNothing); // no longer a hard-coded choice
    }
  });

  // The VitaCare config's rates: worked-out readings, or stored logs fetched while connected.
  final intervals = <String, (DeviceProfile, Duration)>{
    'the PPG sensor: 100 samples at 100 Hz': (ppgMotionProfile(), const Duration(seconds: 1)),
    'the IEF device: its logs every 60 s': (iefProfile(), const Duration(minutes: 1)),
  };
  for (final MapEntry(key: name, value: (profile, every)) in intervals.entries) {
    test('readings interval of $name', () => expect(readingsInterval(profile), every));
  }

  test('the row reads "Every 1 s"', () {
    expect(en.deviceSettingsEvery(const Duration(seconds: 1)), 'Every 1 s');
    expect(en.deviceSettingsEvery(const Duration(minutes: 1)), 'Every 1 min');
  });

  testWidgets('screen readers hear each alert switch with its limit', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSettings(tester, device: band);

    expect(find.bySemanticsLabel(RegExp('Battery below 15 %')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an unknown device says it is not on this phone', (tester) async {
    await pumpSettings(tester);

    expect(find.text('This device is no longer on this phone.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  // TC-DST-003: a blank name is never saved, and leaving does not hide the message.
  for (final blank in ['', '   ']) {
    testWidgets('Back with the name "$blank" stays, shows the message and keeps the old name', (
      tester,
    ) async {
      await pumpSettings(tester, device: band);

      await tester.enterText(find.byType(TextField), blank);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('home page'), findsNothing);
      expect(find.text('Use letters or numbers, up to 40 characters.'), findsOneWidget);
      verifyNever(() => devices.rename(any(), any()));
    });

    testWidgets("the phone's back with the name \"$blank\" stays too", (tester) async {
      await pumpSettings(tester, device: band);

      await tester.enterText(find.byType(TextField), blank);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home page'), findsNothing);
      expect(find.text('Use letters or numbers, up to 40 characters.'), findsOneWidget);
      verifyNever(() => devices.rename(any(), any()));
    });
  }

  testWidgets("the phone's back saves a changed name and returns", (tester) async {
    await pumpSettings(tester, device: band);

    await tester.enterText(find.byType(TextField), 'Kitchen band');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    verify(() => devices.rename(7, 'Kitchen band')).called(1);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('after fixing a blank name, Back saves it and returns', (tester) async {
    await pumpSettings(tester, device: band);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kitchen band');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    verify(() => devices.rename(7, 'Kitchen band')).called(1);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('Done then focus loss saves the new name once', (tester) async {
    await pumpSettings(tester, device: band);

    await tester.enterText(find.byType(TextField), 'Kitchen band');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    verify(() => devices.rename(7, 'Kitchen band')).called(1);
  });

  testWidgets('Back saves a changed name and returns', (tester) async {
    await pumpSettings(tester, device: band);

    await tester.enterText(find.byType(TextField), 'Kitchen band');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    verify(() => devices.rename(7, 'Kitchen band')).called(1);
    expect(find.text('home page'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits a small phone with double text size (${brightness.name})', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSettings(tester, device: band, brightness: brightness, size: const Size(320, 568));

      await tester.scrollUntilVisible(
        find.text('Remove device'),
        200,
        scrollable: find
            .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
            .first,
      );
      expect(tester.takeException(), isNull); // no overflow
    });
  }
}
