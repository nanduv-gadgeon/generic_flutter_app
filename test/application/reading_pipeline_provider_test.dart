import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/application/auth_controller.dart';
import 'package:generic_flutter_app/application/reading_pipeline_provider.dart';
import 'package:generic_flutter_app/core/di/services.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/fake_auth.dart';
import '../fixtures/fake_live_readings.dart';

void main() {
  late MockAuthService auth;
  late FakeLiveReadings live;
  late ProviderContainer container;

  setUp(() {
    auth = MockAuthService();
    live = FakeLiveReadings();
    when(() => auth.logout()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        liveReadingsProvider.overrideWithValue(live),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() async {
    container.listen(readingPipelineProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    await pumpEventQueue();
  }

  test('a restored session lets the user\'s devices be followed', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);

    await settle();

    expect(live.started, [fakeUser.id]);
    expect(container.read(readingPipelineProvider), fakeUser.id);
  });

  test('logging out disconnects the device', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => fakeUser);
    await settle();

    await container.read(authControllerProvider.notifier).logout();
    await pumpEventQueue();

    expect(live.stops, greaterThan(0));
    expect(container.read(readingPipelineProvider), isNull);
  });

  test('nobody logged in starts nothing', () async {
    when(() => auth.currentUser()).thenAnswer((_) async => null);

    await settle();

    expect(live.started, isEmpty);
  });
}
