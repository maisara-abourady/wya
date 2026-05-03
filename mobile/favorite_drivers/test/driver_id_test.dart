// Contract test for DriverId — protects the public-surface API stated in
// MANIFEST.yaml: exports.DriverId, invariants["DriverId.value is always a
// non-empty string"], failure_modes["empty driver id"].

import 'package:test/test.dart';
import 'package:favorite_drivers/favorite_drivers.dart';

void main() {
  group('DriverId contract', () {
    test('rejects empty value with ArgumentError', () {
      expect(() => DriverId(''), throwsArgumentError);
    });

    test('accepts non-empty value', () {
      final id = DriverId('drv-123');
      expect(id.value, equals('drv-123'));
    });

    test('value equality on equal strings', () {
      expect(DriverId('a'), equals(DriverId('a')));
    });

    test('value inequality on different strings', () {
      expect(DriverId('a'), isNot(equals(DriverId('b'))));
    });

    test('hashCode consistent with equality', () {
      expect(DriverId('a').hashCode, equals(DriverId('a').hashCode));
    });

    test('toString returns value verbatim', () {
      expect(DriverId('xyz').toString(), equals('xyz'));
    });
  });
}
