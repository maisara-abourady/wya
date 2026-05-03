# Context pack: add-driver-id-type

**Change:** Add a `DriverId` value type to `mobile/favorite_drivers` as the first export. Wraps a non-empty string identifier; provides value equality and a stable string representation.

**Primary BC:** `mobile/favorite_drivers`
**Dep BCs included:** none — `favorite_drivers` has no current deps.

## Required reading (load these first)

| Path | Why |
|---|---|
| `mobile/favorite_drivers/MANIFEST.yaml` | invariants + failure_modes + current exports (all empty pre-change) |
| `mobile/favorite_drivers/lib/favorite_drivers.dart` | public surface (target of the new export) |
| `CONVENTIONS.md` | public-surface rule, capability vocabulary, version-bump rules |

## Pinned manifest excerpts

### `mobile/favorite_drivers` (current)
- `summary:` User-owned roster of drivers a user has marked as favorites; supports add, remove, list, and reorder.
- `exports:` []
- `deps:` []
- `capabilities:` []
- `invariants:` []
- `failure_modes:` []
- `tests:` []

(All empty — the BC is fresh; this change introduces its first export.)

## Estimated tokens
~350 (well under the 60,000 cap; no escalation needed).

## Routing
- Next: `design-the-seam` — change adds a new public symbol (`DriverId`).

## Seam

### Symbol
`class DriverId` in `mobile/favorite_drivers` — value type wrapping a non-empty string identifier for a driver.

### Signature

```dart
class DriverId {
  final String value;
  DriverId(this.value);

  @override
  bool operator ==(Object other);
  @override
  int get hashCode;
  @override
  String toString();
}
```

### Parameter constraints
- `value` — non-empty. The empty string violates the invariant below and is rejected by the constructor.

### Return semantics
- `==` returns true iff both operands are `DriverId` and `.value` is string-equal.
- `hashCode` is consistent with `==`.
- `toString()` returns `value` verbatim (no decoration).

### Error model

| Failure | Surface |
|---|---|
| empty `value` passed to constructor | `ArgumentError` thrown synchronously from constructor |

### Invariants preserved / introduced
- *(introduced)* `DriverId.value` is always a non-empty string.

### Capabilities required
None. Pure transform — no side effects.

### Version impact
**Minor** — adds a new export. `version: 0.1.0 → 0.2.0`.

### Note: `const` rejected
The seam does not use a `const` constructor. A `const` constructor would force the empty-value check to be either an `assert` (debug-only, not a real invariant in release) or live in a separate factory. Both compromises weaken the invariant. Keeping the constructor non-`const` lets the throw-on-empty path be unconditional and makes the invariant real.

### Stub (pre-implementation state)

```dart
// lib/src/driver_id.dart
class DriverId {
  final String value;
  DriverId(this.value) {
    throw UnimplementedError('DriverId stub');
  }
}
```

Real implementation lands separately, attached to the same change.
