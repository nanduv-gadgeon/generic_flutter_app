import '../../domain/models/device_profile.dart';

/// Reading keys the profile's `signal` block works out on the phone.
Set<String> signalOutputs(DeviceProfile profile) {
  final ppg = profile.signal?.ppgOximetry;
  if (ppg == null) return const {};
  return {ppg.spo2.key, ppg.heartRate.key, ppg.perfusion.red, ppg.perfusion.ir};
}

/// Rules for the `streaming`, `sync`, `signal` and `agc` blocks the JSON schema cannot express.
/// [rawKeys] are the keys the packet layout gives. Returns one `/path: message` per problem.
List<String> checkStreaming(DeviceProfile profile, String path, Set<String> rawKeys) {
  final commands = {for (final c in profile.commands) c.id: c};
  final errors = <String>[];

  void command(String at, String id, {required bool value}) {
    final found = commands[id];
    if (found == null) {
      errors.add('$at: no command "$id"');
    } else if (found.takesValue != value) {
      errors.add('$at: command "$id" ${value ? 'must' : 'must not'} take a value');
    }
  }

  final streaming = profile.streaming;
  if (streaming != null) {
    for (final (i, id) in streaming.start.indexed) {
      command('$path/streaming/start/$i', id, value: false);
    }
    for (final (i, id) in streaming.stop.indexed) {
      command('$path/streaming/stop/$i', id, value: false);
    }
  }

  final sync = profile.sync;
  if (sync != null) {
    for (final (i, id) in sync.onConnect.indexed) {
      command('$path/sync/onConnect/$i', id, value: false);
    }
    for (final (i, id) in sync.repeat.indexed) {
      command('$path/sync/repeat/$i', id, value: false);
    }
    if ((sync.everySeconds == null) != sync.repeat.isEmpty) {
      errors.add('$path/sync: everySeconds and repeat go together');
    }
  }

  final ppg = profile.signal?.ppgOximetry;
  if (ppg != null) {
    final at = '$path/signal/ppgOximetry';
    for (final (name, key) in [('red', ppg.red), ('ir', ppg.ir)]) {
      if (!rawKeys.contains(key)) errors.add('$at/$name: no packet field gives "$key"');
    }
    for (final (name, sections) in [('bandPass', ppg.bandPass), ('lowPass', ppg.lowPass)]) {
      if (sections.isEmpty || sections.any((row) => row.length != 6 || row[3] == 0)) {
        errors.add('$at/$name: needs rows of 6 numbers [b0, b1, b2, a0, a1, a2] with a0 not 0');
      }
    }
    if (ppg.spo2.coefficients.length != 3) errors.add('$at/spo2/coefficients: needs [a, b, c]');
    final hr = ppg.heartRate;
    if (hr.window > hr.buffer || hr.step > hr.window) {
      errors.add('$at/heartRate: needs step ≤ window ≤ buffer');
    }
  }

  final agc = profile.agc;
  if (agc != null) {
    final at = '$path/agc';
    if (!rawKeys.contains(agc.input)) errors.add('$at/input: no packet field gives "${agc.input}"');
    if (!(agc.noContact <= agc.low && agc.low < agc.high)) {
      errors.add('$at: needs noContact ≤ low < high');
    }
    if (!(agc.min <= agc.start && agc.start <= agc.max)) errors.add('$at: needs min ≤ start ≤ max');
    for (final (i, id) in agc.commands.indexed) {
      command('$at/commands/$i', id, value: true);
    }
  }
  return errors;
}
