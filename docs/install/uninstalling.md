# Uninstalling

Somnilux doesn't need `sudo` to install and doesn't need it to remove. Nothing
is installed system-wide, no packages are touched, and no system files are
modified — removing it is a matter of deleting directories.

!!! tip "Try repair first"
    If something is broken rather than unwanted, repairing is faster and keeps
    your Somnium install and settings — see
    [Installing](installing.md#repairing-an-existing-install).

## What to remove

### 1. Somnilux's own directory

```sh
rm -rf ~/.local/share/somnilux
```

This holds the vendored `umu-run`, the generated `launch.sh`, `launch.log`,
the converted icon, the remembered paths, and your `openxr.conf` if you made
one. Removing it undoes Somnilux itself.

### 2. The desktop entry

```sh
rm -f ~/.local/share/applications/somnium-space.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null
```

Some desktops cache the menu; log out and back in if the entry lingers.

### 3. The patched Proton copy

A sibling of your install location, named for the Proton version with a
`-somnilux` suffix. With the default install location that's:

```sh
rm -rf ~/Games/umu/GE-Proton*-somnilux
```

This is the largest item, typically a few gigabytes. It's a private copy that
only Somnilux ever used.

!!! warning "Check the name before deleting"
    Only directories ending in `-somnilux` were created by this project. Your
    Steam Proton installs live under
    `~/.local/share/Steam/compatibilitytools.d/` and are never touched by
    Somnilux — don't delete those.

### 4. The Wine prefix

```sh
rm -rf ~/Games/umu/umu-somnium
```

**This deletes Somnium Space itself**, along with anything stored inside the
prefix — client settings, cached world data, and Somnium's own logs. You'll
re-download and re-install Somnium if you come back.

Keep this directory if you might reinstall Somnilux later. A future install
can reuse an existing prefix.

If you chose a different install location, the paths in steps 3 and 4 differ.
Somnilux remembers where it put things, so check before deleting:

```sh
cat ~/.local/share/somnilux/paths.conf
```

Read that **before** step 1, since step 1 deletes it.

## What is never touched

For reassurance, none of the following are modified at any point, and none
need cleaning up:

- Your system Wine, if you have one
- Your Steam installation, or anything in `compatibilitytools.d/`
- System packages, `/usr`, `/etc`, or anything outside your home directory
  and your chosen install location
- Your OpenXR runtime and its configuration

## Starting over

To reinstall cleanly after a failed or unwanted install, remove items 1–3 and
keep or delete the prefix depending on whether you want to keep Somnium
itself. Then run the installer again and choose **Install Somnium Space**.
