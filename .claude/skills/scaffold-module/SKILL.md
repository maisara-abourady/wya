---
name: scaffold-module
description: |
  Use when introducing a new bounded context to wya. Trigger phrases: "add a
  new BC for X", "scaffold module Y", "create a bounded context", "new domain
  area", "spin up <name>", or after a PRD identifies a new domain area that
  doesn't yet exist as a BC. Generates the side-appropriate directory tree,
  manifest, public-surface stub, README, and CODEOWNERS in one step, fully
  conformant with `CONVENTIONS.md`.
---

# scaffold-module

Generate a new bounded context conforming to every convention. The BC starts clean. It only stays clean if `module-manifest` is used for every subsequent change to its public surface, deps, or capabilities.

## Inputs needed before scaffolding

Stop and ask if any are missing — never invent answers:

- **Side** — one of `mobile`, `backend`, `contracts`. Determines the layout used.
- **BC name** — lowercase snake_case (`^[a-z][a-z0-9_]*$`). Must equal the directory name to be created. Must not already exist.
- **One-sentence summary** — ≤ 200 chars. Used by `context-pack` to match changes against BCs; specificity is leverage.
- **Intended capabilities** — subset of `[db, net, fs, time, rng, env, process, crypto]`. Empty list (a pure transform) is allowed and preferred when possible.
- **Expected callers** — qualified BC names or external surfaces (CLI, HTTP) expected to use this one. Informs the README; not stored in the manifest directly.
- **Owner** — team or person for `CODEOWNERS` (email or `@handle`).

## Side-specific behavior

### `mobile/<bc_name>` — Dart package

Generated tree:

```
mobile/<bc_name>/
  pubspec.yaml
  MANIFEST.yaml
  README.md
  CODEOWNERS
  lib/
    <bc_name>.dart
    src/.gitkeep
  test/.gitkeep
```

**Generated `pubspec.yaml`** — minimal valid Dart package:

```yaml
name: <bc_name>
description: <one-sentence summary>
version: 0.1.0
publish_to: none
environment:
  sdk: ">=3.0.0 <4.0.0"
```

Add `flutter:` SDK dep and `flutter_test:` only if the BC actually needs Flutter (UI BCs). Pure-domain BCs (rosters, models, validators) should stay plain Dart.

**Generated `lib/<bc_name>.dart`** — empty re-export with header:

```
// <bc_name> — public surface.
//
// Only symbols re-exported from this file are visible across BC boundaries.
// Anything imported from mobile/<bc_name>/lib/src/* by code outside this BC
// is a violation of the public-surface rule (see CONVENTIONS.md
// §"Public surface rule").
//
// To add a new export, use the `module-manifest` skill in update mode.
```

### `backend/<bc_name>` — TBD

Halt with a message: the backend layout is locked at the first backend BC scaffold, when the backend runtime is chosen. Surface this to the user and ask which runtime — do not scaffold blind.

### `contracts/<bc_name>` — TBD

Halt with a message: the contracts layout is locked at the first contracts BC scaffold, when the contract format (OpenAPI, Proto, plain YAML) is chosen.

## Generated files (all sides)

### `MANIFEST.yaml`

```yaml
name: <bc_name>
version: 0.1.0
summary: <one-sentence summary>
exports: []
deps: []
capabilities: <intended subset>
invariants: []
events_emitted: []
events_consumed: []
failure_modes: []
tests: []
token_budget_used: 0
links: {}
```

### `README.md`

```
# <side>/<bc_name>

<one-sentence summary>

## Public surface
See `MANIFEST.yaml` → `exports:`. The surface file is the only legal cross-BC
import target.

## Invariants
See `MANIFEST.yaml` → `invariants:`.

## Failure modes
See `MANIFEST.yaml` → `failure_modes:`.

## Tests
See `MANIFEST.yaml` → `tests:`.

## Evolution
Decisions about this BC's shape are recorded under `.claude/evolution-log/`.
```

### `CODEOWNERS`

```
* <owner>
```

## Post-scaffold step

Run `arch-conventions` in lint mode against the new BC. Expect zero violations. If anything fires, halt and surface — a fresh BC must lint clean.

## What scaffold-module never does

- **Never adds dependencies on other BCs at scaffold time.** `deps: []` is the only valid initial state. Capture mentioned dependencies as informational notes for a follow-up `module-manifest update`.
- **Never invents capabilities the user didn't state.** Capabilities are claims to callers; only the user can author them.
- **Never writes business logic, types, or function signatures.** The first export is added later via `design-the-seam` or by hand through `module-manifest update`.
- **Never scaffolds a BC that already exists.** If the directory exists, halt and route to `module-manifest`.
- **Never creates a surface file that re-exports anything.** It must start empty (header comment only).
- **Never scaffolds for a side without a locked layout.** Backend and contracts layouts are TBD until the first BC lands on each side.

## Integrations

- **Consumed by:** any upstream that decomposes work into domain areas (PRD pipeline, ticket triage, ad-hoc) when a new BC is needed.
- **Produces:** the directory tree that `module-manifest`, `context-pack`, `arch-conventions`, and `verify-locality` operate on.
