# release.sh

A small, dependency-free Bash script for **semantic versioning**, **annotated Git tags**, **`.release-tag` tracking**, and optional **CHANGELOG** updates—without Node, Python, or a release CLI.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Why use this?

Teams often want one command to bump a version, tag `HEAD`, push, and record the version in the repo. `release.sh` does that with only Bash and Git, plus optional safety checks, dry-runs, hooks, and CI-friendly modes.

## Requirements

- **Bash** 4.0+
- **Git**
- **`sort -V`** for version ordering (GNU coreutils or recent BSD/macOS)

## Installation

Copy `release.sh` into your Git repository root:

```bash
curl -fsSL https://raw.githubusercontent.com/lagemanngui/release.sh/main/release.sh -o release.sh
chmod +x release.sh
```

Run it from the directory that contains `.git` (and, after the first release, `.release-tag`).

## Quick start

```bash
./release.sh init          # first release → v0.1.0 (see init below)
./release.sh patch         # v0.1.0 → v0.1.1
./release.sh current       # print highest known version
./release.sh doctor        # check .release-tag vs Git tags
```

Tags always use a **`v` prefix** (e.g. `v1.2.3`).

---

## Use cases

### 1. Standard semantic release (default)

Bump, tag the current commit, push the tag, write `.release-tag`, commit, and push the branch.

```bash
./release.sh patch   # 1.2.3 → 1.2.4
./release.sh minor   # 1.2.3 → 1.3.0
./release.sh major   # 1.2.3 → 2.0.0
```

**When to use:** routine releases from `main` with everything pushed to `origin`.

---

### 2. First release (`init`)

Create the initial tag when the repo has no semver tags and no `.release-tag`.

```bash
./release.sh init              # → v0.1.0
INIT_TAG=v1.0.0 ./release.sh init   # → v1.0.0
```

**When to use:** greenfield projects before any version exists. Fails if tags or `.release-tag` already exist.

---

### 3. Show current version (`current` / `show`)

Print the highest version from `.release-tag` and Git tags (no side effects).

```bash
./release.sh current
# v1.2.4
```

**When to use:** CI badges, scripts, or checking state before a release.

---

### 4. Health check (`doctor` / `sync`)

Compare `.release-tag` with the highest semver Git tag and report drift.

```bash
./release.sh doctor
```

**When to use:** after manual tag edits, failed pushes, or restoring a clone.

---

### 5. Preview without changes (`--dry-run`)

Print the version transition and every Git action that would run.

```bash
./release.sh --dry-run minor
```

**When to use:** verifying the next version, teaching the flow, or CI smoke tests.

---

### 6. Explicit version

Set an exact tag instead of a bump rule.

```bash
./release.sh v2.0.0
./release.sh 2.0.0          # v prefix added automatically
./release.sh v1.0.0-beta.1  # pre-release identifier
```

**When to use:** hotfix branches, aligning with an external version, or one-off pre-releases.

---

### 7. Pre-release bumps (`rc`)

Increment release-candidate versions on the same `MAJOR.MINOR.PATCH`.

```bash
# v1.2.3     → v1.2.3-rc.1
# v1.2.3-rc.1 → v1.2.3-rc.2
./release.sh rc
```

Other pre-release IDs (e.g. `v1.0.0-beta.1`) can be set with an **explicit version** (use case 6). A `patch`/`minor`/`major` bump from a pre-release tag advances the stable version (e.g. `v1.2.3-rc.2` → `v1.2.4`).

---

### 8. Local-only release (`--no-push`)

Create the tag and `.release-tag` commit locally without pushing.

```bash
./release.sh --no-push patch
```

**When to use:** review before push, air-gapped workflows, or pushing from CI later.

---

### 9. Tag only (`--tags-only`)

Create and push the Git tag; skip updating `.release-tag` and the follow-up commit.

```bash
./release.sh --tags-only v1.0.0
```

**When to use:** consumers that only read Git tags, or when another process records the version.

---

### 10. Custom remote

Push to a remote other than `origin`.

```bash
./release.sh --remote upstream patch
RELEASE_REMOTE=upstream ./release.sh patch
```

---

### 11. Signed tags

GPG-sign the annotated tag.

```bash
./release.sh --sign patch
RELEASE_SIGN=1 ./release.sh patch
```

**When to use:** supply-chain or policy requirements for signed releases.

---

### 12. CHANGELOG updates (`--changelog`)

Insert a dated `## [X.Y.Z]` section under `## [Unreleased]` in `CHANGELOG.md` (Keep a Changelog style).

```bash
./release.sh --changelog patch
RELEASE_CHANGELOG=1 ./release.sh minor
```

Requires an existing `CHANGELOG.md` with `## [Unreleased]`. The version in the heading omits the `v` prefix.

---

### 13. Custom tag message

Override the default `Release vX.Y.Z` annotation message.

```bash
./release.sh -m "Security fix for CVE-2026-0001" patch
RELEASE_MESSAGE="My message" ./release.sh patch
RELEASE_MESSAGE_FILE=notes.txt ./release.sh patch
```

---

### 14. Release hooks

Optional executable scripts beside `release.sh`:

| File | When | Behavior |
|------|------|----------|
| `.release-pre.sh` | Before tagging | Non-zero exit aborts the release |
| `.release-post.sh` | After success | Notifications, builds, etc. |

Exported variables: `RELEASE_CURRENT`, `RELEASE_NEW`, `RELEASE_DRY_RUN` (`0` or `1`).

---

### 15. Safety: clean tree

By default, releases are refused if there are uncommitted changes.

```bash
./release.sh --allow-dirty patch
```

---

### 16. Safety: branch guard

Restrict releases to a specific branch (e.g. `main`).

```bash
RELEASE_BRANCH=main ./release.sh patch
./release.sh --force-branch patch   # override
```

---

### 17. Combining flags

Typical combinations:

```bash
# Preview a signed release on main
RELEASE_BRANCH=main ./release.sh --dry-run --sign patch

# Local RC with changelog, push later
./release.sh --no-push --changelog rc

# Tag-only dry run
./release.sh --dry-run --tags-only v3.0.0
```

---

## How versioning works

The **next** version (for bumps) is based on the **highest** value among:

| Source | Role |
|--------|------|
| `.release-tag` | Single-line file (e.g. `v1.2.3`), updated after each full release |
| **Git tags** | `vMAJOR.MINOR.PATCH` and `vMAJOR.MINOR.PATCH-PRERELEASE` |

If neither exists, the baseline is **`v0.1.4`** (edit `DEFAULT_TAG` at the top of `release.sh`).

Valid tag shapes:

- `v1.2.3`
- `v1.2.3-rc.1`, `v1.0.0-beta.2`, etc.

The script refuses to create a tag that already exists.

---

## Default release flow

For `./release.sh patch` (and similar, without `--tags-only` / `--no-push`):

1. Optional checks (clean tree, branch name)
2. `.release-pre.sh` (if present)
3. Annotated tag on `HEAD`
4. `git push <remote> <tag>`
5. Write `.release-tag`, optional `CHANGELOG.md` edit, commit, `git push <remote> HEAD`
6. `.release-post.sh` (if present)

Example output:

```text
v1.2.3 -> v1.2.4
pushed v1.2.4 and updated .release-tag on main
```

---

## Project layout

| File | Purpose |
|------|---------|
| `release.sh` | Release entrypoint |
| `.release-tag` | Last released version (tracked in Git) |
| `CHANGELOG.md` | Optional; updated with `--changelog` |
| `.release-pre.sh` | Optional pre-release hook |
| `.release-post.sh` | Optional post-release hook |

---

## GitHub Actions

This repository includes:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Test** | Push / PR | Runs `release.sh` scenarios in a fresh Git repo |
| **Release** | Push tag `v*` | Zip `release.sh`, `.release-tag`, `README.md`; publish a GitHub Release (body from `CHANGELOG.md` when a matching section exists) |

To reuse the release workflow, push an annotated tag; the archive is attached automatically.

---

## Environment variables

| Variable | Effect |
|----------|--------|
| `RELEASE_REMOTE` | Remote name (default: `origin`) |
| `RELEASE_BRANCH` | Allowed branch; unset = any branch |
| `RELEASE_SIGN=1` | GPG-sign tags (same as `--sign`) |
| `RELEASE_CHANGELOG=1` | Update `CHANGELOG.md` (same as `--changelog`) |
| `RELEASE_MESSAGE` | Custom tag message |
| `RELEASE_MESSAGE_FILE` | Path to tag message file |
| `INIT_TAG` | Target for `init` (default: `v0.1.0`) |

---

## Troubleshooting

| Problem | What to check |
|---------|----------------|
| `not a git repository` | Run from inside a Git repo |
| `tag vX.Y.Z already exists` | Tag exists locally or on remote |
| `working tree has uncommitted changes` | Commit/stash or use `--allow-dirty` |
| `refusing to release from branch` | Switch branch or use `--force-branch` |
| `init refused: releases already exist` | Use `patch`/`minor`/`major` or an explicit tag |
| Push fails | Remote name, credentials, branch protection |
| Wrong current version | Run `./release.sh doctor`; fix `.release-tag` and/or tags |
| `rc bump not supported` | Use an explicit `vX.Y.Z-rc.N` tag |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Keep changes small and portable (Bash 4+, Git, common Unix tools).

## License

[MIT](LICENSE) © 2026 [lagemanngui](https://github.com/lagemanngui).
