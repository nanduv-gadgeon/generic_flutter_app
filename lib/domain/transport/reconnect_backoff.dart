/// Waits between reconnect attempts: 2, 5, 15, then every 60 seconds (architecture,
/// "Reconnect / remove").
class ReconnectBackoff {
  const ReconnectBackoff([this.steps = defaultSteps]);

  static const defaultSteps = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];

  final List<Duration> steps;

  /// Delay before attempt [attempt] (0 = first retry); the last step repeats.
  Duration delayFor(int attempt) => steps[attempt.clamp(0, steps.length - 1)];
}
