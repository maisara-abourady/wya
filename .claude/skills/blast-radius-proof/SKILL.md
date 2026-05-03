---
name: blast-radius-proof
description: |
  Use after the seam is designed and before any implementation begins. Produces
  a citation-based written proof that the change cannot affect files outside a
  declared touched set. Re-run if the touched set shifts. Trigger phrases:
  "blast radius", "safety proof", "prove this is local", "what could this
  break", or any pre-implementation safety gate.
---

# blast-radius-proof

Produce a written, citation-based safety proof for a planned change. The proof states a **touched set** of files and proves — by citation — that no file outside that set can be affected. The proof is the artifact attached to the PR; without it, the change is not safe to implement.

## Inputs

- **Context pack** — `.claude/context-packs/<change-id>.md`. Required.
- **Seam** — the "## Seam" section appended to the context pack. Required if the change modifies a public symbol; not required if the change is internal.
- **Implementation outline** — the user-stated plan: which files will be edited, which created, which deleted.

## Required structure of the proof

The proof is a markdown document with exactly four sections — none is optional, and each has a strict format:

### 1. Touched set

The exact, exhaustive list of files that will be created, modified, or deleted by the change. No globs. No "and related." If a file isn't named here and the change touches it, the proof is void.

```
- mobile/favorite_drivers/lib/favorite_drivers.dart  (modified)
- mobile/favorite_drivers/lib/src/roster.dart        (created)
- mobile/favorite_drivers/test/roster_test.dart      (created)
- mobile/favorite_drivers/MANIFEST.yaml              (modified)
```

### 2. Exclusion claim

A single sentence: *"No file outside the touched set can be affected by this change because of the citations below."*

### 3. Justifications

For **every BC not in the touched set** (every BC that exists in the repo but is not being modified), at least one citation justifying its exclusion. Citations must come from one of these sources — never from inference:

| Citation source | Form |
|---|---|
| Public-surface rule | "BC X is excluded because the change does not modify the surface file that other BCs import from." |
| Manifest `exports:` | "BC X exports {…}; none are affected by the touched set." |
| Manifest `invariants:` | "BC X's invariant '…' is preserved because the touched set does not alter the data path it depends on." |
| Manifest `deps:` | "BC X does not depend on the primary BC; the change cannot reach it." |
| Capability contract | "BC X's capabilities {…} cannot be invoked by this change; the change adds no entries to those capability domains." |
| Type/signature constraint | "Symbol Y's signature is unchanged; callers cannot observe the implementation change." |
| Cross-side rule | "BC X is on side A; the change touches side B; cross-side rule prohibits direct effect." |

A justification that boils down to *"shouldn't affect"*, *"implementation detail"*, *"unlikely to break"*, or *"low risk"* is **not** a citation and **invalidates the proof**. The architecture has the wrong seam — route back to `design-the-seam` or `sd-change-request`.

### 4. Open risks

Any aspect of the change not covered by a citation. Surface honestly. Examples:
- Side effects via shared infrastructure (logger, telemetry) not modeled in capability contracts.
- Runtime configuration that affects behavior outside the touched set.
- Concurrent code paths that cross BCs in ways the static graph doesn't capture.

If this section is non-empty, the user decides whether to accept the residual risk before implementation proceeds. If the user accepts, the entry is preserved in the proof as part of the audit trail.

## Pass / fail rule

The proof is **valid** only if:

1. Every BC in the repo that is not in the touched set has at least one citation.
2. No citation uses inference language (*shouldn't, probably, unlikely, edge-case, implementation detail*).
3. Every cited manifest field exists in the cited manifest at the time of writing.
4. The "Open risks" section either is empty or has been accepted by the user.

A proof that fails any of these is **not** a valid blast-radius proof, and the change is not safe to implement under it. The honest move is to either:

- Re-scope the change so the touched set actually does have local citations — likely needs `design-the-seam` to introduce or move a seam.
- Re-decompose the change request via `sd-change-request` if it spans too many BCs to prove locally.

## Output artifact

`.claude/blast-radius/<change-id>.md`. Version-controlled. Attached to the PR description for the change.

## What blast-radius-proof never does

- **Never accepts hand-waving.** No "shouldn't affect," no "implementation detail." Citations or nothing.
- **Never loads files outside the context pack** to "double-check." If the proof needs files the pack didn't include, the pack was wrong — re-run `context-pack`, do not silently expand.
- **Never tightens the touched set after seeing the diff.** The proof is written *before* implementation; widening it post-hoc to fit the actual diff defeats its purpose. If the implementation grew, the proof is invalidated; re-run.
- **Never marks the proof valid with non-empty Open risks unless the user has explicitly accepted them.**

## Integrations

- **Consumes:** the context pack and (usually) the seam appended to it.
- **Produces:** `.claude/blast-radius/<change-id>.md`.
- **Feeds:** the implementation session, then `verify-locality` post-change.
- **Routes back to:** `design-the-seam` when citations can't be made; `sd-change-request` when the change spans too many BCs.
