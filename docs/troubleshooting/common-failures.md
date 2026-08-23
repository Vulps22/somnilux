# Common failures

Symptom first. If yours isn't here,
[reading launch.log](launch-log.md) is the next step.

## Nothing happens when I click the menu entry

The single most common report, and it's almost always visible in the log:

```sh
cat ~/.local/share/somnilux/launch.log
```

If the file doesn't exist at all, the desktop entry isn't running the launch
script — regenerate it by running the installer and choosing **repair**.

If it exists but is empty or stops in the first few lines, see
[When it goes wrong](launch-log.md#when-it-goes-wrong).

A launch can also be waiting on the [restart prompt](../run/restarting.md) in
a terminal window that never opened. It resolves itself after thirty seconds.

## `curl | bash` does nothing / skips every prompt

The installer is interactive and needs standard input, which piping consumes.

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

## "No compatible fixes found"

> This installer needs patched binaries in format N, and none are published.

Nothing has been installed, and nothing is wrong with your system — this is a
publishing mistake on my end. Please
[open an issue](https://github.com/Vulps22/somnilux/issues/new/choose).

## "Incompatible fixes"

> These fixes are format N and this installer handles format M.

The binaries you have don't match what this installer knows how to install.
Fetch a fresh `install.sh` from the latest release. If you passed
`--use-local-dlls-at`, the archive is from a different generation of the build
script.

## "Update needed"

> Newer fixes have been published that this installer is too old to install.

Not an error. It carries on with the newest build it can use, and you get a
working install. Fetch the latest `install.sh` when you want the rest, or
suppress the notice with
[`--force-outdated-fixes`](../install/options.md#-force-outdated-fixes).

## "Missing dependencies"

The script lists what's absent. You need `curl`, `tar`, and `python3`.

```sh
sudo apt install curl tar python3 whiptail   # Debian/Ubuntu/Mint
sudo dnf install curl tar python3 newt       # Fedora/Nobara
sudo pacman -S curl tar python libnewt       # Arch
```

`whiptail` is optional; the others are not.

## "Python too old"

The vendored `umu-run` needs **Python 3.10 or newer**. On an older
distribution this usually means upgrading the distribution — installing a
newer Python alongside won't help unless it becomes `python3` on your `PATH`.

## "Cannot reach GitHub" / "Could not fetch the list of supported Proton versions"

The installer fetches its version list and compatibility data live. Check your
connection, any proxy, and whether GitHub is reachable:

```sh
curl -sSI https://raw.githubusercontent.com/Vulps22/somnilux/main/supported/default.txt
```

## "Checksum verification failed"

The download was corrupt or truncated. Run the installer again — partial
downloads aren't reused. If it fails repeatedly, a proxy or filtering
middlebox is usually rewriting the file.

## "Somnium Space is running"

The installer can't change files Somnium is using. Close Somnium and try
again. If it says **"Could not close Somnium Space"** and lists processes,
they're stuck — log out and back in, which clears them reliably.

## "No Somnium install found at the default location"

Repair couldn't find an existing install. Enter the path to your **install
location** — the directory you chose during install, which contains
`drive_c`. Not the `drive_c` directory itself, and not the Proton directory.

It's validated: if the Somnium Space Launcher isn't inside, you'll be asked
again rather than allowed to proceed.

## The launcher opens but won't connect or sign in

Wine's side is working; this is Somnium's own layer. Check
[Somnium's own logs](launch-log.md#somniums-own-logs) — a maintenance-mode
notice or an authentication error appears there and nowhere else.

If those show a certificate or TLS failure, the patched binaries aren't
installed or aren't being used. Run the installer and choose **repair**.

## No headset, or the wrong runtime detected

Check the `Detected OXR Runtime:` line in the log. Detection runs at every
launch, so set your runtime active and start Somnium again — no reinstall
needed. See [VR runtimes](../run/vr-runtimes.md), including `openxr.conf` for
runtimes detection doesn't handle on its own.

## The launcher window vanished

If "minimize to taskbar" is enabled in the Launcher's settings, the window
disappears — Wine has no system tray for it to minimize into. Turn that
setting off. To recover now, launch Somnium again and let the
[restart prompt](../run/restarting.md) clear the stuck session.

## A video won't play

See [Video playback](../run/video.md) for what's supported. Twitch and VRCDN
over HTTPS are known not to load; RTSP plays without audio.

## Somnium takes ages to start a YouTube video

Expected, and not a Somnilux fault. Somnium's bundled `yt-dlp.exe` is a
self-unpacking bundle that rebuilds itself on every run under Wine, taking a
few minutes. Give it time.
