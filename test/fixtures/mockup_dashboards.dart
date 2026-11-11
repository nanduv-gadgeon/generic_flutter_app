import 'dart:math' as math;

import 'package:generic_flutter_app/domain/decoder/decoded_packet.dart';
import 'package:generic_flutter_app/domain/models/user_device.dart';
import 'package:generic_flutter_app/domain/services/live_readings.dart';

import 'dashboard_harness.dart';

/// The values the mockup's live dashboards show (screens 13–21). All made up.
final mockupNow = DateTime(2026, 11, 11, 9);

/// One mockup dashboard: the device, what is stored and what arrives live.
final class MockupDashboard {
  MockupDashboard({
    required this.device,
    required this.values,
    required this.battery,
    this.heartbeatAgo,
    this.trends = const {},
    this.today = const {},
    this.events = const [],
    this.waveform,
  });

  final UserDevice device;

  /// Live values by reading key.
  final Map<String, double> values;
  final double battery;
  final Duration? heartbeatAgo;

  /// Stored values of the last 30 minutes by key, oldest first; the last one 2 s ago.
  final Map<String, List<double>> trends;

  /// Stored readings of today by key: (hour, minute, value).
  final Map<String, List<(int, int, double)>> today;
  final List<DeviceEvent> events;

  /// Key and samples of a live waveform.
  final (String, List<double>)? waveform;

  FakeReadingRepository readings() {
    final repo = FakeReadingRepository();
    for (final MapEntry(:key, value: values) in trends.entries) {
      repo.series[(device.id, key)] = [
        for (final (i, v) in values.indexed)
          Sample(key, v, mockupNow.subtract(Duration(seconds: 2 + (values.length - 1 - i) * 200))),
      ];
    }
    for (final MapEntry(:key, value: rows) in today.entries) {
      repo.series[(device.id, key)] = [
        for (final (h, m, v) in rows)
          Sample(key, v, DateTime(mockupNow.year, mockupNow.month, mockupNow.day, h, m).toUtc()),
      ];
    }
    return repo;
  }

  FakeDeviceEventRepository eventStore() => FakeDeviceEventRepository()..events[device.id] = events;

  /// What the device sends once the dashboard is open.
  List<LiveUpdate> updates() => [
    const LiveStatusChanged(LiveStatus.streaming),
    for (final MapEntry(:key, :value) in values.entries) LiveValue(Sample(key, value, mockupNow)),
    LiveValue(Sample('battery', battery, mockupNow)),
    if (heartbeatAgo case final ago?) LiveHeartbeat(online: true, lastAt: mockupNow.subtract(ago)),
    if (waveform case (final key, final samples))
      for (final v in samples) LiveValue(Sample(key, v, mockupNow)),
  ];
}

DateTime _at(int h, int m) => DateTime(2026, 11, 11, h, m).toUtc();

/// A made-up ECG trace: one PQRST shape per beat at [bpm], [count] samples at [hz].
List<double> _ecg(int count, {int hz = 250, int bpm = 76}) {
  final beat = hz * 60 / bpm;
  double bump(double x, double centre, double width, double height) =>
      height * math.exp(-math.pow((x - centre) / width, 2));
  return [
    for (var i = 0; i < count; i++)
      () {
        final x = (i % beat) / beat;
        return bump(x, 0.18, 0.03, 0.12) -
            bump(x, 0.30, 0.008, 0.15) +
            bump(x, 0.33, 0.012, 1.0) -
            bump(x, 0.36, 0.01, 0.25) +
            bump(x, 0.58, 0.05, 0.22);
      }(),
  ];
}

const _hub = <(String, double?)>[
  ('ch01', 62.4),
  ('ch02', 71.8),
  ('ch03', 48.2),
  ('ch04', 66.0),
  ('ch05', 31.5),
  ('ch06', 24.1),
  ('ch07', 8.9),
  ('ch08', 6.2),
  ('ch09', 3.4),
  ('ch10', 3.1),
  ('ch11', 1.8),
  ('ch12', 2.2),
  ('ch13', 2.1),
  ('ch14', 1.8),
  ('ch15', 7.4),
  ('ch16', 3.2),
  ('ch17', 1.1),
  ('ch18', 2.9),
  ('ch19', 45),
  ('ch20', 52),
  ('ch21', null),
  ('ch22', 38),
  ('ch23', 42.6),
  ('ch24', 12.3),
];

/// The 9 mockup dashboards by profile id, in the Add device order.
final mockupDashboards = <String, MockupDashboard>{
  'smart_band_v1': MockupDashboard(
    device: const UserDevice(id: 1, name: 'Smart Band S2', profileId: 'smart_band_v1'),
    values: {
      'hr': 72,
      'spo2': 98,
      'bp': 118,
      'bp_dia': 76,
      'temp': 36.6,
      'steps': 6482,
      'sleep': 7.2,
      'resp': 16,
    },
    battery: 78,
    heartbeatAgo: const Duration(seconds: 12),
    trends: {
      'hr': [68, 71, 74, 70, 76, 73, 75, 71, 72],
    },
  ),
  'env_sensor_v1': MockupDashboard(
    device: const UserDevice(
      id: 2,
      name: 'Env Sensor – Lab 2',
      profileId: 'env_sensor_v1',
      transport: Transport.wifi,
    ),
    values: {
      'temp': 24.3,
      'co2': 1140,
      'hum': 56,
      'pm25': 12,
      'press': 1012,
      'light': 320,
      'tvoc': 0.21,
    },
    battery: 42,
    heartbeatAgo: const Duration(seconds: 45),
    trends: {
      'temp': [23.6, 23.9, 24.2, 24.0, 24.5, 24.4, 24.1, 24.3],
    },
  ),
  'wearable_patch_v1': MockupDashboard(
    device: const UserDevice(id: 3, name: 'Cardio Patch P1', profileId: 'wearable_patch_v1'),
    values: {'hr': 78, 'temp': 36.9, 'resp': 18, 'hrv': 42, 'active': 96},
    battery: 64,
    heartbeatAgo: const Duration(seconds: 8),
    trends: {
      'hr': [74, 76, 79, 77, 80, 78, 79, 78],
    },
  ),
  'health_kit_v1': MockupDashboard(
    device: const UserDevice(id: 4, name: 'Home Health Kit', profileId: 'health_kit_v1'),
    values: {'bp': 126, 'bp_dia': 82, 'glucose': 104, 'weight': 72.4, 'spo2': 97, 'pulse': 74},
    battery: 88,
    heartbeatAgo: const Duration(minutes: 1),
    trends: {
      'bp': [118, 121, 124, 122, 127, 126],
    },
  ),
  'ief_device_v1': MockupDashboard(
    device: const UserDevice(id: 5, name: 'Therapy Device – C7:9B', profileId: 'ief_device_v1'),
    values: {'current': 11.8},
    battery: 97,
    trends: {
      'current': [12.3, 12.1, 12.0, 12.2, 12.1, 11.9, 12.1, 11.8],
    },
    events: [
      DeviceEvent(DeviceEventKind.start, _at(6, 0), code: 0),
      DeviceEvent(DeviceEventKind.stop, _at(7, 0), code: 0),
      DeviceEvent(DeviceEventKind.start, _at(7, 30), code: 0),
      DeviceEvent(DeviceEventKind.error, _at(7, 40), code: 0x21),
      DeviceEvent(DeviceEventKind.stop, _at(8, 0), code: 0),
      DeviceEvent(DeviceEventKind.start, _at(8, 0), code: 0),
    ],
  ),
  'thermometer_v1': MockupDashboard(
    device: const UserDevice(id: 6, name: 'Thermometer – Kids', profileId: 'thermometer_v1'),
    values: const {},
    battery: 64,
    today: {
      'temp': [(7, 10, 38.4), (8, 42, 37.9)],
    },
  ),
  'ecg_monitor_v1': MockupDashboard(
    device: const UserDevice(id: 7, name: 'ECG Monitor E1', profileId: 'ecg_monitor_v1'),
    values: {'hr': 76, 'hrv': 38, 'rr': 789, 'resp': 15, 'rhythm': 1, 'electrodes': 1, 'signal': 2},
    battery: 58,
    trends: {
      'hr': [74, 75, 77, 76, 78, 76, 75, 76],
    },
    waveform: ('ecg', _ecg(1500)),
  ),
  'sensor_hub_v1': MockupDashboard(
    device: const UserDevice(id: 8, name: 'Sensor Hub – Plant A', profileId: 'sensor_hub_v1'),
    values: {for (final (key, v) in _hub) key: ?v},
    battery: 81,
    trends: {
      'ch01': [
        for (final f in [0.98, 1.01, 0.99, 1.02, 1.0, 0.99, 1.0]) 62.4 * f,
      ],
    },
  ),
  'ppg_motion_v1': MockupDashboard(
    device: const UserDevice(id: 9, name: 'iNOS – Ward 3', profileId: 'ppg_motion_v1'),
    values: {'spo2': 97, 'heart_rate': 65, 'pi_ir': 0.222, 'pi_red': 0.098},
    battery: 85,
    heartbeatAgo: const Duration(seconds: 2),
    trends: {
      'spo2': [96, 97, 96, 95, 96, 97, 97, 97],
    },
  ),
};
