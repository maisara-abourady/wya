# Blast-radius proof: add-driver-id-type

## 1. Touched set

- `mobile/favorite_drivers/lib/favorite_drivers.dart` — modified (add `export 'src/driver_id.dart' show DriverId;`)
- `mobile/favorite_drivers/lib/src/driver_id.dart` — created (`DriverId` implementation)
- `mobile/favorite_drivers/test/driver_id_test.dart` — created (contract test for `DriverId`)
- `mobile/favorite_drivers/MANIFEST.yaml` — modified (`exports`, `version`, `invariants`, `failure_modes`, `tests`)
- `mobile/favorite_drivers/pubspec.yaml` — modified (`version` bump; add `test` dev dependency)

## 2. Exclusion claim

No file outside the touched set can be affected by this change because of the citations below.

## 3. Justifications

The repo currently contains exactly one BC (`mobile/favorite_drivers`). The "every BC outside the touched set" clause is **vacuously satisfied** — there are no other BCs whose isolation needs justifying.

This is honestly a *degenerate* proof: the locality property is trivially preserved because there is no alternative locality to violate. The test of this skill comes when a second BC exists. Until then, the proof's job here is to:

- establish the format and discipline of the Touched-set / Exclusion / Justifications / Open-risks structure,
- exercise the artifact pipeline (`.claude/blast-radius/<change-id>.md` is produced and version-controlled),
- give us something to compare against once a second BC lands and the proof's work becomes non-trivial.

## 4. Open risks

- `pubspec.yaml` adds `test` as a `dev_dependency`. This is build-time tooling; no runtime side effect on the BC's surface or behavior. **Accepted.**

(no other risks)

## Validation

- ✅ Every BC outside the touched set has a citation (vacuously true; no such BCs exist).
- ✅ No inference language used ("shouldn't", "probably", "low risk" — none).
- ✅ Cited manifest fields exist as cited.
- ✅ Open risks accepted.

Proof is **valid** under the criteria — with the honest caveat above that it will not be load-bearing until a second BC exists.
