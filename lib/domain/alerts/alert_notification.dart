import 'alert.dart';

/// The two kinds of alert notifications, so a user can mute either in the phone's settings.
enum AlertChannel {
  /// A reading went above or below its limit.
  readings,

  /// The device's battery is low or it went offline.
  device,
}

/// The channel an alert of [kind] goes to.
AlertChannel channelOf(AlertKind kind) => switch (kind) {
  AlertKind.above || AlertKind.below => AlertChannel.readings,
  AlertKind.batteryLow || AlertKind.offline => AlertChannel.device,
};

/// What a notification for an alert says. Holds health values: never log it.
typedef AlertNotificationText = ({String title, String body, AlertChannel channel});

/// A channel's name and description, as shown in the phone's settings.
typedef AlertChannelText = ({String name, String description});
