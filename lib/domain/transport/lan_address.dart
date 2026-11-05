import 'dart:io';

/// Whether [host] is on the local network: a private, link-local or loopback IP, or an mDNS
/// `.local` name.
///
/// Wi‑Fi devices are only reached at such hosts, so with isCloud false the app never talks to the
/// internet even though Android grants it the INTERNET permission.
bool isLanHost(String host) {
  final name = host.toLowerCase();
  if (name.endsWith('.local') && name.length > '.local'.length) return true;

  // IPv6 literals may come wrapped in brackets, as in URLs.
  final literal = name.startsWith('[') && name.endsWith(']')
      ? name.substring(1, name.length - 1)
      : name;
  final address = InternetAddress.tryParse(literal);
  if (address == null) return false;
  if (address.isLoopback || address.isLinkLocal) return true;

  final b = address.rawAddress;
  return switch (address.type) {
    InternetAddressType.IPv4 =>
      b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168),
    // Unique local addresses, fc00::/7.
    InternetAddressType.IPv6 => b[0] & 0xFE == 0xFC,
    _ => false,
  };
}
