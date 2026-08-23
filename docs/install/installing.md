# Installing

The installer is interactive. Run it, answer a handful of questions, and it
builds a working Somnium Space install from scratch — no Steam, no Lutris, no
system-wide Wine configuration.

## Before you start

**Get Somnium Space's own Windows installer** from
[somniumspace.com](https://somniumspace.com) and save it somewhere you can
find again. Somnilux never distributes it for you — it asks you where yours
is and runs it.

!!! tip "Signing up for the first time?"
    Use my referral code **VULPS22-WH22**.

You'll also need:

- `curl`, `tar`, and `python3` **3.10 or newer**
- A GPU driver and OpenXR runtime you can already run other VR titles with
- Roughly 5&nbsp;GB free where you choose to install

`whiptail` is optional but recommended — without it the script falls back to
plain text prompts, which work but are less pleasant and less well tested:

```sh
sudo apt install whiptail    # Debian/Ubuntu/Mint
sudo dnf install newt        # Fedora/Nobara
sudo pacman -S libnewt       # Arch
```

The script checks for the required tools before it does anything and tells you
if one is missing, so you can't get halfway through and stall.

## Getting the script

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

!!! warning "Download it, then run it — don't pipe it"
    `curl ... | bash` does not work. Piping hands the script's standard input
    to `curl`'s output, and the installer needs standard input to ask you
    questions. It will appear to hang or skip past every prompt.

You don't need `sudo`. Everything is installed under your home directory and
wherever you choose to put the game.

## What it asks

### 1. Install or repair

- **Install Somnium Space** — a fresh setup.
- **Repair an existing install** / **Configure an existing installation** —
  see [below](#repairing-an-existing-install).

If you've run the installer before, it remembers where things went and offers
to repair that.

### 2. Where your Somnium installer is

The full path to the `.exe` you downloaded from Somnium Space, for example
`~/Downloads/SomniumSpaceInstaller.exe`. A leading `~` is expanded for you. If
the file isn't there, the script stops immediately rather than continuing into
a broken install.

### 3. Where to install

Defaults to:

```
~/Games/umu/umu-somnium
```

This is the Wine prefix — a self-contained fake Windows drive holding Somnium
and nothing else. Point it at a different disk if you'd rather; a games drive
is a common choice. The patched Proton is placed *beside* it, as a sibling
directory named after the version (for example
`~/Games/umu/GE-Proton11-5-somnilux`), so keep both in mind when picking a
location.

### 4. Which Proton version

A menu of versions this project supports, with one marked **(recommended)**.
Take the recommendation unless you have a reason not to — anything else gets a
warning, because it's untested and may break the launcher. The list is fetched
fresh from the project each run, so it stays current without you needing a
newer script.

## What happens next

Once you've answered, the script works through:

1. **Downloads its own `umu-run`** into `~/.local/share/somnilux/umu/`,
   checksum-verified. It doesn't use or need a system umu-launcher package.
2. **Downloads GE-Proton**, verifies its checksum, and extracts it to that
   `-somnilux` sibling directory. This is a private copy — your Steam
   installs under `compatibilitytools.d/` are never touched.
3. **Installs the patched Wine binaries** over that Proton copy. These are the
   fixes that make Somnium work at all; see
   [What's fixed and why](../understanding/whats-fixed.md).
4. **Creates the prefix and runs Somnium's own installer** inside it. A
   Windows installer window opens — **continue there**. It's Somnium's
   installer, not ours.
5. **Generates the launch script** at `~/.local/share/somnilux/launch.sh`.
6. **Creates the desktop entry**, using Somnium's own icon if ImageMagick is
   available to convert it.

### While Somnium's installer is open

Two things worth doing, which the script also tells you:

- In the Launcher's settings, **turn off "minimize to taskbar"**. Wine has no
  system tray for it to minimize into, so the window can vanish entirely and
  need to be killed manually.
- Windows-style notifications won't work under Wine. Nothing is broken; they
  just don't appear.

## When it's done

You'll get a "Done" dialog, and **Somnium Space** appears in your applications
menu. Launching it opens a terminal window showing what it's doing — see
[The launch window](../run/launch-window.md).

If the menu entry seems to do nothing at all, the answer is almost always in:

```
~/.local/share/somnilux/launch.log
```

## Repairing an existing install

Repair re-applies the patched binaries, regenerates the launch script, and
refreshes the desktop entry. It leaves your prefix and your Somnium install
alone — no re-download of the game, no lost settings.

Reach for it when:

- New fixes have been published and you want them
- A launch stopped working after a system update
- The desktop entry vanished or stopped launching
- An earlier install was interrupted partway through

The script finds your install automatically if it's at the remembered or
default location; otherwise it asks for the path, and validates that the
Somnium Space Launcher is really there before doing anything.

## If something goes wrong

The installer keeps its own debug log, separate from the launch log, and
prints the path if a step fails:

```
${XDG_RUNTIME_DIR:-/tmp}/somnilux-<your uid>-debug.log
```

Installs are staged, so an interrupted run can't leave Proton half-patched.
Running the installer again and choosing repair is a safe way to recover.

See [Common failures](../troubleshooting/common-failures.md) for specific
symptoms, or [Reporting a problem](../troubleshooting/reporting.md) if you're
stuck.
