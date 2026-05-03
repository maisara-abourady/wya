// DriverId — value type for a driver's identifier.
//
// Invariant: DriverId.value is always a non-empty string.
// Failure mode: ArgumentError thrown from the constructor on empty value.

class DriverId {
  final String value;

  DriverId(this.value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'DriverId.value must be non-empty');
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DriverId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
