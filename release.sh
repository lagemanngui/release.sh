#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TAG_FILE="$ROOT/.release-tag"
CHANGELOG_FILE="$ROOT/CHANGELOG.md"
DEFAULT_TAG="v0.1.4"
INIT_TAG="${INIT_TAG:-v0.1.0}"
HOOK_PRE="$ROOT/.release-pre.sh"
HOOK_POST="$ROOT/.release-post.sh"

REMOTE="${RELEASE_REMOTE:-origin}"
RELEASE_BRANCH="${RELEASE_BRANCH:-}"
DRY_RUN=0
NO_PUSH=0
SIGN=0
TAGS_ONLY=0
ALLOW_DIRTY=0
FORCE_BRANCH=0
UPDATE_CHANGELOG=0
TAG_MESSAGE=""

usage() {
  cat >&2 <<'EOF'
Usage: release.sh [options] <command>

Commands:
  patch|minor|major     Semantic version bump
  rc                    Bump pre-release (v1.2.3 -> v1.2.3-rc.1, v1.2.3-rc.1 -> v1.2.3-rc.2)
  vX.Y.Z                Release an explicit version (optional pre-release: v1.0.0-rc.1)
  init                  First release (default v0.1.0, override with INIT_TAG)
  current|show          Print the highest known version
  doctor|sync           Report .release-tag vs Git tag drift

Options:
  --dry-run             Show actions without changing anything
  --no-push             Create tag and commit locally; do not push
  --tags-only           Tag only; skip .release-tag commit
  --sign                GPG-sign the annotated tag
  --remote <name>       Remote to push to (default: origin, or RELEASE_REMOTE)
  --allow-dirty         Allow uncommitted changes
  --force-branch        Skip branch name check (RELEASE_BRANCH)
  --changelog           Update CHANGELOG.md (or set RELEASE_CHANGELOG=1)
  --message, -m <text>  Custom tag message (or RELEASE_MESSAGE / RELEASE_MESSAGE_FILE)

Hooks (optional, executable):
  .release-pre.sh       Run before tagging; non-zero exits abort
  .release-post.sh      Run after a successful release

Environment:
  RELEASE_REMOTE, RELEASE_BRANCH, RELEASE_SIGN=1, RELEASE_CHANGELOG=1,
  RELEASE_MESSAGE, RELEASE_MESSAGE_FILE, INIT_TAG
EOF
  exit 1
}

die() {
  echo "error: $*" >&2
  exit 1
}

normalize_tag() {
  local t="$1"
  [[ "$t" == v* ]] || t="v$t"
  echo "$t"
}

parse_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --no-push) NO_PUSH=1 ;;
      --tags-only) TAGS_ONLY=1 ;;
      --sign) SIGN=1 ;;
      --allow-dirty) ALLOW_DIRTY=1 ;;
      --force-branch) FORCE_BRANCH=1 ;;
      --changelog) UPDATE_CHANGELOG=1 ;;
      --remote)
        shift
        [[ $# -gt 0 ]] || die "--remote requires a name"
        REMOTE="$1"
        ;;
      --message | -m)
        shift
        [[ $# -gt 0 ]] || die "--message requires text"
        TAG_MESSAGE="$1"
        ;;
      -h | --help) usage ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
    shift
  done
  ARGS=("$@")
}

require_git() {
  cd "$ROOT"
  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository"
}

collect_tags() {
  local t
  while IFS= read -r t; do
    [[ -n "$t" ]] && printf '%s\n' "$t"
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
  while IFS= read -r t; do
    [[ -n "$t" ]] && printf '%s\n' "$t"
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*-*' 2>/dev/null || true)
}

highest_tag() {
  local candidates=() t
  if [[ -f "$TAG_FILE" ]]; then
    t="$(tr -d '[:space:]' < "$TAG_FILE")"
    [[ -n "$t" ]] && candidates+=("$(normalize_tag "$t")")
  fi
  while IFS= read -r t; do
    [[ -n "$t" ]] && candidates+=("$t")
  done < <(collect_tags)
  if ((${#candidates[@]} == 0)); then
    echo "$DEFAULT_TAG"
    return
  fi
  printf '%s\n' "${candidates[@]}" | sort -V | tail -1
}

valid_tag_format() {
  local t="$1"
  [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]
}

parse_version() {
  local raw="${1#v}"
  PRERELEASE=""
  PRERELEASE_NUM=""
  if [[ ! "$raw" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([0-9A-Za-z]+)\.([0-9]+))?$ ]]; then
    die "invalid version tag: $1"
  fi
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  if [[ -n "${BASH_REMATCH[5]:-}" ]]; then
    PRERELEASE="${BASH_REMATCH[5]}"
    PRERELEASE_NUM="${BASH_REMATCH[6]}"
  fi
}

compute_bump() {
  local bump="$1"
  case "$bump" in
    patch) NEW_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
    minor) NEW_TAG="v${MAJOR}.$((MINOR + 1)).0" ;;
    major) NEW_TAG="v$((MAJOR + 1)).0.0" ;;
    rc)
      if [[ -z "$PRERELEASE" ]]; then
        NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}-rc.1"
      elif [[ "$PRERELEASE" == "rc" ]]; then
        NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}-rc.$((PRERELEASE_NUM + 1))"
      else
        die "rc bump not supported from ${CURRENT} (use an explicit vX.Y.Z-rc.N tag)"
      fi
      ;;
    *)
      die "internal: unknown bump $bump"
      ;;
  esac
}

check_dirty() {
  [[ "$ALLOW_DIRTY" -eq 1 ]] && return 0
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree has uncommitted changes (commit, stash, or use --allow-dirty)"
  fi
}

check_branch() {
  [[ "$FORCE_BRANCH" -eq 1 || -z "$RELEASE_BRANCH" ]] && return 0
  local branch
  branch="$(git branch --show-current)"
  [[ "$branch" == "$RELEASE_BRANCH" ]] ||
    die "refusing to release from branch '$branch' (expected '$RELEASE_BRANCH', or use --force-branch)"
}

tag_exists() {
  git rev-parse "$1" >/dev/null 2>&1
}

resolve_tag_message() {
  if [[ -n "$TAG_MESSAGE" ]]; then
    return 0
  fi
  if [[ -n "${RELEASE_MESSAGE:-}" ]]; then
    TAG_MESSAGE="$RELEASE_MESSAGE"
    return 0
  fi
  if [[ -n "${RELEASE_MESSAGE_FILE:-}" && -f "$RELEASE_MESSAGE_FILE" ]]; then
    TAG_MESSAGE="$(<"$RELEASE_MESSAGE_FILE")"
    return 0
  fi
  TAG_MESSAGE="Release $NEW_TAG"
}

run_hook() {
  local script="$1"
  [[ -x "$script" ]] || return 0
  RELEASE_CURRENT="$CURRENT" RELEASE_NEW="$NEW_TAG" RELEASE_DRY_RUN="$DRY_RUN" "$script"
}

highest_tag_from_git_only() {
  local candidates=() t
  while IFS= read -r t; do
    [[ -n "$t" ]] && candidates+=("$t")
  done < <(collect_tags)
  if ((${#candidates[@]} == 0)); then
    echo ""
    return
  fi
  printf '%s\n' "${candidates[@]}" | sort -V | tail -1
}

cmd_current() {
  echo "$(highest_tag)"
}

cmd_doctor() {
  local file_tag="" git_high
  git_high="$(highest_tag_from_git_only)"
  if [[ -f "$TAG_FILE" ]]; then
    file_tag="$(tr -d '[:space:]' < "$TAG_FILE")"
    [[ -n "$file_tag" ]] && file_tag="$(normalize_tag "$file_tag")"
  fi
  echo "highest git tag: ${git_high:-<none>}"
  echo ".release-tag:    ${file_tag:-<missing>}"
  if [[ -z "$git_high" && -z "$file_tag" ]]; then
    echo "status: ok (no releases yet)"
    return 0
  fi
  if [[ -z "$file_tag" ]]; then
    echo "status: warn (.release-tag missing; run a release or add the file)"
    return 1
  fi
  if [[ -z "$git_high" ]]; then
    echo "status: warn (no semver tags; .release-tag may be ahead)"
    return 1
  fi
  if [[ "$file_tag" == "$git_high" ]]; then
    echo "status: ok"
    return 0
  fi
  echo "status: drift (.release-tag and highest tag differ)"
  return 1
}

update_changelog() {
  [[ "$UPDATE_CHANGELOG" -eq 1 ]] || return 0
  [[ -f "$CHANGELOG_FILE" ]] || {
    echo "warn: --changelog set but $CHANGELOG_FILE not found" >&2
    return 0
  }
  local ver="${NEW_TAG#v}" date
  date="$(date +%Y-%m-%d)"
  if ! grep -q '^## \[Unreleased\]' "$CHANGELOG_FILE"; then
    echo "warn: no ## [Unreleased] section in CHANGELOG.md" >&2
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  line="## [${ver}] - ${date}"
  awk -v insert="$line" '
    /^## \[Unreleased\]/ { print; print ""; print insert; next }
    { print }
  ' "$CHANGELOG_FILE" >"$tmp"
  mv "$tmp" "$CHANGELOG_FILE"
}

dry_run_note() {
  echo "[dry-run] $*"
}

create_tag() {
  local sign_args=()
  [[ "$SIGN" -eq 1 || "${RELEASE_SIGN:-}" == "1" ]] && sign_args=(-s)
  resolve_tag_message
  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_note "git tag -a ${sign_args[*]:-} -m $(printf %q "$TAG_MESSAGE") $NEW_TAG"
    return 0
  fi
  if ((${#sign_args[@]} > 0)); then
    git tag -a "${sign_args[@]}" -m "$TAG_MESSAGE" "$NEW_TAG"
  else
    git tag -a -m "$TAG_MESSAGE" "$NEW_TAG"
  fi
}

push_tag() {
  if [[ "$NO_PUSH" -eq 1 ]]; then
    [[ "$DRY_RUN" -eq 1 ]] && dry_run_note "(skipped push) git push $REMOTE $NEW_TAG"
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_note "git push $REMOTE $NEW_TAG"
    return 0
  fi
  git push "$REMOTE" "$NEW_TAG"
}

record_release() {
  [[ "$TAGS_ONLY" -eq 1 ]] && return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run_note "write $NEW_TAG to .release-tag"
    [[ "$UPDATE_CHANGELOG" -eq 1 ]] && dry_run_note "update CHANGELOG.md"
    dry_run_note "git add .release-tag CHANGELOG.md (if changed)"
    dry_run_note "git commit -m chore: record release $NEW_TAG in .release-tag"
    if [[ "$NO_PUSH" -eq 0 ]]; then
      dry_run_note "git push $REMOTE HEAD"
    fi
    return 0
  fi
  printf '%s\n' "$NEW_TAG" >"$TAG_FILE"
  update_changelog
  git add "$TAG_FILE"
  [[ "$UPDATE_CHANGELOG" -eq 1 && -f "$CHANGELOG_FILE" ]] && git add "$CHANGELOG_FILE"
  git commit -m "chore: record release $NEW_TAG in .release-tag"
  if [[ "$NO_PUSH" -eq 0 ]]; then
    git push "$REMOTE" HEAD
  fi
}

perform_release() {
  valid_tag_format "$NEW_TAG" || die "invalid tag format: $NEW_TAG"
  tag_exists "$NEW_TAG" && die "tag $NEW_TAG already exists"

  check_dirty
  check_branch
  run_hook "$HOOK_PRE"

  echo "$CURRENT -> $NEW_TAG"
  create_tag
  push_tag
  record_release
  run_hook "$HOOK_POST"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] no changes made"
  elif [[ "$TAGS_ONLY" -eq 1 ]]; then
    echo "tagged $NEW_TAG on $(git branch --show-current)"
  elif [[ "$NO_PUSH" -eq 1 ]]; then
    echo "created $NEW_TAG locally and updated .release-tag (not pushed)"
  else
    echo "pushed $NEW_TAG and updated .release-tag on $(git branch --show-current)"
  fi
}

cmd_init() {
  if [[ -n "$(highest_tag_from_git_only)" || -f "$TAG_FILE" ]]; then
    die "init refused: releases already exist (use patch/minor/major or an explicit tag)"
  fi
  CURRENT="(none)"
  NEW_TAG="$(normalize_tag "$INIT_TAG")"
  valid_tag_format "$NEW_TAG" || die "invalid INIT_TAG: $NEW_TAG"
  perform_release
}

main() {
  parse_flags "$@"
  ((${#ARGS[@]} > 0)) || usage

  [[ "${RELEASE_SIGN:-}" == "1" ]] && SIGN=1
  [[ "${RELEASE_CHANGELOG:-}" == "1" ]] && UPDATE_CHANGELOG=1

  require_git

  local cmd="${ARGS[0]}"
  case "$cmd" in
    current | show)
      cmd_current
      exit 0
      ;;
    doctor | sync)
      cmd_doctor
      exit $?
      ;;
    init)
      cmd_init
      exit 0
      ;;
    patch | minor | major | rc)
      CURRENT="$(highest_tag)"
      parse_version "$CURRENT"
      compute_bump "$cmd"
      perform_release
      ;;
    v*)
      CURRENT="$(highest_tag)"
      NEW_TAG="$(normalize_tag "$cmd")"
      perform_release
      ;;
    *)
      if [[ "$cmd" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        CURRENT="$(highest_tag)"
        NEW_TAG="$(normalize_tag "$cmd")"
        perform_release
      else
        usage
      fi
      ;;
  esac
}

main "$@"
