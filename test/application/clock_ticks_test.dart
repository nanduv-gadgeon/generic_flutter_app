import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/alerts_provider.dart';
import 'package:generic_flutter_app/application/dashboard_provider.dart';
import 'package:generic_flutter_app/application/devices_provider.dart';

/// The "ago" clocks catch up as soon as a hidden tab is shown again, instead of keeping the old
/// time until their next tick (which made new alerts say "Just now").
void main() {
  final ticks = <String, (ProviderListenable<AsyncValue<DateTime>>, Duration)>{
    'minute tick (Alerts)': (minuteTickProvider, const Duration(minutes: 1)),
    'second tick (dashboard, Home, Device settings)': (
      dashboardNowProvider,
      const Duration(seconds: 1),
    ),
  };
  for (final MapEntry(key: name, value: (provider, every)) in ticks.entries) {
    testWidgets('$name: up to date at once when shown again', (tester) async {
      var now = DateTime(2026, 11, 23, 9);
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWithValue(() => now)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder(
              valueListenable: visible,
              builder: (_, shown, _) => TickerMode(
                enabled: shown,
                child: Consumer(builder: (_, ref, _) => Text('${ref.watch(provider).value}')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      String shown() => tester.widget<Text>(find.byType(Text)).data!;
      expect(shown(), '$now');

      // Hidden (another tab) for 5 ticks.
      visible.value = false;
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        now = now.add(every);
        await tester.pump(every);
      }
      now = now.add(every ~/ 2);
      visible.value = true;
      await tester.pump();
      await tester.pump();

      expect(shown(), '$now', reason: 'caught up when shown');

      now = now.add(every);
      await tester.pump(every);
      expect(shown(), '$now', reason: 'then ticks on');
    });
  }
}
