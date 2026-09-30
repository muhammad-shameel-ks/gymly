## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Product design

V1 scope, IA, visual/motion system, data contract: see `DESIGN.md` at the repo root.

### CI/CD

`main` is the release branch, and merging a `feat/`, `fix/` or `hotfix/` PR into
it publishes a release automatically — `fix` a patch, `feat` a minor, breaking a
major; `chore`/`ci`/`docs`/`build` release nothing. Workflows, caching, the
release flow and Android signing: see `docs/ci-cd.md`.
