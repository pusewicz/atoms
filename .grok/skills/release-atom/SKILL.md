---
name: release-atom
description: >
  Cut and publish a single-header atom release (atom_log or another src/<lib>).
  Promotes the changelog, commits, tags atom_<lib>-vX.Y.Z, pushes the tag so
  GitHub Actions publishes the header asset and deploys docs, then bumps VERSION
  for ongoing work. Use when the user runs /release-atom, says "release atom_log",
  "cut a release", "publish the header", or "tag atoms".
argument-hint: "[lib] [patch|minor|major | X.Y.Z]   (default: atom_log, current VERSION)"
---

# Release an atom

You are cutting a **library release** for the **atoms** monorepo
(`pusewicz/atoms`). This is **not** a Space Delivery game release.

Trigger: tag push matching `<lib>-v*` (e.g. `atom_log-v0.1.0`) runs
`.github/workflows/release.yml`, which:

1. Asserts the tag version equals `src/<lib>/VERSION`
2. Builds `dist/<lib>.h` and attaches it to a **GitHub Release**
3. Builds docs and deploys **GitHub Pages**

## Arguments (`$ARGUMENTS`)

Parse whitespace-separated tokens (any order after lib name if present):

| Token | Meaning |
|-------|---------|
| *(empty)* | lib = `atom_log`, version = current `src/<lib>/VERSION` (no bump) |
| `atom_log` (or other `src/*` name) | which library |
| `patch` / `minor` / `major` | bump VERSION **before** cutting (semver) |
| `X.Y.Z` | set VERSION to this exact semver before cutting |

If only a bump or version is given, default lib is `atom_log`.
If only a lib is given, use its current VERSION (must already have Unreleased notes).

## 1. Pre-flight (abort on any failure — report, do not “fix forward”)

```bash
cd "$(git rev-parse --show-toplevel)"
git rev-parse --abbrev-ref HEAD     # expect: main
git status --porcelain              # expect: empty
git fetch origin main --quiet
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

Resolve `LIB` from arguments (default `atom_log`). Confirm:

```bash
test -d "src/${LIB}"
test -f "src/${LIB}/VERSION"
test -f "src/${LIB}/CHANGELOG.md"
```

`## [Unreleased]` in `src/${LIB}/CHANGELOG.md` must contain at least one bullet
(`- …`). If empty, stop: **Nothing to release — [Unreleased] is empty.**

## 2. Resolve version `V`

Read current version from `src/${LIB}/VERSION`.

- If argument is `patch` / `minor` / `major`:
  ```bash
  bundle exec rake "version:${LIB}:bump[patch]"   # or minor/major
  ```
  Re-read `VERSION` → `V`.
- If argument is explicit `X.Y.Z`: write that line to `src/${LIB}/VERSION` (must
  be three non-negative integers; should be ≥ current — if lower, stop and ask).
- Else: `V` = current VERSION as-is.

Tag name: **`${LIB}-v${V}`** (e.g. `atom_log-v0.1.0`).

Collision checks (must all fail / be empty):

```bash
git rev-parse -q --verify "refs/tags/${LIB}-v${V}"
git ls-remote --exit-code --tags origin "refs/tags/${LIB}-v${V}"
```

If the tag already exists, stop and report.

## 3. Confirm with the user (required gate)

Show a short plan and **wait for approval** before mutating git history:

- Library: `LIB`
- Version: `V`
- Tag: `LIB-vV`
- That you will: promote changelog → commit → tag → push `main` + tag →
  `bump_next` → commit VERSION bump → push `main`
- Link pattern after success:
  - Release: `https://github.com/pusewicz/atoms/releases/tag/LIB-vV`
  - Docs: `https://pusewicz.github.io/atoms/`

Do **not** proceed without explicit yes.

## 4. Cut release files (working tree)

```bash
bundle exec rake "release:${LIB}"
```

This promotes `[Unreleased]` → `## [V] - YYYY-MM-DD` and runs `dist:${LIB}`.
`VERSION` stays `V`.

If rake fails (empty Unreleased, duplicate section, etc.), stop and report.

## 5. Commit release

```bash
git add "src/${LIB}/CHANGELOG.md" "src/${LIB}/VERSION" dist/   # dist is gitignored; omit if clean
git status
# Prefer only changelog (and VERSION if bumped earlier):
git add "src/${LIB}/CHANGELOG.md"
# If version was bumped in step 2 and not yet committed:
git add "src/${LIB}/VERSION"
git commit -m "Release ${LIB} v${V}"
```

Do not commit `dist/` or `build/` (gitignored). Do not amend unless the user
explicitly asks and HEAD was created by you and not pushed.

## 6. Tag and push (triggers CI)

```bash
git tag -a "${LIB}-v${V}" -m "${LIB} v${V}"
git push origin main
git push origin "${LIB}-v${V}"
```

Watch the workflow:

```bash
gh run list --workflow=release.yml --limit 3
gh run watch   # if a run id is available, or open the URL from list
```

Report success only after the **Release** workflow is green (or paste the run URL
and note if still in progress). On failure, do **not** run `bump_next`; help
debug the failed job.

## 7. Post-release development bump

Only after the tag is pushed (workflow can still be running):

```bash
bundle exec rake "release:${LIB}:bump_next"   # V → next patch
git add "src/${LIB}/VERSION"
git commit -m "Bump ${LIB} to $(tr -d '[:space:]' < src/${LIB}/VERSION) for development"
git push origin main
```

## 8. Summary for the user

- Tag `LIB-vV`
- Release URL (assets: `LIB.h`)
- Docs deploy (Pages) when the release job finishes
- New in-progress VERSION after `bump_next`
- Remind: consumers install via
  `https://github.com/pusewicz/atoms/releases/download/LIB-vV/LIB.h`

## Hard rules

- **Never** push a tag whose version ≠ `src/${LIB}/VERSION` at that commit.
- **Never** force-push tags or rewrite published release commits.
- **Never** release from a dirty tree or a branch other than `main` unless the
  user explicitly overrides after you warn them.
- Prefer `bundle exec rake` over bare `rake`.
- One library per invocation; re-run the skill for another atom.
