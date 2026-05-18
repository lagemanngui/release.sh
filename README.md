# release.sh

A small, dependency-free Bash script for **semantic version bumps**, **annotated Git tags**, and **pushing releases** to `origin`—with a committed `.release-tag` file so the latest version is always visible in the tree.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Why use this?

Many teams want releases to be a single command: bump the version, tag `HEAD`, push the tag, and record the version in the repo. `release.sh` does exactly that without Node, Python, or a release CLI—only Bash and Git.

## Requirements

- **Bash** 4.0+ (macOS/Linux)
- **Git** with a remote named `origin`
- **`sort -V`** for version ordering (GNU coreutils or BSD `sort` on recent macOS)

## Installation

Copy `release.sh` into the root of the Git repository you want to release:

```bash
curl -fsSL https://raw.githubusercontent.com/lagemanngui/release.sh/main/release.sh -o release.sh
chmod +x release.sh
```

Or clone this repository and copy the script:

```bash
git clone https://github.com/lagemanngui/release.sh.git
cp release.sh /path/to/your-project/
chmod +x /path/to/your-project/release.sh
```

Run it from the repository root (the directory that contains `.git`).

## Usage

```bash
./release.sh patch   # 1.2.3 → 1.2.4
./release.sh minor   # 1.2.3 → 1.3.0
./release.sh major   # 1.2.3 → 2.0.0
```

Tags use a **`v` prefix** (e.g. `v1.2.3`). The script prints the transition, then:

1. Creates an **annotated tag** on the current commit
2. **Pushes** the tag to `origin`
3. Writes the new version to **`.release-tag`**, commits, and **pushes** the current branch

Example output:

```text
v1.2.3 -> v1.2.4
pushed v1.2.4 and updated .release-tag on main
```

## How versioning works

The next version is derived from the **highest** known release among:

| Source | Role |
|--------|------|
| **`.release-tag`** | Single-line file in the repo (e.g. `v1.2.3`), committed after each release |
| **Git tags** | All local tags matching `v*.*.*` (semver-shaped) |

If neither exists, the baseline is **`v0.1.4`** (configurable at the top of `release.sh` via `DEFAULT_TAG`).

The script refuses to create a tag that already exists and validates that versions match `vMAJOR.MINOR.PATCH`.

## Project layout

| File | Purpose |
|------|---------|
| `release.sh` | Release entrypoint |
| `.release-tag` | Last released version (tracked in Git) |

After the first release, `.release-tag` is created automatically; commit it with your project.

## Troubleshooting

| Problem | What to check |
|---------|----------------|
| `not a git repository` | Run from inside a Git repo |
| `tag vX.Y.Z already exists` | Tag exists locally or on remote; pick another bump or delete the tag if it was a mistake |
| Push fails | `origin` remote, credentials, and branch protections |
| Wrong “current” version | Ensure `.release-tag` and/or Git tags are correct; highest `v*.*.*` wins |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and pull requests are welcome on [GitHub](https://github.com/lagemanngui/release.sh).

## License

[MIT](LICENSE) © 2026 [lagemanngui](https://github.com/lagemanngui).
