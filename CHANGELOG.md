# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `current` / `show` — print highest known version
- `doctor` / `sync` — detect drift between `.release-tag` and Git tags
- `init` — first release (default `v0.1.0`, override with `INIT_TAG`)
- `rc` — pre-release candidate bumps
- Explicit versions (`vX.Y.Z`, optional pre-release suffix)
- Flags: `--dry-run`, `--no-push`, `--tags-only`, `--sign`, `--remote`, `--allow-dirty`, `--force-branch`, `--changelog`, `--message`
- Optional hooks: `.release-pre.sh`, `.release-post.sh`
- Branch guard via `RELEASE_BRANCH`
- Custom tag messages via flag or `RELEASE_MESSAGE` / `RELEASE_MESSAGE_FILE`
- CI test workflow; GitHub Release body from `CHANGELOG.md` when available
- README documenting all use cases

## [0.0.1] - 2026-05-18

### Added

- Initial `release.sh` with `patch`, `minor`, and `major` bumps
- `.release-tag` tracking alongside Git tags
- Project documentation (README, LICENSE, CONTRIBUTING)
