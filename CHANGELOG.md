# Changelog

## [1.4.1] - 2026-10-17

### Changed

- Revised dashboard, memory breakdown, process browser, menu, alert, prompt, help, launcher, and setup copy for clarity.
- Renamed the speculative memory category to Standby and shortened the manual cache action label to Optimise RAM. The action still runs the same one-time macOS `purge` command after the hidden password prompt.
- Kept process collection, grouping, auto-refresh, alert thresholds and cooldowns, and cache-clearing behavior unchanged.

FeatherRAM changes are recorded by app version. Download published builds from the [GitHub Releases page](https://github.com/taranggsannghi/featherram/releases).

## [1.4.0] - 2026-10-17

### Changed

- Increased the default dashboard preview from eight to 15 process groups; the full paged browser remains available, now at choice 3.
- Restored the concise Auto-refresh menu wording, put Quit last, and explained pressure alerts and their session-only toggle. Manual cache clearing remains choice 2 with the same password and Escape behavior.
- Shortened the memory labels and split the old combined “Free now” value into separate Free and Speculative figures. The underlying `vm_stat` readings and cache-clearing mechanism are unchanged.

## [1.3.1] - 2026-10-17

### Changed

- Removed the extra `CLEAR` confirmation. Choosing 2 now opens a hidden Mac password prompt and runs the same manual file-cache clear through `sudo purge`.
- Escape cancels immediately while entering the password and returns to the dashboard. Success and failure appear on the dashboard without an extra Return prompt.

## [1.3.0] - 2026-10-16

### Added

- Added a paged browser for every process group in a scan, including macOS tasks and unnamed process entries. It supports next/previous pages, page jumps, and an explicit rescan.
- Added the number of process entries in each group and displayed smaller groups in MB.

### Changed

- Kept the dashboard preview compact while making every group accessible through menu choice 8. The existing manually confirmed file-cache action is unchanged.

## [1.2.1] - 2026-10-16

### Changed

- Clarified that the memory list shows the largest process groups, including apps and system tasks, with a count of all visible processes and groups.
- Added a menu choice to show the top 30 groups instead of the default top 8.
- Kept the existing manual file-cache clearing command and confirmation unchanged.

## [1.2.0] - 2026-10-16

### Added

- Added a direct on/off switch for automatic monitoring and saved the choice across app launches.
- Added a confirmation before the one-time manual file-cache action.

### Changed

- Paused pressure alerts whenever automatic monitoring is off; manual refresh remains available.

## [1.1.1] - 2026-10-16

### Changed

- Added a single `VERSION` file used by the command and app build.
- Added a versioned ZIP name and included the version and changelog inside the app.
- Made packaging check that the current version has a changelog entry and that the built app reports the same version.

## [1.1.0] - 2026-10-16

### Added

- Added a live memory-pressure dashboard with a headroom bar and automatic refresh.
- Added notifications after sustained high pressure, with a cooldown.

### Changed

- Clarified that file-cache clearing is a manual diagnostic action; FeatherRAM does not clear cache or quit apps automatically.

## [1.0.0] - date not recorded

### Added

- Initial local FeatherRAM command and macOS app wrapper.
