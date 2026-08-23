# Release process

Three things ship independently — the installer script, the patched binaries,
and the `supported/` metadata on `main`. They have to go out in the right
order.

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
