# Reporting a problem

[**Open an issue →**](https://github.com/Vulps22/somnilux/issues/new/choose)

Or find me on Discord as **`@vulps22`** if an issue feels like too much
ceremony.

## Before you report

Worth a minute each, and they resolve a good share of reports:

1. **Check [Common failures](common-failures.md)** for your symptom.
2. **Check [Known issues](known-issues.md)** — it might be something already
   understood.
3. **Try a repair.** Run the installer, choose repair. It re-applies the
   patched binaries and regenerates the launch script, and fixes a lot.
4. **Grab your `launch.log` before relaunching** — it's overwritten every
   launch.

None of these are prerequisites. A report with nothing but "it doesn't start"
is still better than no report.

## Which template

**Bug report** — something isn't working. The only required fields are your
Somnilux version and distribution.

**Compatibility report** — whether Somnilux works on your setup. **Good news
is wanted here.** "It just worked" is a genuinely useful report, and the
[distribution](distributions.md) and [runtime](../run/vr-runtimes.md) tables
are built entirely from these. Please don't skip it because nothing went
wrong.

**Something else** — questions, suggestions, anything that isn't the above.

Blank issues are disabled, but every field is free text. Nothing has to match
a fixed list — Linux has far too much variation to enumerate, so describe your
setup however you'd describe it.

## What to include

The most useful attachment by a distance:

```
~/.local/share/somnilux/launch.log
```

Attach it **in full**. It's usually under a hundred lines, and the useful part
is often where the log stops rather than the scariest-looking line — which is
hard to judge when you're only sent an excerpt.

Please don't strip out Wine's `fixme:` and `err:` lines. A `fixme:` means Wine
hasn't implemented something Somnium asked for, and that's how every gap
Somnilux fixes was found in the first place — see
[`fixme:` lines](launch-log.md#fixme-lines-please-do-report-these).

Alongside it:

- **Somnilux version** — `./install.sh --version`, or the release you
  installed from
- **Distribution and version** — `Nobara 44`, `Linux Mint 22`
- **GPU and driver** — `AMD RX 7900 XTX, Mesa 25.1`
- **OpenXR runtime and headset** — `WiVRn (Flatpak), Quest 3`
- **Somnium Space version**, if you know it
- **What you expected, and what happened instead**

For an **install** failure, the installer's own log rather than the launch
log:

```
${XDG_RUNTIME_DIR:-/tmp}/somnilux-<your uid>-debug.log
```

For a launcher that starts but won't connect,
[Somnium's own logs](launch-log.md#somniums-own-logs) are the ones that carry
the real reason.

## Before you paste

`launch.log` contains your home directory path and install paths. If your
username is something you'd rather not publish, replace it throughout.
Nothing else in the file is sensitive — no tokens, no credentials.

Somnium's own logs are more variable. Skim them before pasting.

## Reporting a Somnium bug, not a Somnilux one

If something is broken inside Somnium Space in a way unrelated to running on
Linux, Somnium's own support channels are the right place — they can act on
it, and I can't.

If you're not sure which it is, report it here anyway. Working out which side
a fault sits on is exactly the sort of thing worth doing together, and a
misfiled report costs nothing.
