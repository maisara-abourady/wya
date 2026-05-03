---
name: context-pack
description: |
  Use at the start of any code change in wya, once a change description has been
  fixed (source-agnostic — PRD output, ticket, Slack request, verbal). Produces
  the minimal, ranked file list a session must load to make the change safely —
  the load list. Re-run if the change scope shifts mid-implementation. Trigger
  phrases: "context pack", "what files do I need", "load list for this change",
  "pack for <change>", or any setup phase before implementation begins.
---

# context-pack

Most load-bearing skill in the wya pipeline. Without it, sessions still scrape; everything else is theatre. The pack's job is **deterministic**: given a change description, produce the smallest correct file set the LLM needs to make the change safely, with citations to invariants and failure modes that govern the touched BCs.

## Inputs

- **Change description** — free-text sentence (or short paragraph). Required. Source-agnostic: a PRD-derived change request, a ticket, a Slack note, or a verbal request all work as long as the description is concrete enough to match against BC summaries and exports.
- **Change ID** — kebab-case slug (e.g., `add-driver-id-type`). Required for naming the output artifact. Derive from the description if no upstream ID exists.
- **Optional `bc=<side>/<name>` hint** — primary BC if known. If omitted, the skill discovers it.

## Step 1 — Identify the primary BC

Walk all `MANIFEST.yaml` files under `mobile/`, `backend/`, `contracts/`. Match the change description against:

1. The BC's `summary:` field (highest weight).
2. The BC's `exports:` (medium weight — symbol matches in the description).
3. The BC name itself.

If exactly one BC matches strongly, that's the primary BC. If multiple match, surface the candidates and ask the user to pick — do not guess. If none match, the change targets a BC that doesn't yet exist; route to `scaffold-module`.

## Step 2 — Identify dependency BCs to include

Read the primary BC's manifest `deps:`. For each declared dep, include it in the pack **only if** at least one of its `exports:` is referenced (by name) in the change description, or in the part of the primary BC's surface file that the change is touching.

Do not include all deps blindly. The point is the *minimal* pack.

## Step 3 — Pull invariants and failure modes

For the primary BC and every included dep BC:

- Copy the manifest's `invariants:` list verbatim.
- Copy the manifest's `failure_modes:` list verbatim.

These are **required reading**, not optional. They constrain what the change is allowed to do; without them, future-Claude will hallucinate guarantees the BC doesn't actually make.

## Step 4 — Pull tests

For the primary BC:

- All tests with `kind: contract` (they protect the cross-BC API the change might touch).
- All tests with `kind: invariant` (they protect the guarantees stated in the manifest).
- Tests with `kind: regression` only if the change description names a past bug or incident.

For dep BCs: their `kind: contract` tests only.

## Step 5 — Assemble pack

Output a ranked markdown file at `.claude/context-packs/<change-id>.md` containing:

```
# Context pack: <change-id>

**Change:** <one-sentence restatement>
**Primary BC:** <side>/<name>
**Dep BCs included:** <list, with reason for each>

## Required reading (load these first)

| Path | Why |
|---|---|
| <bc>/MANIFEST.yaml | invariants + failure_modes for primary BC |
| <bc>/lib/<bc>.dart  | public surface (cross-BC contract) |
| <bc>/lib/src/<file> | implementation file the change touches |
| <bc>/test/<file>    | contract tests for the touched export |
| <dep>/MANIFEST.yaml | invariants for dep BC                 |
| <dep>/<surface>     | dep's public surface                  |

## Pinned manifest excerpts

### <side>/<name>
invariants:
- ...
failure_modes:
- ...

### <side>/<dep>
invariants:
- ...

## Estimated tokens
<sum>

## Routing
- Next: `design-the-seam` if a public symbol changes; otherwise direct implementation.
```

Estimate total tokens (sum of file sizes via the same heuristic the lint uses). Flag if the pack exceeds **60,000 tokens** — that means the change is too large for a single session and should be re-decomposed upstream into smaller change descriptions.

## Step 6 — Escalate when the change doesn't fit

If the change spans **more than 2 BCs**, do not silently expand the pack. Surface that the change is misshapen and route back upstream for splitting (re-decompose into smaller change descriptions). The locality property is non-negotiable; widening the pack to fit defeats the purpose.

If the primary BC has no matching `exports:` for the symbol the change references, surface that the seam doesn't yet exist — route to `design-the-seam` to add it before implementation.

## What context-pack never does

- **Never includes whole-repo greps.** The pack is built from manifests, not from search.
- **Never includes BCs not on the dep path.** "Just in case" inclusions defeat the locality property.
- **Never includes private files** (`lib/src/*` of dep BCs). The pack only includes private files of the *primary* BC.
- **Never substitutes implementation reading for manifest reading.** Invariants from the manifest are the source of truth; if they conflict with the implementation, the implementation is wrong, not the manifest.
- **Never expands silently when over 60k tokens.** Halt and split.

## Output artifact

`.claude/context-packs/<change-id>.md`. Version-controlled. Referenced by every downstream skill for this change (`design-the-seam`, `blast-radius-proof`, `verify-locality`).

The `<change-id>` is a kebab-case slug — derive it from the change description, or reuse an upstream ID if your change source provides one.

## Integrations

- **Consumes:** all `MANIFEST.yaml` files under `mobile/`, `backend/`, `contracts/`; the change description from any upstream source (PRD pipeline, ticket, ad-hoc).
- **Feeds:** `design-the-seam`, `blast-radius-proof`, the implementation session itself.
- **Re-run trigger:** if the change scope shifts during implementation, re-run with the updated description; the previous pack file is overwritten with a version note.
