# Archive format

!!! info "Maintainer reference"
    Contributing a change? Start with
    [CONTRIBUTING.md](https://github.com/Vulps22/somnilux/blob/main/CONTRIBUTING.md).
    This page documents how the project is built and released.

The installer script and the patched binaries are released separately, so any
version of the script can meet any published archive. The format number is
what stops an old script installing an archive it doesn't understand.

## The problem it solves

`supported/dlls.txt` named one binary release, and nothing recorded which
installers could actually use it. If a future archive changed shape — a new
top-level directory, a different archive type, an extra step the old code
doesn't perform — an old installer would happily download it and install it
wrongly.

## The scheme

`install.sh` declares `ARCHIVE_FORMAT` (currently **2**). `supported/compat.txt`
holds one `format:tag` line per published binary release:

```
1:wine-11.15
2:somnilux-binaries-build-1
```

The installer takes the newest build whose format matches **exactly**.

!!! warning "Exactly — not 'at least'"
    This is easy to get backwards. A format-2 script cannot run a format-1
    archive any more than it could run a format-4 one that ships `.java`
    files. The number identifies a *shape*, not a minimum version.

## When to bump it

Bump when an installer of the previous number would get the archive **wrong**.

More files inside a directory that already exists is **not** a bump — an older
installer copies the directory and is none the wiser.

A new top-level directory, a different archive type, or a new installation
step the old script doesn't perform all are.

## Four enforcement points

They overlap deliberately: each catches a case the others can't see.

### `compat.txt` — no match

> No compatible fixes found

Nothing is installed. This is a build-time misconfiguration rather than
anything the user did, so it says so and links to the issue tracker instead of
installing something arbitrary.

### `compat.txt` — a newer format exists

> Update needed

A notice, then it carries on with the newest build it *can* use. The user gets
a working install.
[`--force-outdated-fixes`](../install/options.md#-force-outdated-fixes) skips
the notice; it's documented for users but deliberately not mentioned in the
dialog itself.

### `archive-format.txt` inside the archive

Checked immediately after extraction, **before a single file is installed**. A
mismatched *or unstamped* archive is refused outright, as is an unknown
top-level directory.

This is the check that catches a hand-fetched or mispublished archive, where
`compat.txt` never came into it.

### `build-artifacts.sh` asks the installer

The build script calls `install.sh --supported-format` rather than holding its
own copy of the number, so the writer and the reader cannot drift apart.

That flag does `trap - EXIT` before printing: the EXIT trap restores the
terminal by writing escapes to stdout, which would otherwise corrupt output
being parsed by another program.

## Keeping `compat.txt` honest

`.github/workflows/record-archive-format.yml` maintains it automatically.

On `release: published` it looks for a `somnilux-binaries.tar.gz` asset, and
if there is one, downloads it, reads `archive-format.txt` **from inside**, and
appends `format:tag` to `compat.txt` on `main`.

Three details that are load-bearing:

- **`published`, not `released`.** The `released` event never fires for
  prereleases, and binary builds go out as prereleases.
- **Reads the number from the archive, not the tag.** The recorded line
  therefore cannot disagree with what actually shipped.
- **Appends rather than replaces.** The file is a record of which installers
  can still be served, not just the newest.

A `concurrency` group serialises it so two releases can't race the push.

The workflow only runs for releases published after it landed on `main` —
which is why `1:wine-11.15` was written by hand.

## The ordering constraint

`SUPPORTED_BASE_URL` reads from `main`, so the order in which you publish
matters. See [Release process](release-process.md) — getting it wrong makes a
correct installer refuse to install anything.
