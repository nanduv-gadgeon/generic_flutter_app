/// The name a new device starts with (Add device step 4): its type's label and the last 4
/// characters of its address, e.g. `Smart band 7B21`. If the user already has a device with that
/// name, ` (2)`, ` (3)` … is added.
String suggestDeviceName(String typeLabel, String address, Iterable<String> taken) {
  final tail = address.replaceAll(RegExp('[^0-9A-Za-z]'), '');
  final base = tail.isEmpty
      ? typeLabel
      : '$typeLabel ${tail.substring(tail.length < 4 ? 0 : tail.length - 4).toUpperCase()}';
  final names = taken.toSet();
  if (!names.contains(base)) return base;
  for (var n = 2; ; n++) {
    final name = '$base ($n)';
    if (!names.contains(name)) return name;
  }
}
