/// Checksums used by device protocols. Add one here when a protocol document needs it.
library;

final List<int> _crc32Table = List.unmodifiable(
  List.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    return c;
  }),
);

/// CRC-32 (IEEE 802.3, as zlib) of `bytes[start..end)`.
int crc32(List<int> bytes, [int start = 0, int? end]) {
  var crc = 0xFFFFFFFF;
  for (var i = start; i < (end ?? bytes.length); i++) {
    crc = _crc32Table[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

/// XOR of `bytes[start..end)`.
int xor8(List<int> bytes, [int start = 0, int? end]) {
  var x = 0;
  for (var i = start; i < (end ?? bytes.length); i++) {
    x ^= bytes[i];
  }
  return x & 0xFF;
}

/// Sum of `bytes[start..end)`, modulo 256.
int sum8(List<int> bytes, [int start = 0, int? end]) {
  var sum = 0;
  for (var i = start; i < (end ?? bytes.length); i++) {
    sum += bytes[i];
  }
  return sum & 0xFF;
}
