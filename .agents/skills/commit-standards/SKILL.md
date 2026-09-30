---
name: commit-standards
description: Write this repo's commit messages: the Conventional Commit type for a change, the version bump it triggers, and the `app/`-only rule for what actually releases. Use when writing or amending a commit message, or deciding whether a change should release.
---

# Commit standards

release-please reads every commit on `main` and turns it into a version number
and a changelog entry. The message is the release trigger, not documentation.

## Format

```
<type>(<scope>): <summary>

<body>
```

- **type** — required; from the table below.
- **scope** — optional, the area: `android`, `release`, `agent`, `deps`,
  `supabase`, or the app feature (`members`, `home`, `leads`, `plans`, `auth`,
  `gyms`).
- **summary** — imperative, ≤ 72 characters, no trailing period: `declare
  INTERNET in the main manifest`, not `declared` / `declaring` / `manifest fix`.
- **body** — the *why*, wrapped at 72: the cause, the constraint, what you
  rejected. The diff already carries the what, so a commit whose why is visible
  in the diff has no body.

## Types

| Type | Bump | For |
|---|---|---|
| `feat` | minor | behaviour the owner can see |
| `fix` | patch | a defect |
| `perf` | patch | same behaviour, faster |
| `refactor` | — | same behaviour, different code |
| `docs` | — | prose, comments |
| `test` | — | tests only |
| `build` | — | dependencies, Gradle, `pubspec` |
| `ci` | — | workflows |
| `chore` | — | no behaviour change |

`feat!:` or a `BREAKING CHANGE:` footer bumps major — use it when the owner's
stored data or the Supabase schema changes shape.

## What the type decides

- **The type describes the whole commit.** One logical change per commit: a
  defect fix plus a screen refactor is two commits, because the type is what
  decides the version. Type a change for what it is, so the release that follows
  is the one the change deserves.
- **Only `app/` releases.** The released package is `app`, so a `fix:` touching
  only `.github/` or `docs/` cuts no version — the pipeline stops after its first
  job. Pipeline work is `ci(release): …`, docs work is `docs: …`.

Jobs, timings, escape hatches: `docs/ci-cd.md`.

## Before you commit

- Every file in the commit matches the type — no second change riding along.
- The summary reads as an instruction to the codebase and fits 72 characters.
- A body is there only when the why is not in the diff.
- `app/` + `feat`/`fix` means a release is coming: that is the intent, not a
  surprise.
