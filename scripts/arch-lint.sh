#!/bin/bash
# scripts/arch-lint.sh — lint wya bounded contexts against CONVENTIONS.md.
#
# Usage:
#   scripts/arch-lint.sh                       # lint all BCs
#   scripts/arch-lint.sh <side>/<bc_name>      # lint one BC
#
# Requires: python3 with PyYAML (pip3 install pyyaml).
# Exit codes:
#   0 — clean
#   1 — violations found
#   2 — environment error (missing tooling, BC not found)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "arch-lint: python3 not found" >&2
  exit 2
fi
if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "arch-lint: PyYAML not installed (run: pip3 install pyyaml)" >&2
  exit 2
fi

python3 - "$REPO_ROOT" "$TARGET" <<'PY'
import re, sys, yaml
from pathlib import Path

repo = Path(sys.argv[1])
target = sys.argv[2]

SIDES = ("mobile", "backend", "contracts")
CAP_SET = {"db", "net", "fs", "time", "rng", "env", "process", "crypto"}
NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.-]+)?$")
DEP_RE = re.compile(r"^(mobile|backend|contracts)/[a-z][a-z0-9_]*$")
BUDGET = 50_000


def discover():
    bcs = []
    for side in SIDES:
        side_dir = repo / side
        if not side_dir.is_dir():
            continue
        for entry in sorted(side_dir.iterdir()):
            if not entry.is_dir() or entry.name.startswith("."):
                continue
            if (entry / "MANIFEST.yaml").exists():
                bcs.append((side, entry.name, entry))
    return bcs


def check_mobile_shape(bc_dir, name):
    issues = []
    for f in ["pubspec.yaml", "MANIFEST.yaml", "README.md", "CODEOWNERS", f"lib/{name}.dart"]:
        if not (bc_dir / f).is_file():
            issues.append(f"missing file: {f}")
    for d in ["lib/src", "test"]:
        if not (bc_dir / d).is_dir():
            issues.append(f"missing directory: {d}")
    return issues


def check_shape(side, name, bc_dir):
    if side == "mobile":
        return check_mobile_shape(bc_dir, name)
    # backend/contracts layouts are TBD — minimal check only.
    if not (bc_dir / "MANIFEST.yaml").is_file():
        return ["missing file: MANIFEST.yaml"]
    return []


def check_manifest(side, name, manifest):
    issues = []
    if not isinstance(manifest, dict):
        return ["MANIFEST.yaml is not a mapping"]
    for key in ["name", "version", "summary", "exports", "deps", "capabilities", "invariants", "tests"]:
        if key not in manifest:
            issues.append(f"missing required field: {key}")
    n = manifest.get("name")
    if n != name:
        issues.append(f"name '{n}' != directory '{name}'")
    if isinstance(n, str) and not NAME_RE.match(n):
        issues.append(f"name '{n}' violates pattern ^[a-z][a-z0-9_]*$")
    v = manifest.get("version")
    if isinstance(v, str) and not VERSION_RE.match(v):
        issues.append(f"version '{v}' is not semver")
    s = manifest.get("summary")
    if isinstance(s, str) and len(s) > 200:
        issues.append(f"summary length {len(s)} > 200")
    caps = manifest.get("capabilities") or []
    bad_caps = [c for c in caps if c not in CAP_SET]
    if bad_caps:
        issues.append(f"capabilities not in closed set: {bad_caps}")
    deps = manifest.get("deps") or []
    bad_deps = [d for d in deps if not DEP_RE.match(d)]
    if bad_deps:
        issues.append(f"deps not in qualified form <side>/<name>: {bad_deps}")
    for d in deps:
        if not DEP_RE.match(d):
            continue
        dep_side = d.split("/")[0]
        if side == "mobile" and dep_side not in ("mobile", "contracts"):
            issues.append(f"cross-side: mobile may not depend on {dep_side}/* ({d})")
        if side == "backend" and dep_side not in ("backend", "contracts"):
            issues.append(f"cross-side: backend may not depend on {dep_side}/* ({d})")
        if side == "contracts" and dep_side != "contracts":
            issues.append(f"cross-side: contracts may not depend on {dep_side}/* ({d})")
    if f"{side}/{name}" in deps:
        issues.append(f"self-dep: {side}/{name} listed in deps")
    return issues


def check_ownership(bc_dir):
    f = bc_dir / "CODEOWNERS"
    if not f.is_file():
        return ["CODEOWNERS missing"]
    rules = [
        line for line in f.read_text().splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]
    if not rules:
        return ["CODEOWNERS has no ownership rules"]
    return []


def count_tokens(bc_dir):
    total_words = 0
    for path in bc_dir.rglob("*"):
        if not path.is_file() or path.name == ".gitkeep":
            continue
        rel_parts = path.relative_to(bc_dir).parts
        if any(p.startswith(".") for p in rel_parts):
            continue
        try:
            text = path.read_text(errors="ignore")
        except Exception:
            continue
        total_words += len(text.split())
    return int(total_words * 1.3)


def check_budget(tokens):
    return [f"token budget exceeded: {tokens} / {BUDGET}"] if tokens > BUDGET else []


bcs = discover()
if target:
    bcs = [b for b in bcs if f"{b[0]}/{b[1]}" == target]
    if not bcs:
        print(f"arch-lint: BC '{target}' not found", file=sys.stderr)
        sys.exit(2)
if not bcs:
    print("arch-lint: no BCs found under mobile/, backend/, contracts/")
    sys.exit(0)

total = 0
for side, name, bc_dir in bcs:
    qualified = f"{side}/{name}"
    print(f"\narch-conventions lint: {qualified}")

    shape_issues = check_shape(side, name, bc_dir)
    print(f"  shape ({len(shape_issues)}):" + (" ok" if not shape_issues else ""))
    for i in shape_issues:
        print(f"    {i}")

    try:
        manifest = yaml.safe_load((bc_dir / "MANIFEST.yaml").read_text())
        manifest_issues = check_manifest(side, name, manifest)
    except Exception as e:
        manifest_issues = [f"failed to parse MANIFEST.yaml: {e}"]
    print(f"  manifest ({len(manifest_issues)}):" + (" ok" if not manifest_issues else ""))
    for i in manifest_issues:
        print(f"    {i}")

    ownership_issues = check_ownership(bc_dir)
    print(f"  ownership ({len(ownership_issues)}):" + (" ok" if not ownership_issues else ""))
    for i in ownership_issues:
        print(f"    {i}")

    tokens = count_tokens(bc_dir)
    budget_issues = check_budget(tokens)
    print(f"  budget ({len(budget_issues)}): {tokens} / {BUDGET} tokens")
    for i in budget_issues:
        print(f"    {i}")

    print("  surface (deferred): not yet language-aware")
    print("  deps-drift (deferred): not yet language-aware")
    print("  capability-drift (deferred): not yet language-aware")

    total += len(shape_issues) + len(manifest_issues) + len(ownership_issues) + len(budget_issues)

print(f"\ntotal violations: {total}")
sys.exit(0 if total == 0 else 1)
PY
