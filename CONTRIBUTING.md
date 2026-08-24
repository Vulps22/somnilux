# Contributing to Somnilux

Thanks for wanting to help. This document is the process for outside
contributions. It is the authority — the release and build pages on the
[documentation site](https://vulps22.github.io/somnilux/) describe internal
maintainer process and are not a contribution guide.

## Before anything else

**Every change needs an issue.** Branch names carry the issue number, so
there is nowhere for issueless work to go. If what you want to do has no
issue, [open one](https://github.com/Vulps22/somnilux/issues/new/choose)
first — that is not bureaucracy, it is the discussion that stops you building
the wrong thing.

## Claiming an issue

**Comment on the issue** saying you would like to take it. That is all.

GitHub does not let you assign yourself without write access, so a comment is
the claim. Once you have commented, a maintainer can assign the issue to you,
which makes it visible to everyone else that it is taken.

Two things that keep this honest:

- **Claims go stale after 14 days** with no visible progress. If life happens,
  say so on the issue and it stays yours. Silence for two weeks means it is
  open again.
- **Maintainers claim too.** If a maintainer starts work on an issue, they
  comment on it the same way. If nobody has claimed an issue, nobody is
  working on it.

Please do not open a PR for an unclaimed issue without commenting first. It
usually works out, but occasionally two people build the same thing and one of
them wasted an evening.

## Branch naming

```
[issue number]-verb-action-performed
```

Examples:

```
16-add-verbose-logging
23-fix-runtime-detection-on-wayland
```

Rules:

- Starts with the issue number, then a hyphen
- Starts with a **verb** — an instruction or goal, not a noun phrase.
  `16-add-verbose-logging`, never `16-verbose-logging`
- Lowercase, hyphen-separated

**Branches with the wrong name will be rejected.** It is a rename and a
force-push, not a rewrite, so it costs you a minute — but it will be asked
for.

Branches are never deleted in this project, including after a clean merge.

## Commit messages

```
GH-16 Add verbose logging to the launch script
```

The issue reference, then an imperative description of what that commit does.

**Use `GH-16`, not `#16`.** Both link the issue and both create a reference on
its timeline, but a leading `#` is a comment character in git — running
`git commit` and typing `#16 ...` in the editor silently discards the line.
`GH-` is GitHub's own equivalent and has no such problem.

Every commit must be **atomic and complete on its own** — the tree builds and
runs at every commit, not just at the end of the branch.

### Never use closing keywords

Do not write `fixes`, `closes` or `resolves` (or `fix`/`close`/`resolve`,
`fixed`/`closed`/`resolved`) immediately before an issue reference, in a
commit message or a pull request description.

Those close the issue automatically. **An issue is not closed until the work
reaches `main`**, which happens when a release branch is merged — not when
your pull request is approved, and not when it lands on a release branch.

Reference the issue, do not resolve it:

```
GH-16 Add verbose logging to the launch script     correct
Fixes GH-16: add verbose logging                   closes the issue early
```

Putting the reference first makes this hard to trigger by accident, but it is
worth knowing why.


## Doing the work

### 1. Fork the repository

Work on your fork. You do not need write access to anything here.

### 2. Make the change

Match the surrounding code. Two project conventions that catch people out:

- **Write zero code comments** unless something is genuinely obscure. If you
  feel the need to explain, ask on the issue instead — the answer usually
  belongs in the commit message or the docs.
- **Never modify, patch, or bypass anything belonging to Somnium Space.**
  Reading Somnium's behaviour to find a Wine bug is fine and is how most of
  this project happened. Changing Somnium's binaries, or working around its
  verification, is not, and such a PR will be closed.

### 3. Test it

**All changes:** run the thing you changed and say in the PR what you did.

**Changes to `install.sh` or `launch.sh`:** run a real install or launch.
State your distribution, desktop and OpenXR runtime.

**Changes to the Wine patches only:** build them and install them locally.

```sh
./scripts/build-artifacts.sh
./scripts/install.sh --use-local-dlls-at ./somnilux-binaries.tar.gz
```

Then launch Somnium and check its own logs report no errors and no maintenance
mode. See
[Testing a build](https://vulps22.github.io/somnilux/contributing/testing/).

**Changes to `docs/`:** `mkdocs build --strict` must pass.

If a step does not apply to your change, skip it — nobody needs to build DLLs
to fix a typo.

### 4. Regenerate the patches — Wine changes only

If you changed the Wine source, regenerate `patches/` with `git format-patch`
so the shipped patches match what the binaries were built from, and update
`patches/BASE_COMMIT.txt` if the base moved.

Skip this entirely for script or documentation changes.

### 5. Open a pull request

**Target the active release branch, not `main`.** A maintainer will tell you
which one on the issue; ask there if it is not obvious.

Say what you changed, why, and how you tested it. Reference the issue with
`GH-16`, without a closing keyword.

## Review

A maintainer reviews it. Expect questions — they are about understanding the
change, not about doubting you.

Approved work merges into the release branch. Nothing reaches `main` except a
release branch merge, and that is when the issue closes — so your issue
staying open after your pull request is merged is expected, not an oversight.


## Why a PR gets rejected

Most of these are a quick fix rather than a closed door.

**Sent back for a fix**

- Branch name does not match the format
- Commit messages do not match the format
- Closing keywords in a commit message or the pull request description
- Targets `main` instead of the active release branch
- **Regression commits.** A commit that adds something and a later commit that
  removes it should not both be in the tree — revert or rebase so the mistake
  was never there. History is a record of intent, not of flailing.
- Non-atomic commits, or commits that leave the tree broken
- Unrelated changes bundled in. One issue, one PR
- Patches not regenerated after a Wine source change
- Version constants or `supported/` files changed — those are release-time
  maintainer changes
- Code comments that explain what the code already says
- `mkdocs build --strict` fails on a docs change
- No statement of how it was tested

**Closed**

- Modifies, patches, or bypasses Somnium's own binaries or verification
- Deletes branches, or force-pushes over `main`
- Redistributes anything belonging to Somnium Space
- Adds a dependency the installer would need at runtime, without discussing it
  on the issue first — the whole point of vendoring `umu-run` was removing
  those

## Licensing

Scripts and documentation are MIT. The Wine patches are LGPL-2.1, being
modifications to Wine. By contributing you agree your work is released under
the licence covering the part of the project you touched.

## Questions

Ask on the issue, or find me on Discord as `@vulps22`.
