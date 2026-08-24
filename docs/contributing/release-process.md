# Release process

!!! info "This is internal maintainer process"
    Releases are cut by maintainers. If you are contributing a change, none of
    this applies to you — follow
    [CONTRIBUTING.md](https://github.com/Vulps22/somnilux/blob/main/CONTRIBUTING.md)
    instead, which covers claiming an issue, branch and commit naming, testing,
    and opening a pull request.

    This page is here so the process is written down rather than remembered.

Three things ship independently — the installer script, the patched binaries,
and the `supported/` metadata on `main`.

## Versioning

The version's job is the update notice. `SCRIPT_VERSION` feeds
`supported/script.txt`, and every launch checks it. So the bump rule follows
what a user has to *do* about it.

**Major — an existing user must act.** They have to reinstall, upgrade
something on their system, or their current install stops receiving fixes.

**Minor — they benefit from updating, but nothing breaks if they don't.**

A **format bump is always major**, because an older installer can no longer
use new binaries. The reverse doesn't hold: 2.0 was vendoring `umu-run`, with
no format change, and was major because installs on some distributions were
silently broken until reinstalled.

Other things that make a release major: changing the prefix or Proton
directory layout, raising the Python floor, dropping a supported Proton
version, changing the desktop entry name.

## How work accumulates

**Approved pull requests are not merged straight away.** They sit approved,
targeting `main`, until a release is assembled.

This is deliberate. Releasing every fix as it lands would mean an update
notice for `--verbose`, then another the next day for a Twitch fix, then
another for RTSP audio — and users would reasonably start ignoring them, or
want them turned off. Batching keeps the notice meaningful.

**What triggers a release is judgement**, plus maintainer availability. There
is no cadence. Grouping issues by relationship — via milestones, decided at
refinement — is a possible future refinement, but with no outside contributors
yet, eyeballing the pile is enough.

!!! warning "Say so, on the pull request"
    An approved pull request that then sits for three weeks looks, from the
    outside, exactly like being ignored. Approval means accepted; merging
    happens when a release is put together. Contributors are told this in
    CONTRIBUTING.md, but it is worth repeating on the PR itself.

## Cutting a release branch

**Cut the branch when the work is already done**, not before. The pile is
approved and ready; its contents decide which kind of release this is, and
therefore the branch name.

| Payload | Branch |
| --- | --- |
| Binaries only | `release-binaries-build-4` |
| Script only | `release-somnilux-3-2` |
| Both | `release-somnilux-3-2-binaries-build-4` |

The name says what to publish, and in what order. Because the branch is cut
immediately before release, the build number is already known.

Then retarget the waiting pull requests onto it and merge them. Retargeting is
one action per PR and requires nothing from the contributor.

Release branches are **exempt from the verb-first branch naming rule** — they
are noun phrases by nature.

## Pull requests arriving mid-release

Once a release branch is open, new work is triaged:

- **Urgent** — merge into the current release branch
- **Everything else** — schedule for the next release

The calibration line: a client crash is urgent, 1080p YouTube is not.

## Urgent fixes

An urgent fix **triggers a release of whatever is already waiting**. It does
not go out alone, and the stockpile does not delay it.

!!! danger "Anything with a merge problem is dropped, not fixed"
    If a waiting pull request has developed conflicts since it was approved,
    it comes **out** of the release and is investigated for the next one.

    Do not stop to resolve conflicts. The urgent fix is the priority, and a
    conflict found under time pressure is exactly when a bad merge gets made.
    Dropping it costs one release cycle; a rushed resolution can cost the fix.

Tell the contributor on the PR that it was pulled and why — it is not a
rejection, and it is the second time their work has visibly not moved.

## Combining two release branches

Rare, but it happens: a release branch is open and being tested when work
arrives that needs both a script and a binaries release.

Cut a new combined branch from `main`, merge the open release branch into it
at whatever its current HEAD is, then add the new work.

There is no need to hurry the open branch to a stopping point. Every commit is
atomic and complete on its own, so any point on it is already shippable —
anything unfinished simply is not committed yet.

## The ordering constraint

!!! danger "Main, then the archive, then the installer"
    `SUPPORTED_BASE_URL` reads `supported/` from **`main`**, live, on every
    installer run. Published in any other order, a correct installer finds no
    matching line in `compat.txt` and correctly refuses to install anything.

1. **Merge to `main` first.** This lands `compat.txt`, the workflows, and any
   changed version files. Nothing takes effect until it's on `main`.
2. **Publish the binary archive.** The `record-archive-format` workflow fires
   on `release: published`, reads `archive-format.txt` from inside the
   archive, and appends its `format:tag` line to `compat.txt`.
3. **Release the installer script.** Only now can it find a compatible entry.

The workflow only runs for releases published *after* it is on `main` — which
is the same constraint stated a different way.


## Tag naming

```
Somnilux-<Somnilux version>-for-<Somnium version verified against>
```

For example `Somnilux-2.0-for-3.2.5`. Binary releases are tagged separately;
`compat.txt` refers to them by tag.

## Prereleases

Test builds go out as GitHub **prereleases**. This matters more than it looks:
`releases/latest/download/...` skips prereleases entirely, which is what keeps
a beta away from existing users while it's being tested.

It's also why the `record-archive-format` workflow triggers on `published`
rather than `released` — `released` never fires for a prerelease.

## Before publishing

- **`UMU_VERSION` and `UMU_SHA256` must be bumped in the same commit.** A pin
  changed without its checksum is a broken install.
- **Release notes hardcode their own tag** in the download URL, so that string
  needs updating for each release.
- **Run the smoke test.** See [Testing a build](testing.md).
- **Check `supported/script.txt`** matches what's shipping. The release
  workflow reads the version from the published script itself, so the two
  can't silently disagree — but the file still has to be right.

## After publishing

Verify the served script byte-for-byte:

```sh
curl -sL https://github.com/Vulps22/somnilux/releases/latest/download/install.sh \
  | diff - scripts/install.sh && echo "identical"
```

Then confirm the workflow appended the expected line to `compat.txt` on
`main`.

## Never publish unasked

**Building, committing and pushing are fine. Creating, editing or deleting a
GitHub release is not.** Permission for one release does not carry to the
next.

Build it, commit, push, then say what's ready and wait to be asked for that
specific release by name.

## Branches

Branches are **never deleted**, even after a clean merge.

- Name a branch as an instruction or goal — `add-rtspt-support`, not
  `rtsp-support`
- Feature branches never merge into each other. If one needs another's work,
  that's a structural signal: cut a release branch off `main` and merge both
  into that
- Keep every commit atomic and complete on its own
