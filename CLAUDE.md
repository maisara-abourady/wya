# wya

Project-scoped Claude configuration lives in `.claude/`.

## Structure

- `product/` — product documents (PRDs, specs).
- `implementation-plans/` — implementation plans for ongoing work.
- `.claude/skills/` — project-scoped slash commands / skills available only when Claude is invoked from this directory.

## Conventions

- `.claude/` is committed (except `settings.local.json`) so collaborators share the same project-scoped tooling.
