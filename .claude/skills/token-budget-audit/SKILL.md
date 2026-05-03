---
name: token-budget-audit
description: |
  Use periodically, or when `verify-locality` flags a budget overrun. Determines
  whether an oversized BC should be split into two BCs (split-as-B) or grow
  internal package structure (grow-as-C). Trigger phrases: "audit budgets",
  "BC over budget", "is anything too big", "split this BC", "token check".
---

# token-budget-audit

Walk every BC, identify those over the 50,000-token cap, and produce a per-BC recommendation: split into two BCs, or grow internal package structure. **Never auto-splits.** The decision is the user's; this skill provides the diagnosis and the options.

## Inputs

- None required. Walks all BCs by default.
- Optional `bc=<side>/<name>` to audit a single BC.

## Steps

1. Run `scripts/arch-lint.sh` and capture the budget line for each BC.
2. Filter to BCs at or over **45,000 tokens** (90% of the 50,000 cap — early warning) and **over 50,000** (hard violation).
3. For each, read the BC's `MANIFEST.yaml`, `lib/<bc>.dart` (or surface file), and a sampling of `lib/src/*` to assess shape.
4. Apply the decision rule below per BC.

## Decision rule

For each over-budget BC:

### Question 1 — Are there two distinct semantic concerns?

Read the BC's `summary:`, `exports:`, and `invariants:`. Look for:

- Two clusters of exports that don't share invariants.
- A summary that uses "and" to join two responsibilities (e.g., "manages drivers **and** computes proximity").
- Failure modes that split cleanly along a domain seam.

**If yes** — recommend **split-as-B** (preferred). The two clusters become two BCs. Each gets its own manifest, surface, capabilities, deps, budget. Cross-BC links between the two new BCs go through the public-surface rule like any other.

### Question 2 — If one concern, has internal sub-structure emerged?

Look for clusters of files in `lib/src/` that:

- Import each other heavily but don't import other clusters.
- Map to distinct sub-responsibilities of the BC's single concern.
- Have natural sub-public-surfaces (a few "entry" files vs. many "internal" files).

**If yes** — recommend **grow-as-C**. Introduce package directories *inside* the BC, each with its own sub-`MANIFEST.yaml` and sub-surface. Cross-package imports inside the BC must go through sub-package surfaces. The outer `index.*` and `MANIFEST.yaml` remain the only cross-BC contract.

### Question 3 — Neither?

If the BC is one concern with a flat structure that has simply grown large:

- The first move is to look harder for hidden seams (re-read with fresh eyes; check whether new BCs have come up in PRDs that this BC actually contains).
- If still no seam, consider whether the budget itself needs revisiting (an evolution-log entry; this is rare and should not be the default escape).
- Avoid grow-as-C as a face-saving fallback. It is a last resort, not a tie-breaker.

## Output

For each over-budget BC, a recommendation block:

```
<side>/<bc_name>: <tokens> / 50000   (<over by>)

  candidate seams (split-as-B):
    - <seam description>: <export cluster A> vs. <export cluster B>
    - ...

  candidate sub-structure (grow-as-C):
    - <sub-package candidate>: <files>
    - ...

  recommendation: split-as-B | grow-as-C | re-examine
  rationale: <one paragraph>

  next step: invoke `scaffold-module` for <new BC> | manual sub-package creation
```

If no BCs are over budget, the report is:

```
token-budget-audit: all BCs under 50,000 / 50,000 (highest: <side>/<name> @ <tokens>)
no action required.
```

## What token-budget-audit never does

- **Never auto-splits a BC.** The decision is semantic and the user's. The skill only diagnoses.
- **Never recommends grow-as-C when split-as-B is plausible.** Split is preferred; grow-as-C is for genuinely-one-concern-but-deep cases.
- **Never raises the 50k cap to silence a violation.** The cap is an evolution-log decision, not a per-BC accommodation.
- **Never operates without reading the manifest and a code sample.** A purely numerical recommendation is meaningless; the rule depends on semantic shape.

## Integrations

- **Consumes:** all `MANIFEST.yaml` files; lint output; samples of BC source.
- **Produces:** a recommendation report; no file artifacts unless the user accepts and proceeds.
- **Routes to:** `scaffold-module` (split-as-B path), or direct file work (grow-as-C path).
- **Triggered by:** scheduled run, or `verify-locality` budget failure.
