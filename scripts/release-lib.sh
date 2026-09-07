# Shared helpers for scripts/release*.sh. ROOT must be set before sourcing.
# Not executed on its own.

release_die() { echo "error: $*" >&2; exit 1; }

release_cargo_workspace_version() {
  awk '
    /^\[workspace.package\]/ { p = 1; next }
    p && /^\[/ { exit }
    p && /^version = "/ {
      gsub(/"/, "", $3)
      print $3
      exit
    }
  ' "$ROOT/Cargo.toml"
}

release_nix_package_version() {
  awk '
    /^[[:space:]]*version = "/ {
      gsub(/[";]/, "", $3)
      print $3
      exit
    }
  ' "$ROOT/nix/rbitcoin.nix"
}

release_changelog_has_heading() {
  local ver="$1"
  grep -qE "^## \\[${ver}\\]" "$ROOT/CHANGELOG.md"
}

release_changelog_notes() {
  local ver="$1"
  awk -v ver="$ver" '
    $0 ~ ("^## \\[" ver "\\]") { p = 1; next }
    p && /^## \[/ { exit }
    p { print }
  ' "$ROOT/CHANGELOG.md" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

release_parse_semver() {
  local ver="$1"
  [[ "$ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 1
  REL_MAJOR="${BASH_REMATCH[1]}"
  REL_MINOR="${BASH_REMATCH[2]}"
  REL_PATCH="${BASH_REMATCH[3]}"
}

release_is_ship() {
  [[ "${REL_PATCH:-}" != "99" ]]
}

release_is_maint_branch() {
  local branch="$1"
  [[ "$branch" =~ ^v[0-9]+\.[0-9]+\.x$ ]]
}

release_kind() {
  local ver
  ver="$(release_cargo_workspace_version)"
  release_parse_semver "$ver" || release_die "Cargo.toml workspace version is not X.Y.Z: ${ver:-empty}"
  if release_is_ship; then
    echo ship
  else
    echo dev
  fi
}

release_set_cargo_version() {
  local new="$1"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rbitcoin-cargo-ver.XXXXXX")"
  awk -v new="$new" '
    /^\[workspace.package\]/ { p = 1 }
    p && /^\[/ && $0 != "[workspace.package]" { p = 0 }
    p && /^version = "/ { print "version = \"" new "\""; next }
    { print }
  ' "$ROOT/Cargo.toml" >"$tmp"
  mv "$tmp" "$ROOT/Cargo.toml"
}

release_set_nix_version() {
  local new="$1"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rbitcoin-nix-ver.XXXXXX")"
  awk -v new="$new" '
    BEGIN { done = 0 }
    !done && /^[[:space:]]*version = "/ {
      sub(/version = "[^"]*"/, "version = \"" new "\"")
      done = 1
    }
    { print }
  ' "$ROOT/nix/rbitcoin.nix" >"$tmp"
  mv "$tmp" "$ROOT/nix/rbitcoin.nix"
}

release_cut_changelog_ship() {
  local ver="$1"
  local date="$2"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rbitcoin-cl.XXXXXX")"
  awk -v ver="$ver" -v date="$date" '
    /^## \[Unreleased\]/ {
      print
      print ""
      print "## [" ver "] — " date
      next
    }
    { print }
  ' "$ROOT/CHANGELOG.md" >"$tmp"
  mv "$tmp" "$ROOT/CHANGELOG.md"
}

release_cut_changelog_dev_next() {
  local ver="$1"
  local toward="$2"
  local published="$3"
  local maint="$4"
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/rbitcoin-cl-dev.XXXXXX")"
  awk -v ver="$ver" -v toward="$toward" -v published="$published" -v maint="$maint" '
    /^## \[Unreleased\]/ {
      print
      print ""
      print "### Changed"
      print ""
      print "- **Workspace version " ver ":** in-tree toward " toward "."
      print "  Published GitHub Releases remain " published "; `" maint "` is the patch branch."
      next
    }
    { print }
  ' "$ROOT/CHANGELOG.md" >"$tmp"
  mv "$tmp" "$ROOT/CHANGELOG.md"
}

release_latest_maint_branch() {
  local names name best_maj=-1 best_min=-1 best=""
  local maj min
  names="$(
    git -C "$ROOT" for-each-ref --format='%(refname:short)' \
      'refs/heads/v*.*.x' 'refs/remotes/*/v*.*.x' 2>/dev/null || true
  )"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    name="${name##*/}"
    [[ "$name" =~ ^v([0-9]+)\.([0-9]+)\.x$ ]] || continue
    maj="${BASH_REMATCH[1]}"
    min="${BASH_REMATCH[2]}"
    if (( maj > best_maj || (maj == best_maj && min > best_min) )); then
      best_maj="$maj"
      best_min="$min"
      best="$name"
    fi
  done <<<"$names"
  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

release_plan_minor() {
  local ver="$1"
  release_parse_semver "$ver" || return 1
  [[ "$REL_PATCH" == "99" ]] || return 1
  REL_SHIP="${REL_MAJOR}.$((REL_MINOR + 1)).0"
  REL_MAINT="v${REL_MAJOR}.$((REL_MINOR + 1)).x"
  REL_DEV_NEXT="${REL_MAJOR}.$((REL_MINOR + 1)).99"
}

release_plan_major() {
  local ver="$1"
  release_parse_semver "$ver" || return 1
  [[ "$REL_PATCH" == "99" ]] || return 1
  REL_SHIP="$((REL_MAJOR + 1)).0.0"
  REL_MAINT="v$((REL_MAJOR + 1)).0.x"
  REL_DEV_NEXT="$((REL_MAJOR + 1)).0.99"
}

release_plan_patch() {
  local ver="$1"
  release_parse_semver "$ver" || return 1
  [[ "$REL_PATCH" != "99" ]] || return 1
  local next=$((REL_PATCH + 1))
  (( next < 99 )) || return 1
  REL_SHIP="${REL_MAJOR}.${REL_MINOR}.${next}"
  REL_MAINT="v${REL_MAJOR}.${REL_MINOR}.x"
  REL_DEV_NEXT=""
}

release_plan_dev_next() {
  local ver="$1"
  release_parse_semver "$ver" || return 1
  [[ "$REL_PATCH" == "0" ]] || return 1
  REL_SHIP=""
  REL_MAINT="v${REL_MAJOR}.${REL_MINOR}.x"
  REL_DEV_NEXT="${REL_MAJOR}.${REL_MINOR}.99"
  REL_TOWARD="${REL_MAJOR}.$((REL_MINOR + 1)).0"
}
