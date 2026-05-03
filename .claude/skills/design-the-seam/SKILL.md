---
name: design-the-seam
description: |
  Use after the context pack is produced and before any implementation begins,
  whenever the change adds or modifies a public symbol, a public type, or a
  cross-BC contract. Forces interface-first design — the seam is written and
  validated before any body. Trigger phrases: "design the seam", "interface
  first", "what should the API be", "add a new export", or any change to a BC's
  public surface.
---

# design-the-seam

Force interface-first design. The seam — signature, types, errors, invariants, capabilities, version impact — is written, validated, and locked **before** any implementation body is written. Output is a contract callers can rely on without reading internals.

## Inputs

- **Context pack** — `.claude/context-packs/<change-id>.md`. Required.
- **Target symbol** — the specific export (function, type, class, event) being added or changed.
- **Intent** — one sentence stating what the symbol must let callers do.

## Required outputs (the seam itself)

The seam document must specify each of these — none is optional:

1. **Signature.** Function/method shape with parameter names and types, return type. For a class or type, the public field/method shape.
2. **Parameter constraints.** Refinement on raw types — non-empty, range, format, allowed values, ownership semantics. Anything callers need to satisfy. State as preconditions.
3. **Return semantics.** What the return value represents, when it can be null/empty, freshness guarantees, ordering guarantees.
4. **Error model.** What can go wrong, how it's surfaced (thrown? returned union? sentinel?). Each error case is a named entry that maps to a `failure_modes:` entry in the BC's manifest.
5. **Invariants preserved.** Which manifest invariants this symbol is responsible for upholding, and how. If the symbol introduces a new invariant, the manifest's `invariants:` is updated in the same change.
6. **Capabilities required.** Which entries from the closed capability set the implementation will use. Must be a subset of the BC's declared `capabilities:` — if not, surface that as a deliberate widening that needs justification.
7. **Version impact.** Major / minor / patch per the rules in `module-manifest`. Recorded so the manifest version bump matches the seam change.

## Procedure

1. Read the context pack. Load the BC's manifest, surface file, and any directly relevant src files.
2. Draft the seam document inline (it gets appended to the context pack — see *Output artifact*).
3. Write the seam as a **stub** in the BC's surface file: full signature, full types, body throws `UnimplementedError` (Dart) or equivalent. The body comes later.
4. Update `MANIFEST.yaml`:
   - `exports:` — add the new symbol name.
   - `version:` — bump per the rule in step (7) above.
   - `invariants:`, `failure_modes:`, `capabilities:` — update if the seam requires it.
5. Run `arch-conventions` lint. **The seam is locked only when lint passes.** If it fails, fix the manifest or the stub before continuing — never advance to implementation with a non-conformant seam.
6. Implementation follows in a separate step.

## Anti-patterns

- **Never design implementation before contract.** "I'll write it and figure out the signature later" is the failure mode. The signature *is* the design.
- **Never relax an invariant to make implementation easier.** If an invariant is in the way, the design is wrong, not the invariant.
- **Never widen capabilities silently.** Adding `net` because you suddenly need it is a deliberate, justified change — surface it.
- **Never skip the manifest update.** The seam in code and the seam in manifest must land in the same change. A stub in `lib/<bc>.dart` without a corresponding entry in `exports:` is drift in waiting.
- **Never write a body during seam design.** Stubs throw; that's the contract.

## When the seam reveals the change is wrong

If you cannot cleanly state any of the seven required outputs — especially the error model or invariants preserved — that is a signal the *change* is misshapen, not that the seam is hard. Halt and route back to `sd-change-request` for re-scoping. The cost of fixing this here is small; the cost of fixing it after implementation is large.

## Output artifact

A "## Seam" section is **appended** to `.claude/context-packs/<change-id>.md`, containing the seven required outputs above plus the stubbed-code excerpt.

Code-level changes:
- Updated `lib/<bc>.dart` with the stubbed export.
- Updated `MANIFEST.yaml`.

These are committed together with the seam document.

## Integrations

- **Consumes:** the context pack from `context-pack`, the BC's current `MANIFEST.yaml` and surface file.
- **Feeds:** `blast-radius-proof` (which uses the seam to define the touched set), the implementation session.
- **Routes back to:** `sd-change-request` if the seam reveals the change is misshapen; `module-manifest` if the manifest update is non-trivial.
