# wya conventions

Canonical statement of wya's architectural conventions. Every project-scoped skill in `.claude/skills/` reads from this file. The `arch-conventions` skill is the canonical interpreter — any check or rule not encoded in that skill or in `scripts/arch-lint.sh` effectively does not exist.

If you change this file, add an entry under `.claude/evolution-log/<YYYY-MM-DD>-<slug>.md` recording the change, the trigger, and the alternatives considered.

## Module unit

The unit of architecture in wya is the **bounded context** (BC). A BC is a coherent domain area that:

- Is owned by one team (one `CODEOWNERS` line at the BC root).
- Is built and tested as a single unit.
- Carries a single public surface (one surface file at the BC root, see *Public surface rule*).
- Carries a single declared capability set.
- Carries a single token budget (≤ 50,000).

A BC is **not** a package, a folder of utilities, or a layer (e.g., not "controllers" or "models"). It is a feature-shaped slice of the product.

## Repo partition

wya is a monorepo with three top-level *sides*:

| Side | Purpose | Languages |
|---|---|---|
| `mobile/` | Flutter (Dart) mobile client | Dart |
| `backend/` | Backend services | TBD — locked at first backend BC scaffold |
| `contracts/` | Shared, language-agnostic API and event schemas consumed by both sides | YAML / JSON / Proto |

Every BC lives under exactly one side. A BC is referenced by its **qualified name** `<side>/<bc-name>` (e.g., `mobile/favorite_drivers`, `backend/billing`, `contracts/user`).

### Reserved (non-BC) top-level entries

- `.claude/`, `.git/`, `.github/`, dotfiles
- `product/`, `implementation-plans/`, `scripts/`
- Repo-wide files: `CONVENTIONS.md`, `MANIFEST.schema.yaml`, `README.md`, `LICENSE`, `CODEOWNERS`, `.gitignore`

Anything else at the repo root must be one of `mobile/`, `backend/`, or `contracts/`.

## Naming

BC names are **snake_case** (`^[a-z][a-z0-9_]*$`): the Dart package ecosystem disallows hyphens in package names, and snake_case is portable across all languages. The directory name, the value of `name:` in the manifest, and (for Dart) the `lib/<bc_name>.dart` filename must all match.

## Directory shape

Each side imposes a layout. The lint walks the side directories and checks the corresponding shape.

### `mobile/<bc_name>/` — Dart package

```
mobile/<bc_name>/
  pubspec.yaml              # Dart package definition; external Dart deps
  MANIFEST.yaml             # wya BC manifest (validated against MANIFEST.schema.yaml)
  README.md
  CODEOWNERS
  lib/
    <bc_name>.dart          # public surface — only legal cross-BC import target
    src/                    # private implementation (Dart convention)
  test/                     # colocated tests
```

External Dart dependencies are declared in `pubspec.yaml`. *Cross-BC* dependencies are declared in `MANIFEST.yaml` (`deps:`). The two are independent concerns.

### `backend/<bc_name>/` — TBD

Layout is locked at the first `backend/` BC scaffold, when the backend runtime is chosen. Until then, scaffolding under `backend/` is blocked.

### `contracts/<bc_name>/` — TBD

Layout is locked at the first `contracts/` BC scaffold, when the contract-format choice is made (OpenAPI? Proto? Plain YAML?). Until then, scaffolding under `contracts/` is blocked.

## Public surface rule

Code outside a BC may import only from the BC's surface file:

| Side | Surface file |
|---|---|
| `mobile/<bc>` | `mobile/<bc>/lib/<bc>.dart` |
| `backend/<bc>` | TBD |
| `contracts/<bc>` | TBD |

Imports from any other file inside the BC, from outside the BC, are violations. Inside the BC, files import from each other freely.

## Dependency rule

A BC's `MANIFEST.yaml` declares its cross-BC dependencies in the `deps:` field as **qualified names** (`<side>/<bc_name>`). Actual cross-BC imports must exactly match the declared set: every declared dep must be used; every used dep must be declared. The lint cross-checks; mismatches are violations.

The cross-BC import graph is a DAG.

### Cross-side rules

- A `mobile/` BC may depend only on `mobile/*` and `contracts/*`.
- A `backend/` BC may depend only on `backend/*` and `contracts/*`.
- A `contracts/` BC may not depend on `mobile/*` or `backend/*` — contracts are leaves.

These are enforced by lint.

## Token budget

Each BC's combined size — code + docs + tests + manifest — must be ≤ **50,000 tokens**. Token counting uses the project's tokenizer if available; otherwise approximate as `word_count * 1.3`. The current count is recorded in `MANIFEST.yaml` as `token_budget_used:` and refreshed on every commit that touches the BC.

When a BC overruns the budget, see *Just-in-time-C protocol* below.

## Capability vocabulary

A BC declares which side effects it is allowed to perform. The closed set:

| Capability | Meaning |
|---|---|
| `db` | Reads or writes persistent storage owned by the project (server DB, local SQLite, Hive, etc.) |
| `net` | Performs outbound network calls (HTTP, gRPC, etc.) |
| `fs` | Reads or writes the local filesystem outside the BC's own bundle |
| `time` | Observes wall-clock time (non-deterministic) |
| `rng` | Uses randomness |
| `env` | Reads environment variables |
| `process` | Spawns or controls OS processes |
| `crypto` | Performs cryptographic operations |

The set is closed. Adding a new capability requires updating this file, `MANIFEST.schema.yaml`, the lint script, and an evolution-log entry — in one PR.

Code inside a BC must not perform a capability not declared in its manifest. A BC with no declared capabilities is a **pure transform** — the strongest claim a manifest can make.

## Ownership

Each BC carries a single `CODEOWNERS` file at its root naming the owner (team or person). Cross-BC ownership is not allowed; if two teams need to own parts of one BC, the BC is misshapen and should be split.

## Just-in-time-C protocol

When `token-budget-audit` flags a BC over 50k, choose one of:

1. **Split-as-B (preferred when possible).** The BC contains two distinct *semantic* concerns. Split into two BCs at the seam. Each gets its own manifest, public surface, capabilities, and budget. The split is decided by the user; the audit skill never auto-splits.

2. **Grow-as-C (fallback).** The BC is one concern but has accumulated internal sub-structure. Introduce package directories *inside* the BC, each with its own sub-`MANIFEST.yaml` and sub-surface. Cross-package imports inside the BC go through sub-package surface files. The BC's outer surface and `MANIFEST.yaml` remain the only cross-BC contract.

The protocol is **just-in-time**: never adopt grow-as-C preemptively. Internal package boundaries earn their place by being revealed by real code overrunning the budget, never by elegance.

## Evolution log

Decisions about the conventions themselves — this file, `MANIFEST.schema.yaml`, the closed capability set, the budget, the side partition — are recorded as entries in `.claude/evolution-log/<YYYY-MM-DD>-<slug>.md`. Each entry records the change, the trigger, and the alternatives considered. This is the durable record of *why* the conventions are what they are, queryable by future maintainers without scraping commit history.
