#!/usr/bin/env bash
# Brief GitHub Release notes: platform blurb + CHANGELOG ### Highlights.
# Full Keep a Changelog body stays in CHANGELOG.md.
set -euo pipefail

ROOT=""
VER=""
HERE="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "usage: $0 [X.Y.Z] [--root DIR]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || usage
      ROOT="$2"
      shift
      ;;
    -h|--help) usage ;;
    *)
      [[ -z "$VER" ]] || usage
      VER="$1"
      ;;
  esac
  shift
done

if [[ -z "$ROOT" ]]; then
  ROOT="$(cd "$HERE/.." && pwd)"
fi
cd "$ROOT"
# shellcheck source=release-lib.sh
source "$HERE/release-lib.sh"

if [[ -z "$VER" ]]; then
  VER="$(release_cargo_workspace_version)"
fi
release_parse_semver "$VER" || release_die "version is not X.Y.Z: ${VER:-empty}"
release_is_ship || release_die "workspace $VER is not a ship version (patch 99 is in-tree only)"
release_require_highlights "$VER"

hl="$(release_changelog_highlights "$VER" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
printf '%s\n' "rbitcoin v${VER}

Linux **musl x86_64** is the operator binary (statically linked).
Windows is CRT-static PE (no IoRing). Darwin aarch64 is ad-hoc
codesigned, **not notarized** (\`xattr -d com.apple.quarantine\`).

### Highlights

${hl}

Full notes: CHANGELOG.md \`## [${VER}]\`."
