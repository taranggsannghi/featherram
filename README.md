# FeatherRAM

FeatherRAM is a lightweight live memory monitor for macOS, built to stay fast, quiet, and out of your way.

It shows macOS memory pressure, memory headroom, and the largest process groups. It alerts you when pressure stays high, so you do not need to keep checking it manually.

Created by Tarang Sanghi.

## What You Get

- A live headroom bar and the macOS `NORMAL`, `WARNING`, or `CRITICAL` memory-pressure state.
- A RAM snapshot with separate Free and Standby figures, plus inactive, compressed, wired, and active memory.
- A top-15 process-group preview. Choose **3** to browse every group in the scan, including macOS tasks. Each group shows its memory estimate and process count.
- Auto-refresh every five seconds by default, with an on/off switch and adjustable interval.
- An optional notification after three consecutive `WARNING` or `CRITICAL` scans while auto-refresh is on, with a 30-minute cooldown for repeated alerts at the same pressure level.
- An optional one-time manual file-cache clearing action for diagnostics. Choose **2. Optimise RAM**, enter your Mac password, or press **Escape** to cancel. This runs the existing one-time file-cache clear.

## What It Does Not Do

- It does not delete files.
- It does not empty Trash.
- It does not force quit apps automatically.
- It does not clear cache automatically.
- It does not bypass macOS permissions.

## Usage

Double-click:

```bash
featherram.command
```

For a clickable app, double-click the current `dist/FeatherRAM-<version>.zip` on macOS, move `FeatherRAM.app` to Applications, and double-click it. The source-folder app bundle is build input; the ZIP contains the verified signed build.

Or run from Terminal:

```bash
./featherram.command
```

If a Mac says the file cannot be executed after download, AirDrop, or copying from another computer, run:

```bash
zsh install.sh
zsh run-featherram.sh
```

This repairs executable permissions, clears macOS quarantine when needed, and launches FeatherRAM without depending on Finder metadata.

Show one snapshot:

```bash
./featherram.command --once
```

Show version:

```bash
./featherram.command --version
```

## Settings

**5. Auto-refresh** turns timed scans on or off. This choice is saved across launches in `~/Library/Application Support/FeatherRAM/automatic-monitoring`. When off, pressure alerts also pause; **1. Refresh** still shows a new snapshot. **6. Auto-refresh interval** sets the scan frequency. **7. Pressure alerts** turns notifications on or off for the current session only. Alerts notify after three consecutive `WARNING` or `CRITICAL` scans while auto-refresh is on; they do not clear cache. **8. Quit** closes FeatherRAM.

Choose **3. Browse all process groups** to view the complete scan. In that view, use **n** and **p** for next and previous pages, enter a page number to jump, **r** to rescan, or **q** to return. The browser holds its snapshot until you rescan, so groups do not move between pages while you read.

You can also set the interval and dashboard preview count from Terminal:

```bash
FEATHERRAM_REFRESH_SECONDS=3 FEATHERRAM_LIMIT=20 ./featherram.command
```

Set `FEATHERRAM_ALERTS=0` to disable notifications. The in-app alert toggle affects only the current session. For testing or separate configurations, `FEATHERRAM_SETTINGS_FILE` can point to a different monitoring preference file. Legacy environment names `RAM_OPTIMIZER_REFRESH_SECONDS` and `RAM_OPTIMIZER_LIMIT` still work.

The browser includes every nonblank process row returned by macOS `ps` in that scan, including system tasks and rows without a process name. It does not list apps that are installed but not running. Helpers are grouped under an app name when possible; other commands and system tasks are grouped by process name. The group process counts add up to the visible-process total. Memory values are approximate resident-memory sums, so shared pages can appear in more than one process; the group sums do not equal physical RAM. **4. Open Activity Monitor** shows the per-process view.

## Sharing On Any Mac

For the smoothest sharing experience:

1. Share the current `dist/FeatherRAM-<version>.zip` archive when you want the cleanest handoff. `dist/FeatherRAM.zip` is an identical convenience copy of the latest build.
1. Share the whole FeatherRAM folder as a `.zip` when you also want the scripts and README included.
1. Tell people to try `FeatherRAM.app` first.
1. If macOS blocks it or says they do not have the right access privileges, they should open Terminal in the FeatherRAM folder and run:

```bash
zsh install.sh
zsh run-featherram.sh
```

This fallback works even if the executable bit did not survive the transfer.

## App Wrapper

`FeatherRAM.app` now carries its own bundled launcher scripts inside the app package. It opens Terminal and starts FeatherRAM without depending on sibling files next to the app, which makes it much better for sharing as a single item.

To rebuild the shareable app package:

```bash
zsh packaging/build-release.sh
```

## Versions and release notes

`VERSION` is the app version used by the command, the built app's macOS metadata, and the archive name. `CHANGELOG.md` records what changed in each version. The build stops if the current version has no changelog entry or the bundled command reports a different version.

For the next local build, update `VERSION`, add a matching `## [x.y.z] - YYYY-MM-DD` entry at the top of `CHANGELOG.md`, then run the build command above. Use a patch number for compatible fixes, a minor number for compatible new features, and a major number for breaking changes. Check the result with:

```bash
./featherram.command --version
unzip -l "dist/FeatherRAM-$(cat VERSION).zip" | head
```

FeatherRAM is published on [GitHub](https://github.com/taranggsannghi/featherram). Download the latest macOS app from the [Releases page](https://github.com/taranggsannghi/featherram/releases).

## What automatic care means

macOS already reclaims memory and uses unused RAM for cache. When auto-refresh is on, FeatherRAM watches the system pressure level and can alert you when it remains elevated. When it is off, FeatherRAM does not scan on a timer or send pressure alerts. The headroom bar is macOS's reported free-memory percentage; it is not a measure of app memory that can be "optimized." The `Free` and `Standby` rows show separate `vm_stat` categories; older versions added them together as “Free now.” If pressure is critical, save your work and inspect the largest apps in Activity Monitor.

[Apple's Activity Monitor guide](https://support.apple.com/en-ca/guide/activity-monitor/actmntr34865/mac) explains why free RAM alone is not a performance target.

The manual **Optimise RAM** action asks for your Mac password in a hidden prompt, then invokes macOS `purge` through `sudo` once to clear the file cache. Press **Escape** at any point while typing to return to the menu without clearing cache. The password is passed to `sudo` through standard input and is not written to a file. Apple describes `purge` as a way to simulate a cold file cache for performance analysis. It does not free memory allocated by apps and may make reopening files slower, so FeatherRAM never runs it automatically. The menu label does not change the underlying one-time cache-clearing action.

## Keyboard Shortcut

You can assign a keyboard shortcut with macOS Shortcuts:

1. Open the Shortcuts app.
1. Create a new shortcut.
1. Add the action to run a shell script.
1. Point it at this file, for example `~/path/to/featherram.command`.
1. Add a keyboard shortcut from the shortcut details panel.

This lets you open the RAM dashboard without hunting for the file in Finder.

## Why FeatherRAM

- It is meant to feel tiny, fast, and unobtrusive.
- It gives you a live view and timely alerts without running a heavy cleaner.
- The name points to the product promise: very low overhead, very quick to use.

## License

MIT License.
