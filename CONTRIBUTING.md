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

## Which issues to pick up

**Only take issues labelled `Ready To Work`.**

That label means the issue has been submitted, reviewed, refined, and is
genuinely going to be worked on. Anything without it may still be closed as a
duplicate, or as something this project is not going to do — and there is
nothing worse than finishing work on an issue that was never going to be
accepted.

The three labels that track where an issue is:

| Label | Meaning |
| --- | --- |
| `Ready To Work` | Refined and accepted. Free to claim. |
| `Working` | Claimed and assigned. Someone is on it. |
| `Ready And Waiting` | Done, with an approved pull request, waiting for a release branch. |

An issue with none of these has not been triaged yet. You are welcome to
comment on it, but do not start building.

## Claiming an issue

**Comment on the issue** saying you would like to take it. That is all.

GitHub does not let you assign yourself without write access, so a comment is
the claim. Once you have commented, a maintainer can assign the issue to you
and set it to `Working`.

**You will not be able to change the labels yourself.** Editing labels needs
triage permission on the repository, which being an assignee does not grant.
That is GitHub's rule rather than a lack of trust — a maintainer moves the
issue through the labels, so you never have to think about it.

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

### 4. Update the documentation

**If your change alters what a user does or sees, update the page that says
so — in the same pull request.**

The project is fully documented, so there is almost always an existing page
rather than a new one to write. Find it on the
[documentation site](https://vulps22.github.io/somnilux/) and edit the
matching file under `docs/`:

| You changed | Page |
| --- | --- |
| A flag on `install.sh` | `docs/install/options.md` |
| What the installer asks or does | `docs/install/installing.md` |
| Launch behaviour, runtimes, video | `docs/run/` |
| A new failure users can hit | `docs/troubleshooting/common-failures.md` |
| A limitation you could not fix | `docs/troubleshooting/known-issues.md` |
| How the project is built or released | `docs/contributing/` |

`mkdocs build --strict` must pass. It fails on a link to a missing page *or*
to a heading that no longer exists, so it catches most mistakes for you.

**When you do not need to touch the docs:** a fix that restores behaviour the
docs already describe, an internal refactor, or a developer tool nobody
installs. If the documentation was already true and still is, leave it alone.

Write for someone using Somnilux, not someone reviewing your patch — what to
do, not what you changed.

**Documentation is never held against you.** Awkwardly worded, in the wrong
place, or forgotten entirely — it gets listed as a to-do on the pull request,
talked through, and fixed. It is not a mark against your work and it is not a
reason your change gets turned away. Prose is the cheapest thing in this
project to correct.

**Ask if you are not sure.** Maintainers are happy to guide and discuss where
documentation does and does not need adjusting, in the pull request comments.
"Does this need a docs change?" is a perfectly good question to open with, and
a better use of everyone's time than guessing.

Documentation publishes when a release reaches `main`, so your page goes live
at the same moment your change does.


### 5. Regenerate the patches — Wine changes only

If you changed the Wine source, regenerate `patches/` with `git format-patch`
so the shipped patches match what the binaries were built from, and update
`patches/BASE_COMMIT.txt` if the base moved.

Skip this entirely for script or documentation changes.

### 6. Open a pull request

**Target `main` unless the issue names a branch to use instead.**

You do not need to know anything about how releases are structured. If your
work needs to land somewhere other than `main`, a maintainer will change the
target for you — that is a single action on their side and requires nothing
from you. Do not close and reopen a pull request to change its target.

Say what you changed, why, and how you tested it. Reference the issue with
`GH-16`, without a closing keyword.

## Using an AI assistant

**Use one if you want to. Nobody is going to think less of you for it, and
there is nothing to hide.**

Every pull request here gets reviewed by Claude as well as by a human, so an
assistant is already part of the process on this side. Running your own over
your work first is sensible, not suspect.

The bar is the same either way: **you understand what you are submitting and
can answer questions about it.** That is the only thing being asked. Code you
cannot explain is a problem whether a model wrote it or you did at 3am.

Two things worth knowing, neither of them a rule:

- Wine's behaviour is badly represented in training data, and models will
  invent plausible-sounding APIs and flags that do not exist. Read the actual
  Wine source; it is right there and it is the only reliable answer.
- The house style is light on comments and prose. Assistants tend to be
  generous with both. Trimming is expected and is not a criticism.


## Review

A maintainer reviews it, and so does Claude. Expect questions — they are
about understanding the change, not about doubting you.
change, not about doubting you.

### After approval, expect a wait

**Approved does not mean merged.** Approval means your work is accepted; it is
merged when a release is put together, which may be days or weeks later. The
issue is labelled `Ready And Waiting` at this point, so you can see the
difference between "still being looked at" and "done, queued for a release".

Releases are batched on purpose. If every fix shipped the moment it was
approved, users would get an update notice for a logging flag on Monday, a
Twitch fix on Tuesday and an audio fix on Wednesday, and would quite
reasonably start ignoring them. Batching is what keeps the notice worth
reading.

So a pull request of yours sitting approved and untouched is the system
working, not you being forgotten. Ask on the issue any time if you want to
know where it is in the queue.

Occasionally an approved pull request is pulled back out of a release — if
`main` has moved and it no longer merges cleanly, it is dropped to the next
release rather than resolved in a hurry. You will be told on the pull request
if that happens. It is not a rejection.


### Where it actually lands

Approved work does not necessarily merge straight to `main`. If it is being
grouped with other changes for a release, a maintainer cuts a release branch
at that point and retargets your pull request onto it. Release branches are
created when there is something to put in them, not in advance, which is why
there may be none to target when you open.

Either way this is handled for you, and the only visible difference is which
branch the merge button says.

### When your issue closes

**When the work reaches `main`** — which may be some time after your pull
request is merged, if it landed on a release branch first.

Your issue staying open after a merge is expected, not an oversight. Nobody
has forgotten it.


## Why a PR gets rejected

Most of these are a quick fix rather than a closed door.

**Sent back for a fix**

- Branch name does not match the format
- Commit messages do not match the format
- Closing keywords in a commit message or the pull request description
- Closed and reopened to change the target branch, instead of asking
- **Regression commits.** A commit that adds something and a later commit that
  removes it should not both be in the tree — revert or rebase so the mistake
  was never there. History is a record of intent, not of flailing.
- Non-atomic commits, or commits that leave the tree broken
- Unrelated changes bundled in. One issue, one PR
- Patches not regenerated after a Wine source change
- Version constants or `supported/` files changed — those are release-time
  maintainer changes
- Code comments that explain what the code already says
- `mkdocs build --strict` fails
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
