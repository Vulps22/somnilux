# Updating

Somnilux never updates itself. Starting Somnium will *tell* you when something
newer exists, but downloading and installing it is always something you do
deliberately, by running the installer again.

## The update notice

When you start Somnium, the launch script checks whether a newer Somnilux has
been published. If one has, it says so in the launch window and waits ten
seconds before carrying on — press ++enter++ to skip the wait.

Nothing is downloaded and nothing is changed. The notice is purely
informational, and Somnium starts normally either way.

If you're offline the check stays quiet and the launch proceeds as usual.

## Two different things can be newer

It's worth knowing which one the notice means, because they're updated
differently.

**The installer script** is versioned `major.minor` and released as
`install.sh`. A new script release is needed when the installer itself gained
something — a new step, a fix, support for a new archive layout.

**The patched binaries** are published separately, as their own release. New
fixes can ship without a new script, and your existing installer will pick
them up on its next run.

That separation is why "update" usually just means *run the installer again
and choose repair* — see [Installing](installing.md#repairing-an-existing-install).
The recommended Proton and Wine versions are fetched live too, so those can
move without a new script release as well.

## Updating

```sh
curl -LO https://github.com/Vulps22/somnilux/releases/latest/download/install.sh
chmod +x install.sh
./install.sh
```

Choose **Repair an existing install**. Your prefix, your Somnium install, and
your settings are left alone; the patched binaries are re-applied, and the
launch script and desktop entry are regenerated.

Always fetch a fresh copy of `install.sh` rather than reusing the one you
downloaded last time — an older script can't install newer fixes, and will
tell you so.

## Reading release tags

Releases are tagged:

```
Somnilux-<Somnilux version>-for-<Somnium Space version verified against>
```

For example, `Somnilux-2.0-for-3.2.5` is Somnilux 2.0, verified working with
Somnium Space 3.2.5.

The Somnium version is the one it was *tested* against, not a hard
requirement — a newer Somnium will usually be fine. But if you're on a newer
Somnium Space and hitting problems, checking whether a newer Somnilux release
exists is the first thing worth doing.

!!! note "Prereleases"
    Test builds go out as GitHub prereleases. The
    `releases/latest/download/install.sh` URL above deliberately skips them,
    so following the normal instructions never lands you on a test build.

## "Update needed"

If the installer says newer fixes exist that it's too old to install, it
carries on with the newest build it *can* use, and you get a working install
either way. Grab the latest `install.sh` when you want the rest.

The notice can be suppressed with
[`--force-outdated-fixes`](options.md#-force-outdated-fixes), which changes
nothing else.
