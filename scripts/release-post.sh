#!/usr/bin/env bash
# After a ship version is on the branch tip: annotated tag, push the tag,
# and for X.Y.0 create the vX.Y.x patch branch at the same commit.
set -euo pipefail

ROOT=""
DRY=0
PUSH=1
ALLOW_BRANCH=""
ALLOW_DIVERGED=0
REMOTE="origin"
HERE="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "usage: $0 [--dry-run] [--no-push] [--allow-branch NAME] [--allow-diverged] [--remote NAME] [--root DIR]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-push) PUSH=0 ;;
    --allow-branch)
      [[ $# -ge 2 ]] || usage
      ALLOW_BRANCH="$2"
      shift
      ;;
    --allow-diverged) ALLOW_DIVERGED=1 ;;
    --remote)
      [[ $# -ge 2 ]] || usage
      REMOTE="$2"
      shift
      ;;
    --root)
      [[ $# -ge 2 ]] || usage
      ROOT="$2"
      shift
      ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done

if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$HERE/.." && pwd)"
fi
cd "$ROOT"
# shellcheck source=release-lib.sh
source "$HERE/release-lib.sh"

ver="$(release_cargo_workspace_version)"
release_parse_semver "$ver" || release_die "Cargo.toml workspace version is not X.Y.Z: ${ver:-empty}"
release_is_ship || release_die "workspace $ver is not a ship version (patch 99 is in-tree only)"

rel_args=(--root "$ROOT" --tag-only --remote "$REMOTE")
[[ "$DRY" -eq 1 ]] && rel_args+=(--dry-run)
[[ "$PUSH" -eq 0 ]] && rel_args+=(--no-push)
[[ -n "$ALLOW_BRANCH" ]] && rel_args+=(--allow-branch "$ALLOW_BRANCH")
[[ "$ALLOW_DIVERGED" -eq 1 ]] && rel_args+=(--allow-diverged)

bash "$HERE/release.sh" "${rel_args[@]}"

maint="v${REL_MAJOR}.${REL_MINOR}.x"
if [[ "$REL_PATCH" == "0" ]]; then
  echo "maint=${maint}"
  echo "dev_next=${REL_MAJOR}.${REL_MINOR}.99"
  if [[ "$DRY" -eq 1 ]]; then
    echo "release-post: would create ${maint} at HEAD"
    exit 0
  fi
  if git rev-parse -q --verify "refs/heads/${maint}" >/dev/null; then
    local_sha="$(git rev-parse "refs/heads/${maint}")"
    head="$(git rev-parse HEAD)"
    [[ "$local_sha" == "$head" ]] || \
      release_die "local ${maint} exists at $local_sha, not HEAD $head"
  else
    git branch "$maint" HEAD
    echo "release-post: created local ${maint} at $(git rev-parse --short HEAD)"
  fi
  if [[ "$PUSH" -eq 1 ]]; then
    git fetch "$REMOTE" "+refs/heads/${maint}:refs/remotes/${REMOTE}/${maint}" >/dev/null 2>&1 || true
    if git rev-parse -q --verify "refs/remotes/${REMOTE}/${maint}" >/dev/null; then
      remote_sha="$(git rev-parse "refs/remotes/${REMOTE}/${maint}")"
      head="$(git rev-parse HEAD)"
      [[ "$remote_sha" == "$head" ]] || \
        release_die "remote ${REMOTE}/${maint} exists at $remote_sha, not HEAD $head"
      echo "release-post: ${REMOTE}/${maint} already at HEAD"
    else
      git push "$REMOTE" "refs/heads/${maint}"
      echo "release-post: pushed ${maint} → $REMOTE"
    fi
  else
    echo "release-post: not pushed (--no-push). Push with:"
    echo "  git push ${REMOTE} refs/heads/${maint}"
  fi
else
  echo "maint=${maint}"
  echo "release-post: patch ${ver}; did not create ${maint} (already on the line)"
fi
