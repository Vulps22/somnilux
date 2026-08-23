# Restarting

Starting Somnium while it's **already running** stops the previous session
first, then starts a clean one.

This is the fix for a stuck launcher. A hung Somnium leaves a `wineserver`
holding the prefix, and every later start then hangs silently with no window
and no error. Rather than leaving you to find and kill processes by hand,
Somnilux clears the old session for you.

## It asks first

Restarting applies to a **healthy** session too — if Somnium is up and working
and you launch it again, continuing will close it and start over. So it
checks:

- **In the launch window**, it counts down ten seconds. Press ++ctrl+c++ to
  cancel, or ++enter++ to go immediately.
- **If no terminal could be opened**, a graphical dialog appears instead. If
  nothing answers it within thirty seconds it goes ahead, on the assumption
  that you launched it precisely because the old session was stuck.

## Only your Somnium session is stopped

Only processes belonging to **this Somnilux prefix** are stopped. Other Wine
or Proton games running at the same time are left alone, as is anything else
using Wine on your system.

## Closing Somnium normally

Quit from inside the client, or close the launcher window.

If you left **"minimize to taskbar"** enabled in the Launcher's settings, the
window can vanish without closing — Wine has no system tray for it to minimize
into. The install walkthrough suggests turning that off for exactly this
reason. If it's already happened, simply launch Somnium again and let the
restart prompt clear the stuck session.

## If a launch still hangs

If Somnium won't start even after a restart:

1. Check [`launch.log`](../troubleshooting/launch-log.md) — it's written
   fresh on every attempt.
2. Log out and back in, which clears anything holding the prefix.
3. See [Common failures](../troubleshooting/common-failures.md).
