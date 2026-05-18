#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TAG_FILE="$ROOT/.release-tag"
DEFAULT_TAG="v0.1.4"

usage() {
  echo "Usage: $0 patch|minor|major" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage
case "$1" in
  patch | minor | major) BUMP="$1" ;;
  *) usage ;;
esac

cd "$ROOT"
git rev-parse --git-dir >/dev/null 2>&1 || {
  echo "error: not a git repository" >&2
  exit 1
}

highest_tag() {
  local candidates=() t
  if [[ -f "$TAG_FILE" ]]; then
    t="$(tr -d '[:space:]' < "$TAG_FILE")"
    [[ -n "$t" ]] && candidates+=("$t")
  fi
  while IFS= read -r t; do
    [[ -n "$t" ]] && candidates+=("$t")
  done < <(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)
  if ((${#candidates[@]} == 0)); then
    echo "$DEFAULT_TAG"
    return
  fi
  printf '%s\n' "${candidates[@]}" | sort -V | tail -1
}

parse_version() {
  local raw="${1#v}"
  if [[ ! "$raw" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "error: invalid version tag: $1" >&2
    exit 1
  fi
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
}

CURRENT="$(highest_tag)"
parse_version "$CURRENT"

case "$BUMP" in
  patch) NEW_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  minor) NEW_TAG="v${MAJOR}.$((MINOR + 1)).0" ;;
  major) NEW_TAG="v$((MAJOR + 1)).0.0" ;;
esac

if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  echo "error: tag $NEW_TAG already exists" >&2
  exit 1
fi

echo "$CURRENT -> $NEW_TAG"
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"
git push origin "$NEW_TAG"
printf '%s\n' "$NEW_TAG" > "$TAG_FILE"
git add "$TAG_FILE"
git commit -m "chore: record release $NEW_TAG in .release-tag" -- "$TAG_FILE"
git push origin HEAD
echo "pushed $NEW_TAG and updated .release-tag on $(git branch --show-current)"
