# Distribution notes

Somnilux avoids depending on distribution packaging wherever it can — it
downloads its own GE-Proton and its own `umu-run`, and needs no system Wine,
no Steam, and no `sudo`. What's left is a short list of things that do vary.

## Tested distributions

✅ confirmed · ⚠️ untested · ❌ known broken

| Distribution | Status | Notes |
| --- | --- | --- |
| CachyOS | ✅ | CachyOS needs some tweaks, see them [here](../distros/cachyos.md) |
| Linux Mint | ✅ | |
| Nobara 44 | ✅ | |
| Arch Linux | ⚠️ | |
| Bazzite | ⚠️ | |
| Debian | ⚠️ | |
| Fedora | ⚠️ | |
| Manjaro | ⚠️ | |
| openSUSE | ⚠️ | |
| Pop!_OS | ⚠️ | |
| Ubuntu | ⚠️ | |

Untested means nobody has reported back, not that it's broken. If you get
Somnilux working on something in that list or on something not listed at all,
please [say so](reporting.md) — the table only grows from reports.

## Package names that differ

`whiptail` is optional but recommended, and it's packaged under three
different names:

| Distribution | Command |
| --- | --- |
| Debian, Ubuntu, Mint | `sudo apt install whiptail` |
| Fedora, Nobara | `sudo dnf install newt` |
| Arch, Manjaro | `sudo pacman -S libnewt` |

Without it the installer falls back to plain text prompts. They work, but the
guided path is better tested.

## Python version

The vendored `umu-run` requires **Python 3.10 or newer**, checked before
anything is downloaded.

This rules out older long-term-support releases still shipping Python 3.8 or
3.9. Installing a newer Python alongside the system one generally doesn't
help — it has to be what `python3` resolves to on your `PATH`.

## ImageMagick and the desktop icon

The installer converts Somnium's own `.ico` into a PNG for the desktop entry,
using ImageMagick if it's present. Both spellings are handled:

- `magick` — ImageMagick 7, on most current distributions
- `convert` — ImageMagick 6, still current on Debian and Mint

If neither is installed the entry is created **without** an icon. Everything
works; it just looks plain. Install ImageMagick and run a repair if you want
the icon.

## Immutable and atomic distributions

Bazzite, Silverblue and similar are untested. Nothing Somnilux does needs to
write outside your home directory or your chosen install location, so there's
no obvious reason for them to fail — but "no obvious reason" isn't a report.
If you try one, please let me know either way.

## Flatpak OpenXR runtimes

System-wide Flatpak runtimes have their install directory shared into the
container automatically, as do `/opt` installs. Per-user Flatpaks under your
home directory need nothing extra.

If yours needs more, [`openxr.conf`](../run/vr-runtimes.md#when-automatic-detection-isnt-enough)
is the escape hatch — and worth reporting, since detection should usually be
handling it.
