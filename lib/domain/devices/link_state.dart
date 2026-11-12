import '../services/live_readings.dart';

/// How the connection to a device looks to the user. The home card, the dashboard's status strip,
/// the Connected count and the offline banner all use this, so they always agree.
enum LinkState {
  /// Linked: streaming, or setting up after connecting (syncing logs, starting).
  connected,

  /// Opening the first connection.
  connecting,

  /// The link dropped and is being opened again; not Offline until the heartbeat says so.
  reconnecting,

  /// Missed its heartbeats, or could not be reached and is waiting to try again.
  offline,

  /// Connects only to send a reading, so never shown as Offline (e.g. a thermometer).
  onDemand,
}

/// The [LinkState] for a device whose link reports [status] (null: not linked at all) and whose
/// heartbeat says [online]. [onDemand] comes from its profile's dashboard settings.
LinkState linkStateOf(LiveStatus? status, {required bool online, bool onDemand = false}) {
  if (onDemand) return LinkState.onDemand;
  if (status == null || !online) return LinkState.offline;
  return switch (status) {
    LiveStatus.waiting => LinkState.offline,
    LiveStatus.reconnecting => LinkState.reconnecting,
    LiveStatus.connecting => LinkState.connecting,
    LiveStatus.syncing || LiveStatus.starting || LiveStatus.streaming => LinkState.connected,
  };
}
