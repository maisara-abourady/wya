---
name: arch-conventions
description: |
  Use when starting any structural work on wya — introducing a new bounded
  context, reviewing whether code conforms to repo conventions, linting an
  existing BC, or when another skill needs to load the conventions before
  acting. Trigger phrases: "what are the conventions", "lint the architecture",
  "is this BC valid", "check conventions", "module rules", or any structural
  question about wya's module shape.
---

# arch-conventions

Canonical interpreter of `CONVENTIONS.md`. This skill is the single source of truth for what the conventions mean and how they are enforced. If a check is not encoded here or in `scripts/arch-lint.sh`, it effectively does not exist.

## Quick reference

| # | Convention | Value |
|---|---|---|
| 1 | Module unit | Bounded context |
| 2 | Repo partition | Three sides: `mobile/`, `backend/`, `contracts/` |
| 3 | BC qualified name | `<side>/<bc_name>` (snake_case) |
| 4 | Public surface | `mobile/<bc>/lib/<bc>.dart` (others TBD) |
| 5 | Dependency declaration | Manifest `deps:` ↔ actual cross-BC imports (exact match) |
| 6 | Cross-side rules | mobile→{mobile, contracts}; backend→{backend, contracts}; contracts→{} |
| 7 | Token budget | 50,000 per BC |
| 8 | Capability vocabulary | `db`, `net`, `fs`, `time`, `rng`, `env`, `process`, `crypto` (closed set) |
| 9 | Ownership | One `CODEOWNERS` line at BC root, single owner |

For full text, read `CONVENTIONS.md` at the repo root.

## How to read the conventions

This skill is the **only** interpreter of `CONVENTIONS.md`. Any conventions check not encoded here or in `scripts/arch-lint.sh` does not exist as far as the system is concerned. Updates to either must stay in sync with the doc; drift is the silent-degradation failure mode this whole pipeline is designed to prevent.

## Inputs

- None required for orientation mode.
- Optional `bc=<side>/<name>` to lint a specific BC. Lints all BCs if omitted.

## Steps — orientation mode

When invoked without a lint request:

1. Read `CONVENTIONS.md`. Surface the quick-reference table above.
2. List current BCs by walking `mobile/`, `backend/`, `contracts/` and reporting any directory that contains a `MANIFEST.yaml`.
3. Suggest the next likely skill:
   - `scaffold-module` — for creating a new BC. Requires a side.
   - `module-manifest` — for changing an existing BC's surface, deps, or capabilities.
   - `token-budget-audit` — when a BC is at or near 50k tokens.

## Steps — lint mode

When invoked to lint:

1. Run `scripts/arch-lint.sh <qualified-name?>`. (If the script does not yet exist, surface that and halt.)
2. Group violations by BC and classify each as one of:
   - `surface` — cross-BC import bypasses the BC's surface file
   - `deps` — import target not in manifest `deps:`, or declared dep not actually imported
   - `cross-side` — dep crosses a side rule (e.g., mobile depending on backend)
   - `capability` — code performs a capability not declared in manifest, or declared capability is unused
   - `budget` — BC exceeds 50,000 token budget
   - `ownership` — missing or malformed `CODEOWNERS` at BC root
   - `manifest` — `MANIFEST.yaml` fails schema validation against `MANIFEST.schema.yaml`
   - `shape` — BC directory structure violates the per-side shape (e.g., missing `lib/<bc>.dart` in mobile)
3. For each violation, surface the file path, line (if available), and the specific rule violated.
4. Suggest the next skill:
   - `module-manifest` — for `manifest`, `deps`, `capability`, `surface`, `cross-side` drift
   - `token-budget-audit` — for `budget`
   - direct user action — for `ownership`, `shape`

## Output format

```
arch-conventions lint: <side>/<bc_name>
  shape (0): ok
  surface (1):
    src/foo.dart → ../identity/lib/src/internal/x.dart
      bypasses identity/lib/identity.dart
  deps (0): ok
  cross-side (0): ok
  capability (1):
    src/bar.dart uses fs.readFile, manifest declares: [db, net]
  budget (0): 38,212 / 50,000 tokens
  ownership (0): ok
  manifest (0): ok

next: run module-manifest in update mode for <side>/<bc_name>
```

## What not to do

- **Never silently fix a violation.** Surface it and route to the appropriate skill.
- **Never expand the capability vocabulary on the fly.** The closed set requires updates to `CONVENTIONS.md`, `MANIFEST.schema.yaml`, the lint script, and an evolution-log entry — in one PR.
- **Never bypass the public-surface rule, even temporarily.** The fix is to either expose the symbol via the BC's surface file or refuse the cross-BC dependency.
- **Never widen a BC's `deps:` to silence a `surface` violation.** `surface` and `deps` are independent rules.
- **Never relax a cross-side rule** to make an offending import pass — the import is wrong, not the rule.

## Integrations

- **Consumed by:** `context-pack` (loads conventions before assembling a pack), `scaffold-module` (post-scaffold lint), `verify-locality` (post-change lint).
- **Feeds:** `module-manifest` (surfaces drift this skill resolves), `token-budget-audit` (surfaces overruns this skill flags).
