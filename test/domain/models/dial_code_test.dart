import 'package:flutter_test/flutter_test.dart';
import 'package:generic_flutter_app/domain/models/dial_code.dart';

void main() {
  test('every ISO code is listed once', () {
    final isos = [for (final c in dialCodes) c.iso];
    expect(isos.toSet().length, isos.length);
  });

  test('every entry is well formed', () {
    final iso = RegExp(r'^[A-Z]{2}$');
    // +, a 1–3 digit country code, then (North America only) a 3 digit area code.
    final dial = RegExp(r'^\+[1-9][0-9]{0,2}( [0-9]{3})?$');
    for (final c in dialCodes) {
      expect(c.iso, matches(iso), reason: c.name);
      expect(c.dial, matches(dial), reason: c.name);
      expect(c.name.trim(), isNotEmpty, reason: c.iso);
      if (c.dial.contains(' ')) expect(c.dial, startsWith('+1 '), reason: c.name);
    }
  });

  // Spot checks against the ITU-T E.164 assignments.
  final known = {
    'IN': '+91',
    'GB': '+44',
    'US': '+1',
    'CA': '+1',
    'JM': '+1 876',
    'RU': '+7',
    'KZ': '+7',
    'DE': '+49',
    'AE': '+971',
    'AU': '+61',
    'ZA': '+27',
  };
  for (final MapEntry(key: iso, value: dial) in known.entries) {
    test('$iso is $dial', () => expect(dialCodeFor(iso)?.dial, dial));
  }

  test('the fallback is in the list', () {
    expect(dialCodeFor(fallbackDialCode.iso)?.dial, fallbackDialCode.dial);
  });

  test('dialCodeFor ignores case and returns null for unknown codes', () {
    expect(dialCodeFor('gb')?.name, 'United Kingdom');
    expect(dialCodeFor('ZZ'), isNull);
    expect(dialCodeFor(null), isNull);
  });

  test('defaultDialCode uses the region, else India', () {
    expect(defaultDialCode('GB').iso, 'GB');
    expect(defaultDialCode('ZZ').iso, 'IN');
    expect(defaultDialCode(null).iso, 'IN');
  });

  // query -> ISO codes found
  final searches = <String, Set<String>>{
    'ind': {'IN', 'ID', 'IO'}, // India, Indonesia, British Indian Ocean Territory
    'UNITED KINGDOM': {'GB'},
    'gb': {'GB'},
    '44': {'GB', 'GG', 'IM', 'JE'},
    '+1 876': {'JM'},
    'zzz': {},
  };
  for (final MapEntry(key: query, value: isos) in searches.entries) {
    test('filterDialCodes("$query")', () {
      expect({for (final c in filterDialCodes(query)) c.iso}, isos);
    });
  }

  test('filterDialCodes with an empty query returns every code', () {
    expect(filterDialCodes('  '), dialCodes);
  });

  test('digitCount counts only digits', () {
    expect(dialCodeFor('IN')!.digitCount, 2);
    expect(dialCodeFor('JM')!.digitCount, 4);
  });
}
