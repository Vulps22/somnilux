# Installer options

`install.sh` is interactive and needs no arguments — running it with none is
the normal path. The flags below exist for specific situations.

```
install.sh [options]
```

Run `./install.sh --help` at any time for the same list.

## `--force-outdated-fixes`

Skip the **"Update needed"** warning shown when newer patched binaries have
been published than this installer knows how to install.

The patched Wine binaries are published separately from the script, and each
release of the script can only install builds laid out the way it expects (see
[Archive format](../contributing/archive-format.md)). When newer builds exist
that this script is too old to use, it says so and then carries on with the
newest build it *can* use.

That notice is worth reading the first time. If you're deliberately staying on
an older installer and don't want to see it on every run, this flag suppresses
it. It changes nothing else — the same binaries are installed either way.

!!! note
    This does **not** let an old installer use a newer build. Nothing can; the
    layouts genuinely differ. It only hides the notice.

## `--use-local-dlls-at <archive>`

Install the patched binaries from a local `.tar.gz` instead of downloading
them from the GitHub release.

```sh
./install.sh --use-local-dlls-at ./somnilux-binaries.tar.gz
```

The archive is the one produced by `scripts/build-artifacts.sh`, laid out by
destination:

| In the archive      | Installed into                |
| ------------------- | ----------------------------- |
| `x86_64-unix/`      | `files/lib/wine/x86_64-unix/` |
| `x86_64-windows/`   | `files/lib/wine/x86_64-windows/` |
| `x86_64-linux-gnu/` | `files/lib/x86_64-linux-gnu/` |

Everything else about the install is unchanged. This is for testing a build
before it's released — see [Testing a build](../contributing/testing.md).

## `-v`, `--version`

Print the installer's version as `major.minor` and exit.

```console
$ ./install.sh --version
3.1
```

The release workflow reads this from the published script, so
`supported/script.txt` can't disagree with what actually shipped.

## `--supported-format`

Print the archive format number this installer can install, and exit.

```console
$ ./install.sh --supported-format
2
```

Used by `scripts/build-artifacts.sh` so the number lives in exactly one place
and the writer and reader can't drift apart. You're unlikely to need it
directly.

## `-h`, `--help`

Print the usage summary and exit.
