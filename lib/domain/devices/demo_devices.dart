/// Debug builds only: dummy devices (home's hidden long-press) have made-up addresses in the
/// `AA:BB:CC:DD` range, which nothing real uses. They never connect; a demo feed plays made-up
/// readings for them instead.
const _prefix = 'AA:BB:CC:DD:';

/// The address of dummy device [n] (1 or more): `AA:BB:CC:DD:00:01`.
String demoAddress(int n) => '${_prefix}00:${n.toString().padLeft(2, '0')}';

/// Whether [address] belongs to a dummy device.
bool isDemoAddress(String address) => address.toUpperCase().startsWith(_prefix);
