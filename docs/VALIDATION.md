# Validation

## Syntax Check

Run AutoHotkey validation before publishing a change:

`powershell
AutoHotkey64.exe /Validate /ErrorStdOut 1Hub.ahk
`

Expected result: no parser errors and no output on standard error.

## Manual Smoke Test

- Start the script with AutoHotkey v2.
- Trigger the primary workflow described in README.
- Confirm the target behavior occurs once per gesture or hotkey press.
- Confirm normal keyboard and mouse behavior returns after the script action.
- Exit the script from the tray menu.

## Privacy Review

Before committing, scan tracked files for:

- Absolute local paths.
- Personal .ini or runtime configuration.
- Generated runner files.
- Backups or local experiment dumps.
- Sensitive local credentials.