# Update without deleting the app

Keep one source folder on the Mac. The installed app and its saved alert history are separate from this folder.

## First use of this updater

1. Copy the entire updated project to your Mac, including the new `scripts` folder.
2. Open Terminal in that project folder (type `cd `, drag the folder into Terminal, press Return).
3. Run `make test`. The expected result is 27/27 checks passed.
4. Run `make update`.

The updater compiles first. If compilation fails, your running app is left alone. If it succeeds, it asks the old app to quit, packages the new app, copies it to your personal `~/Applications/DiskMetrics.app`, verifies its signature, and opens it. It never force-kills the app. Your live alert history stays in Application Support. Finish any filesystem test/check before updating.

Click the menu-bar icon and **Open dashboard** to see the full overview. You do not need to delete an app or clear saved data. Use this installed copy going forward; older copies in Downloads are no longer needed for launching.

## Subsequent changes without Git

Copy the changed source files into this same source folder, replacing the previous versions, then run:

```sh
make update
```

The command updates the installed app in place. `make update` does not fetch changes from the Windows computer by itself.

## Recommended team workflow: GitHub

Publish this project in a public team repository (also required by the challenge). On the Mac, clone that repository once and use the cloned folder for development. Once changes have been committed and pushed from the editing computer, run in that clone:

```sh
make sync
```

This runs `git pull --ff-only` and then `make update`. It will stop on a Git error instead of discarding local edits. A remote repository must be configured first; this project currently has no remote configured in the authoring workspace. Never put tokens or passwords in these files.

## Live data versus demo

Normal launches always use real collectors. Speed values automatically choose KB/s, MB/s, or GB/s. The graph uses GB/s. Freshness labels update once a second; collectors normally complete about every two seconds plus collection time. After ten seconds without a completed current activity sample, rate values show unavailable. Capacity keeps its last measurement with an explicit stale timestamp.

Health is a separate periodic scan, not a second-by-second sensor stream. The overview describes reported hardware warnings in one sentence; it does not invent a health percentage. Health reports older than three minutes are marked old. Quota/NFS reports and speed-test results are snapshots.

For an intentionally simulated judging scenario only, quit the normal instance first and launch:

```sh
open "$HOME/Applications/DiskMetrics.app" --args --demo
```

The dashboard displays an explicit simulated banner. Quit and reopen normally to return to live data. There is no demo toggle in the user dashboard.
