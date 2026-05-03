---
name: verify-locality
description: |
  Use after implementing a change and before opening the PR. Verifies the
  change did not violate the locality property declared in the blast-radius
  proof. Trigger phrases: "verify locality", "check the change is local",
  "did anything leak", "post-change check", "ready to open PR".
---

# verify-locality

Post-change check that the implementation respected what the proof claimed. The proof was written *before* implementation; this skill is the receipt that the implementation matches.

## Inputs

- **Change ID** — the slug used for the context pack and proof.
- **Files referenced:**
  - `.claude/blast-radius/<change-id>.md` — the proof (must exist; if missing, halt).
  - `.claude/context-packs/<change-id>.md` — the seam (for export checks).
  - `mobile/<bc>/MANIFEST.yaml` (or other side) — the primary BC's manifest.

## Checks

Run all five. Each is independent; report each separately.

### 1. Diff matches touched set

Compare `git status --porcelain` (or `git diff --name-only HEAD`) against the touched set listed in the proof.

- **Fail** if the diff includes any file *not* in the touched set.
- **Fail** if the touched set lists files that did not actually change.
- **Pass** when the diff and the touched set are equal as sets.

If the change touched files outside the proof, the proof is now stale: route to `blast-radius-proof` to either widen the touched set with new citations or narrow the implementation.

### 2. No undeclared cross-BC imports

For each modified or created file in the primary BC, scan its `import 'package:<other_bc>/...'` lines (Dart) or equivalent. Each `<other_bc>` reference must appear in the BC's `MANIFEST.yaml` `deps:` field as `<side>/<other_bc>`.

- **Fail** if an import references a BC not in `deps:`.
- **Fail** if `deps:` lists a BC no longer imported anywhere (dead dep).
- **Fail** if any cross-side rule is violated (mobile → backend, etc.).

### 3. Manifest exports match surface

Read the BC's `MANIFEST.yaml` `exports:` list. Read the surface file (`lib/<bc>.dart` for mobile). For each entry in `exports:`:

- **Fail** if the surface file does not contain a corresponding `export ... show <name>;` (Dart) or equivalent.
- **Fail** if the surface file exports a symbol not in `exports:`.

### 4. Capabilities used match capabilities declared

For each modified/created file in the primary BC, scan for use of capability-bearing APIs:

| Capability | Indicators (Dart) |
|---|---|
| `db` | `package:sqflite`, `package:hive`, `package:shared_preferences`, `package:drift`, etc. |
| `net` | `package:http`, `dart:io` HttpClient, `package:dio`, `package:grpc` |
| `fs` | `dart:io` File/Directory, `package:path_provider` |
| `time` | `DateTime.now`, `Stopwatch`, `Future.delayed` with non-zero |
| `rng` | `Random()`, `dart:math` random |
| `env` | `Platform.environment`, `String.fromEnvironment` |
| `process` | `dart:io` Process |
| `crypto` | `package:crypto`, `dart:typed_data` for hashing |

(Indicators are approximate — language-aware static analysis is the future home for this check; for now use grep + judgment.)

- **Fail** if code uses a capability not in the manifest's `capabilities:`.
- **Fail** if `capabilities:` declares a capability for which no code path uses it (dead capability).

### 5. Token budget

Run `scripts/arch-lint.sh <side>/<bc>` and confirm budget is still ≤ 50,000.

- **Fail** with `budget` violation if exceeded.

## Output

```
verify-locality: <change-id>
  1. diff vs. touched set     [pass | fail: <details>]
  2. cross-BC imports         [pass | fail: <details>]
  3. exports vs. surface      [pass | fail: <details>]
  4. capabilities             [pass | fail: <details>]
  5. token budget             [pass | fail: <details>]

verdict: PASS | FAIL
```

On failure, surface which earlier artifact is now stale and which skill should be re-run:

| Failed check | Stale artifact | Re-run |
|---|---|---|
| 1 | proof | `blast-radius-proof` |
| 2 or 3 | manifest | `module-manifest update` |
| 4 | manifest or seam | `design-the-seam` (capability widening) or `module-manifest` (declare/remove) |
| 5 | nothing — surface to user | `token-budget-audit` |

## What verify-locality never does

- **Never modifies code or manifests** to make a check pass. Checks fail loudly; the user fixes upstream.
- **Never relaxes a check** because the failure is "small." If the proof said the file wouldn't change, and it changed, the proof is stale — period.
- **Never skips a check.** All five run on every invocation.

## Integrations

- **Consumes:** the proof, the context pack, the BC's manifest, the diff.
- **Produces:** a pass/fail report; no file artifacts.
- **Routes back to:** the appropriate upstream skill on failure.
- **Precedes:** PR creation.
