# wya engineering pipeline — user manual

How to use the project-scoped skills under `.claude/skills/` to plan, design, implement, and verify a code change without scraping the codebase.

If you want the *theory* behind the design, read this file's last section. If you want to ship a change *now*, start with **Quick start** and skip the rest until you hit a problem.

---

## What this pipeline is for

Every skill in this pipeline serves one property: **locality of reasoning.** Any change you make in wya should be understandable, plannable, implementable, and verifiable by reading a small, predictable subset of files — never by scraping the repo. The pipeline encodes the discipline; the conventions in `CONVENTIONS.md` are what make the discipline mechanical.

The investment pays off as wya grows: future Claude sessions (and future you) will be able to make safe changes without holding the whole system in context.

---

## Input contract

The engineering pipeline is **source-agnostic**. It does not depend on any particular upstream — it accepts input from a PRD-driven product pipeline, a ticket system, a Slack message, or a verbal request equally well. The only things it needs are:

| Required | Form | Used for |
|---|---|---|
| Change description | Free-text sentence (or short paragraph). Concept-shaped: name the affected behavior using vocabulary that appears (or will appear) in some BC's `summary:` or `exports:`. | Routing the pack to the right BC; pulling relevant invariants and tests. |
| Change ID | Kebab-case slug (e.g., `add-driver-id-type`, `fix-roster-reorder-race`). Derive from the description if no upstream ID exists. | Naming the artifacts at `.claude/context-packs/<change-id>.md` and `.claude/blast-radius/<change-id>.md`. |
| Optional: BC hint | `<side>/<bc_name>` if you already know which BC the change targets. | Skips `context-pack`'s discovery step. |

That's the entire contract. **Whatever upstream produces something that includes those, the pipeline will accept it.** No JSON schema, no required structure beyond the slug shape; the engineering skills do the structured work themselves.

---

## The pipeline at a glance

```
   UPSTREAM (any source — product pipeline, ticket, ad-hoc request)
   ────────────────────────────────────────────────────────────────
   produces:  change description (free text)
              change-id (kebab-case slug)
              optional BC hint
                                                                       │
                                                                       │  feeds into
                                                                       ▼
   THIS PIPELINE (engineering-side, project skills)
   ─────────────────────────────────────────────────
                                                              context-pack
                                                                       │
                                                                       │  load list + invariants
                                                                       ▼
                                          (if public surface changes)
                                                              design-the-seam
                                                                       │
                                                                       │  signature, errors, capabilities
                                                                       ▼
                                                              blast-radius-proof
                                                                       │
                                                                       │  citation-based safety proof
                                                                       ▼
                                                              IMPLEMENT
                                                                       │
                                                                       ▼
                                                              verify-locality
                                                                       │
                                                                       ▼
                                                                      PR

   HEALTH (run periodically, not per change)
   ─────────────────────────────────────────
   token-budget-audit          arch-conventions (lint mode)

   STRUCTURAL (use when adding a new bounded context)
   ──────────────────────────────────────────────────
   scaffold-module ──► module-manifest (create) ──► module-manifest (update on every public surface change)
```

---

## Quick start

Day-to-day, the loop you'll repeat is:

1. Get the change down to one sentence and pick a kebab-case `change-id` slug. Source doesn't matter — PRD output, ticket, ad-hoc.
2. **Invoke `context-pack`** with that sentence. Get back a load list of the few files you need.
3. If the change touches a public symbol or type, **invoke `design-the-seam`**. Stub the symbol, update the manifest. Lint must stay green.
4. **Invoke `blast-radius-proof`**. Get a citation-based proof attached to the change. If you can't write it without hand-waving, the change is misshapen — go back to step 1.
5. Implement. Replace stubs with real code.
6. **Invoke `verify-locality`**. Five checks; if any fail, fix the upstream artifact.
7. Open the PR. Attach `.claude/blast-radius/<change-id>.md` to the description.

When something happens that *isn't* a routine change:

- **New domain area / bounded context** → `scaffold-module`
- **BC seems too big** → `token-budget-audit`
- **Sanity-check the whole repo** → `arch-conventions` (lint mode) or `scripts/arch-lint.sh`

---

## Skills reference

Skills are project-scoped and live under `.claude/skills/<name>/SKILL.md`. Trigger them with the slash-command form (`/<name>`) or by phrasing your request to match the skill description (Claude Code routes by the description string). Both work.

### Foundation (use when adding or touching BC structure)

| Skill | When to invoke | Inputs | Output / effect |
|---|---|---|---|
| `arch-conventions` | Orientation ("what are the rules in this repo?") or after-the-fact lint. Other skills also load it implicitly. | Optional `bc=<side>/<name>` | Quick-reference table, or lint report grouped by violation kind. |
| `module-manifest` | New BC creation; changing exports/deps/capabilities/invariants; validating an existing manifest against reality. | Mode (`create` / `update` / `validate`) | Writes or validates `MANIFEST.yaml`; surfaces drift. |
| `scaffold-module` | New bounded context. | side, BC name (snake_case), summary, capabilities, owner, language | Side-shaped directory tree, manifest, surface stub, README, CODEOWNERS. |

### Per-change loop (use for every code change)

| Skill | When to invoke | Inputs | Output / effect |
|---|---|---|---|
| `context-pack` | Start of any code change, after the change description is fixed. Re-run if scope shifts. | Change description, optional BC hint | `.claude/context-packs/<change-id>.md` — ranked load list + pinned manifest excerpts + token estimate. |
| `design-the-seam` | When the change adds or modifies a public symbol/type/event. Skip if the change is purely internal. | Context pack, target symbol, intent | "## Seam" section appended to the context pack. Stubbed code + manifest updates. |
| `blast-radius-proof` | After seam (or directly after pack for internal changes), before implementation. Re-run if touched set shifts. | Context pack, seam (optional), implementation outline | `.claude/blast-radius/<change-id>.md` — citation-based proof with touched set, exclusion claim, justifications, open risks. |
| `verify-locality` | After implementation, before opening the PR. | Change ID | Pass/fail report on five checks (diff, imports, surface, capabilities, budget). Pass-required for PR. |

### Health (run on a cadence, not per change)

| Skill | When to invoke | Output / effect |
|---|---|---|
| `arch-conventions` (lint mode) | Periodic full-repo check; CI eventually. | Same lint report as above, across all BCs. |
| `token-budget-audit` | Periodically, or when `verify-locality` fails check 5. | Per-BC recommendation: split-as-B (preferred) vs grow-as-C, with rationale. Never auto-splits. |

### Deferred (don't build until concrete pain)

`behavior-index`, `snapshot-graph`, `evolution-log` (as a separate skill — for now lives as `links:` in manifests and `.claude/evolution-log/` files), `failure-catalog` (lives in manifest's `failure_modes:`), `dead-code-sweep`, `drift-detector` (split between `module-manifest` validate and `verify-locality`), `runtime-self-location`, `observability-conventions`, `test-classifier` (lives in manifest's `tests:` field), `diff-discipline`, `capability-contract` as a separate skill.

---

## End-to-end example: `add-driver-id-type`

Walking through the change that's already committed in the repo, so you can read the artifacts.

**Change description:** "Add a `DriverId` value type to `mobile/favorite_drivers` as the first export. Wraps a non-empty string identifier; provides value equality."

### Step 1 — `context-pack`

Output: [`.claude/context-packs/add-driver-id-type.md`](.claude/context-packs/add-driver-id-type.md)

The pack identified `mobile/favorite_drivers` as the primary BC, no dep BCs (the BC has empty `deps:`), and a short load list (3 files). Estimated tokens: ~350. Well under the 60k cap; no escalation.

### Step 2 — `design-the-seam`

Output: "## Seam" section appended to the context pack. The seam captured:

- Signature: `class DriverId { final String value; DriverId(this.value); ... }`
- Constraint: `value` non-empty
- Error model: `ArgumentError` from constructor on empty
- Invariant introduced: `DriverId.value` is always a non-empty string
- Capabilities required: none (pure transform)
- Version impact: minor (`0.1.0 → 0.2.0`)

**Real catch:** the seam process surfaced that `const` constructor is incompatible with the non-empty invariant (would force `assert`-only enforcement, debug-only). Decision recorded in the seam doc; non-`const` constructor chosen. **This is exactly the value of seam-first** — the design tradeoff would have been hidden in implementation otherwise.

### Step 3 — `blast-radius-proof`

Output: [`.claude/blast-radius/add-driver-id-type.md`](.claude/blast-radius/add-driver-id-type.md)

Touched set: 5 files. Justifications: vacuously valid because no other BC exists yet — the proof is honest about being degenerate at this scale. Open risks: pubspec.yaml `test` dev-dep adds nothing runtime. Accepted.

### Step 4 — Implement

Files written:
- `mobile/favorite_drivers/lib/src/driver_id.dart` — full implementation (constructor with throw, `==`, `hashCode`, `toString`).
- `mobile/favorite_drivers/test/driver_id_test.dart` — six contract tests covering rejection, equality, hashCode, toString.
- `mobile/favorite_drivers/lib/favorite_drivers.dart` — added `export 'src/driver_id.dart' show DriverId;`.
- `mobile/favorite_drivers/MANIFEST.yaml` — exports, version, invariants, failure_modes, tests filled in.
- `mobile/favorite_drivers/pubspec.yaml` — version bump, `test` dev_dependency.

### Step 5 — `verify-locality`

Five checks. Result for this exercise:

| # | Check | Result |
|---|---|---|
| 1 | diff vs. touched set | Pass by inspection (entire repo was untracked at exercise time, so no mechanical baseline) |
| 2 | cross-BC imports | Pass (no `package:<other_bc>/` imports) |
| 3 | exports vs. surface | Pass (manifest `[DriverId]` ↔ surface `export ... show DriverId`) |
| 4 | capabilities | Pass (none used, none declared) |
| 5 | token budget | Pass (535 / 50000) |

### Step 6 — PR

Branch pushed, PR opened, merged into main: https://github.com/maisara-abourady/wya/pull/1

---

## Artifact map

```
wya/
  CONVENTIONS.md                       canonical conventions doc
  MANIFEST.schema.yaml                 schema every MANIFEST.yaml validates against
  PIPELINE.md                          this file

  scripts/
    arch-lint.sh                       backing lint for arch-conventions

  .claude/
    skills/
      arch-conventions/SKILL.md        canonical interpreter of CONVENTIONS.md
      module-manifest/SKILL.md         create / update / validate MANIFEST.yaml
      scaffold-module/SKILL.md         generate a new BC
      context-pack/SKILL.md            assemble per-change load list
      design-the-seam/SKILL.md         interface-first design
      blast-radius-proof/SKILL.md      citation-based safety proof
      verify-locality/SKILL.md         post-change five-check verification
      token-budget-audit/SKILL.md      diagnose oversized BCs
    context-packs/
      <change-id>.md                   per-change load list + seam
    blast-radius/
      <change-id>.md                   per-change safety proof
    evolution-log/                     decisions about the conventions themselves
                                       (entries: <YYYY-MM-DD>-<slug>.md)

  mobile/                              Flutter side
    <bc_name>/                         each BC is a Dart package
      pubspec.yaml
      MANIFEST.yaml
      README.md
      CODEOWNERS
      lib/<bc_name>.dart               public surface (only legal cross-BC import)
      lib/src/                         private implementation
      test/                            colocated tests

  backend/                             backend side (layout TBD; locks at first BC)
  contracts/                           shared schemas (layout TBD; locks at first BC)
```

---

## Gotchas and tripwires

### "My blast-radius proof is degenerate / vacuously valid"

Expected when there are 0–1 other BCs. The proof's job becomes load-bearing once you have at least 2 BCs to cite exclusions for. Don't try to make it look more impressive than it is — note the vacuity honestly in the proof.

### `verify-locality` check 1 can't run mechanically

Check 1 (diff vs. touched set) needs a committed baseline. If the repo is in a half-uncommitted state (e.g., you're stacking multiple changes without committing in between), check 1 falls back to manual inspection. The fix is to commit per change so each subsequent change has a clean diff.

### Manifest drift — `module-manifest validate` reports mismatches

The most common drift sources:

- Added an export but forgot to update `exports:` → fix manifest.
- Added a side effect (e.g., reading from a database) but didn't declare the capability → either remove the side effect or declare the capability with reasoning.
- Added a cross-BC import without adding to `deps:` → either declare the dep or refactor to remove the cross-BC reference.
- Removed an export but left it in `exports:` → fix manifest.

Run `module-manifest update` to interactively walk through these.

### "Seam-first feels like overhead for tiny changes"

If a change doesn't touch any public symbol or type, **skip `design-the-seam`**. It's only required when the public surface changes. For purely internal refactors or bug fixes, go straight from `context-pack` → `blast-radius-proof` → implement.

### "The skill isn't triggering when I describe my task"

Skills are routed by their `description:` frontmatter. If your phrasing doesn't match the trigger phrases, invoke the skill explicitly: `/<skill-name>` or "use the `<skill-name>` skill". The descriptions in each `SKILL.md` list known trigger phrases; expand them if a phrasing should match but doesn't.

### "I'm not sure which BC owns this change"

Run `context-pack` with the change description; if it surfaces ambiguity (multiple BCs match), it'll ask. If no BCs match, the change probably needs a new BC — invoke `scaffold-module` first.

### "I want to introduce a new capability that isn't in the closed set"

Don't widen the set casually. The closed-set guarantee is what makes capability contracts trustworthy. To add one: update `CONVENTIONS.md`, `MANIFEST.schema.yaml`, the lint script in `scripts/arch-lint.sh`, and add an entry under `.claude/evolution-log/`. All in one PR.

### "A BC went over the 50k budget"

Run `token-budget-audit`. The skill never auto-splits; it diagnoses and recommends. Two possible verdicts:

- **Split-as-B** (preferred): two semantic concerns; split into two BCs. Use `scaffold-module` for the new one.
- **Grow-as-C** (fallback): one concern with internal sub-structure; introduce package directories inside the BC with their own sub-manifests.

---

## Cheat-sheet: skill ↔ command

The fastest way to invoke any skill is the slash-command form:

```
/arch-conventions
/scaffold-module
/module-manifest
/context-pack
/design-the-seam
/blast-radius-proof
/verify-locality
/token-budget-audit
```

Or by natural-language request that matches the skill's trigger phrases. The skills are listed in `.claude/skills/` and Claude Code surfaces them automatically.

---

## Reference paths

- Conventions: `CONVENTIONS.md`
- Schema: `MANIFEST.schema.yaml`
- Lint: `scripts/arch-lint.sh`
- Skill files: `.claude/skills/<name>/SKILL.md`
- Per-change artifacts: `.claude/context-packs/`, `.claude/blast-radius/`
- Evolution log: `.claude/evolution-log/`

---

## Why this design — the short version

LLMs degrade as context grows. Their reliability depends on being able to load *just enough* of the codebase to make a change correctly. The traditional answer ("write good code, modular code, well-named code") isn't enough — it doesn't guarantee that any given change has a *small, predictable* file set. This pipeline does.

The bounded context is the locality unit. The manifest is the contract. The context pack is the load list. The seam is the contract change. The proof is the safety check. The verify is the receipt. Every piece exists to make sure that *future you* (or future Claude) can make a safe change without holding wya in their head.

If you find yourself fighting a piece of this pipeline, that's data — either the convention is wrong (rare; record an evolution-log entry and adjust) or the change is misshapen (common; re-decompose upstream into smaller change descriptions). Both are good outcomes. The bad outcome is silently working around the discipline; that's how locality is lost.
