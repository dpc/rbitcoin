---
name: release
description: >-
  Cut, tag, and publish rbitcoin GitHub Releases (minor, patch, or major).
  Use when the user says "do a minor release", "do a patch release",
  "do a major release", "cut a release", "tag a release", or asks to bump
  workspace.package.version / open a version-bump PR / create vX.Y.x.
---

# rbitcoin releases

Read [`docs/releases.md`](docs/releases.md) first. Do not invent a
second process. Worktree + HTTPS push + poll: [`AGENTS.md`](AGENTS.md).

## Decide which playbook

| User said | Script | Base |
|-----------|--------|------|
| “do a minor release” | `./scripts/release-cut.sh --minor` | `origin/master` at `X.Y.99` |
| “do a patch release with …” | `--latest-maint` then `--patch` | `origin/vX.Y.x` (or the line they named) |
| “do a major release” | `--major` | `origin/master` at `X.Y.99` |

`--print-plan` before writing files. `patch 99` is never a tag.

**Major:** read `docs/road-to-1.0.md`. If any 1.0 promise is open, stop and
report. Do not tag `v1.0.0` anyway.

## Ship PR (minor / major / patch)

1. `git fetch origin`. Worktree on a topic branch. Never commit the bump on
   `master`.
2. Run the cut command. Edit README / SECURITY / `docs/road-to-1.0.md` /
   `docs/experimental-mainnet.md` so they match the new version. Keep
   CHANGELOG notes non-empty (`./scripts/release-gate.sh` must pass).
3. Push HTTPS; `gh pr create` targeting **`master`** (minor/major) or
   **`vX.Y.x`** (patch).
4. Labels: **`release`** and **`core-functional`** (`gh label create`
   if missing).
5. `gh pr checks --watch`. Merge only when required checks **and**
   `core-functional` **and** `release-extra` are green.

## Tag immediately after merge (do not delay)

```bash
~/.config/rbitcoin-grok/gh-login.sh
gh pr merge <N> --merge --repo reardencode/rbitcoin
# If merge is blocked on review / ruleset: ask the operator, then continue
# from the merge SHA without waiting on the .99 PR.

BASE=master   # vX.Y.x for a patch PR
git fetch origin
# Do not `git switch master` — it may already be checked out in another worktree.
git switch -C "tag/vX.Y.Z" "origin/${BASE}"
./scripts/release-post.sh --no-push --allow-branch "tag/vX.Y.Z"
git push https://github.com/reardencode/rbitcoin.git refs/tags/vX.Y.Z
# X.Y.0 only:
git push https://github.com/reardencode/rbitcoin.git refs/heads/vX.Y.x
```

Confirm Actions `release.yml` started on the tag. App SSH is missing here;
do not `git push origin`.

If `gh pr merge` is denied, ask the operator to merge and tag the merge
commit the same way as soon as the SHA exists.

## After X.Y.0 only: `.99` PR

New worktree from `origin/master` (now at X.Y.0):

```bash
./scripts/release-cut.sh --dev-next
```

Point narrative banners at **X.Y.99**. PR to `master` without ship labels.
Merge when required cargo checks are green. Do not tag `.99`.

## Patch cherry-pick

1. `./scripts/release-cut.sh --latest-maint` unless the user named a line.
2. Cherry-pick onto that branch. If it does not apply, stop.
3. If `master` lacks the fix, say so in the PR body (do not skip master
   silently).
4. Ship PR targets the maint branch; `release-post.sh` will **not** open a
   `.99` bump.

## Do not

- Squash-merge a ship PR (tag would not be the PR head you reviewed).
- Tag from the topic branch before merge.
- Force-push `master` / `main` / `vX.Y.x`.
- Push `.github/workflows/*` with the App token — operator `git push`.
- Run `nix build .#rbitcoin-musl` on the feature branch as the ship step
  (`release.yml` builds snapshots).
