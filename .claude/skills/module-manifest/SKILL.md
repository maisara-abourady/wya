---
name: module-manifest
description: |
  Use when creating a new bounded context, when public exports change, when
  cross-BC imports change, when capabilities change, when invariants are added
  or relaxed, or when validating that an existing manifest still matches reality.
  Trigger phrases: "create manifest", "update manifest", "validate the manifest",
  "manifest drift", "what does this BC export", "add a dependency to the
  manifest", or any change to a BC's public surface, deps, or capabilities.
---

# module-manifest

Create, update, and validate a BC's `MANIFEST.yaml` against `MANIFEST.schema.yaml` and against the BC's actual code state. The manifest is the cross-BC contract — its accuracy is non-negotiable.

## Modes

The skill operates in one of three modes; choose based on user intent or explicit `mode=` argument:

- `create` — no manifest exists; produce one for a newly scaffolded BC.
- `update` — manifest exists; sync with current code state and any user-requested changes.
- `validate` — manifest exists; report drift but write nothing.

## Create flow

1. Gather inputs (stop and ask if any are missing):
   - **BC name** — must equal the BC's directory name.
   - **Summary** — one sentence, ≤ 200 chars.
   - **Initial capabilities** — subset of `[db, net, fs, time, rng, env, process, crypto]`. Empty list (pure transform) is preferred when possible.
   - **Initial exports** — typically empty for a freshly scaffolded BC.
   - **Expected callers** — informational; helps frame summary; not stored.
2. Generate `MANIFEST.yaml` populated from inputs. Defaults:
   - `version: 0.1.0`
   - `deps: []`
   - `invariants: []` (added explicitly later)
   - `events_emitted: []`, `events_consumed: []`
   - `failure_modes: []`
   - `tests: []`
   - `token_budget_used: 0`
   - `links: {}`
3. Validate against `MANIFEST.schema.yaml`. Halt on any violation.

## Update flow

1. Read current `MANIFEST.yaml`.
2. Diff each machine-determinable field against reality:
   - `exports`: actual symbols re-exported from `index.*`
   - `deps`: actual cross-BC imports in `src/` (excluding self-imports)
   - `capabilities`: side effects detected via static analysis (or annotated pragmas if static analysis is unavailable)
   - `tests`: files under `tests/`
   - `token_budget_used`: re-counted (code + docs + tests)
3. Surface drift to the user as a structured diff *before* writing.
4. Apply corrections to machine-determinable fields only after user confirmation.
5. **Never edit `invariants` or `failure_modes` automatically.** These reflect human-stated guarantees; any change requires explicit user input.
6. Bump `version` per these rules:
   - **Major:** removed export, narrowed type, added invariant the BC didn't already satisfy.
   - **Minor:** added export, added capability, added failure_mode, added invariant the BC already satisfied.
   - **Patch:** rare; manifest-only fixes that don't change the public surface.

## Validate flow

1. Run schema validation (read-only) against `MANIFEST.schema.yaml`.
2. Run reality cross-check (read-only):
   - Each declared export must exist in `index.*`.
   - Each declared dep must correspond to ≥ 1 actual cross-BC import.
   - Each actual cross-BC import must be in `deps`.
   - Each declared capability must correspond to ≥ 1 actual usage (no dead capabilities).
   - Each actual capability usage must be declared.
   - Each declared test path must exist; each file under `tests/` must appear in `tests`.
   - `token_budget_used` must match a fresh count within ±5%.
3. Output a drift report. Write nothing.

## Anti-patterns

- **Never invent invariants the user didn't state.** A wrong invariant is worse than no invariant — callers may rely on it and silently break.
- **Never widen `capabilities` to silence a lint error.** The fix is to remove the offending side effect or to consciously expand the manifest with an explicit reason.
- **Never re-export internals from `index.*` to make the manifest "match."** If a symbol shouldn't be public, it shouldn't be on `exports` — fix the caller instead.
- **Never edit `failure_modes` based on inferred behavior.** These are claims the BC makes to its callers; only the user can author them.
- **Never auto-bump `version` past the rule above.** Surface ambiguous cases for user decision.

## Output

- Modes `create` and `update` write `MANIFEST.yaml` and emit a one-paragraph diff summary listing every field changed and why.
- Mode `validate` emits a drift report and writes nothing.

## Integrations

- **Produces:** the manifest read by `context-pack`, `verify-locality`, and `arch-conventions`.
- **Consumed by:** `scaffold-module` (during BC creation).
- **Feeds:** `arch-conventions` lint (this skill resolves the drift `arch-conventions` surfaces).
