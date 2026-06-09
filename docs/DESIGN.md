# Design Notes

## Goal

A tray-first AutoHotkey v2 hub for launching, editing, and supervising small AHK modules from one place.

## Boundaries

- Runs locally on Windows through AutoHotkey v2.
- Keeps behavior in a small script rather than a packaged service.
- Avoids network calls, telemetry, and background updaters.
- Keeps private runtime configuration outside the public repository.

## Main Flow

1. AutoHotkey loads $(System.Collections.Hashtable.Script).
2. The script registers the relevant hotkeys or tray behavior.
3. User input triggers a small, deterministic action.
4. The script returns control to the target application or Windows shell.

## Failure Handling

The preferred failure mode is conservative: if the target app or expected window state is not available, the script should avoid destructive actions and leave normal keyboard or mouse behavior recoverable.

## Release Checklist

- Validate AutoHotkey syntax.
- Review git-tracked files for private paths or generated runtime files.
- Update CHANGELOG for user-visible changes.
- Keep GitHub Actions disabled by omission; this project does not need automated runners.