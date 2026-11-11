import 'package:drift/drift.dart';

/// How the phone talks to a device.
enum DeviceTransport { ble, wifi }

/// Phase 1 local accounts. Passwords are stored only as a salted hash (made in task 1.1.6).
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The form allows 70 characters; 255 leaves room for international names.
  TextColumn get name => text().withLength(max: 255)();

  /// Stored lowercased by [UsersDao], so uniqueness ignores letter case. 254: the RFC 5321 limit.
  TextColumn get email => text().withLength(max: 254).unique()();
  TextColumn get mobile => text()();
  BlobColumn get passwordHash => blob()();
  BlobColumn get passwordSalt => blob()();

  /// Algorithm and cost settings used for this hash, e.g. `argon2id;m=19456;t=2;p=1`.
  TextColumn get hashParams => text()();
  IntColumn get failedLoginCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get termsAcceptedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Who is logged in. Always at most one row, with id 1.
class Sessions extends Table {
  // ignore: recursive_getters
  IntColumn get id => integer().check(id.equals(1))();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get lastActiveAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Devices a user has added. Their readings and heartbeats have their own tables.
@TableIndex(name: 'devices_user_order', columns: {#userId, #sortOrder})
class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// A device type id from the config file's `deviceTypes`.
  TextColumn get profileId => text()();
  TextColumn get transport => textEnum<DeviceTransport>()();

  /// BLE: MAC address or remote id. Wi‑Fi: the device id it announces by mDNS, which stays the
  /// same when its IP changes.
  TextColumn get address => text()();

  /// Wi‑Fi: the last IP address, used when mDNS does not find the device (added in schema v3).
  TextColumn get ipAddress => text().nullable()();
  TextColumn get firmware => text().nullable()();
  IntColumn get batteryPercent =>
      // ignore: recursive_getters
      integer().nullable().check(batteryPercent.isBetweenValues(0, 100))();
  DateTimeColumn get lastHeartbeatAt => dateTime().nullable()();
  IntColumn get sortOrder => integer()();

  /// Phase 2: unique key returned by the cloud when the device is registered.
  TextColumn get deviceKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {userId, address},
  ];
}

/// Each user's app settings (added in schema v2). No row yet means every setting is at its default.
class AppSettings extends Table {
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}

/// Alert limits for one reading of one device (added in schema v3). Starts as the device type's
/// defaults from the config file; Device settings changes them.
class DeviceAlerts extends Table {
  IntColumn get deviceId => integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// A reading key of the device's profile, e.g. `heart_rate`.
  TextColumn get readingKey => text()();
  RealColumn get above => real().nullable()();
  RealColumn get below => real().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {deviceId, readingKey};
}

/// Readings from devices (added in schema v4). One row per reading key and time; the same reading
/// arriving twice (e.g. a log synced again) is stored once.
///
/// Values are health data: never log them.
// TODO(phase2): what the uploader has sent goes in an upload_state table.
@TableIndex(name: 'readings_device_key_time', columns: {#deviceId, #key, #atMs}, unique: true)
class Readings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// A reading key of the device's profile, e.g. `heart_rate`.
  TextColumn get key => text()();
  RealColumn get value => real()();

  /// When it was measured: UTC milliseconds since 1970. Drift date-times keep only whole seconds,
  /// which would merge readings that arrive several times a second.
  IntColumn get atMs => integer()();
}

/// When each device was heard from (any data counts as a heartbeat), at most once per heartbeat
/// interval, with its battery level then. Kept for 24 hours.
/// TODO(phase2): uploaded with the readings.
@TableIndex(name: 'heartbeats_device_time', columns: {#deviceId, #atMs})
class Heartbeats extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// UTC milliseconds since 1970.
  IntColumn get atMs => integer()();
  IntColumn get batteryPercent =>
      // ignore: recursive_getters
      integer().nullable().check(batteryPercent.isBetweenValues(0, 100))();
}

/// What devices logged other than readings (added in schema v6): sessions started and stopped,
/// and errors. Kept as long as readings. The same event arriving twice (e.g. a log synced again)
/// is stored once.
/// TODO(phase2): uploaded with the readings.
// Named DeviceEventRow so it does not clash with the decoder's DeviceEvent.
@DataClassName('DeviceEventRow')
@TableIndex(name: 'device_events_device_time', columns: {#deviceId, #atMs, #kind}, unique: true)
class DeviceEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deviceId => integer().references(Devices, #id, onDelete: KeyAction.cascade)();

  /// `start`, `stop` or `error`.
  TextColumn get kind => text()();

  /// The device's error code, or 0.
  IntColumn get code => integer().withDefault(const Constant(0))();

  /// When the device logged it: UTC milliseconds since 1970.
  IntColumn get atMs => integer()();
}
