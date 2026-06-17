# Lightweight Security Review - 2026-06-18

Scope: public repository only. Private repositories were excluded.

## 검사1 - Exposure Scan

Checked README, main AHK script, ignore rules, generated runner/log/backup patterns, local path patterns, and credential-like strings.

Result: no public secret, private path, or credential exposure was found. Runtime paths use AutoHotkey variables such as `A_ScriptDir` and `A_Startup`. `.gitignore` excludes generated runners, logs, settings, backups, and disabled scripts.

Severity: none

## 검사2 - Behavior And Build Risk

Checked `1Hub.ahk`, module discovery, hidden runner generation, Startup shortcut handling, and repository Actions metadata.

Result: the tool intentionally discovers and runs top-level `*.ahk` files from the selected module folder. That is useful, but it means the module folder should be trusted and user-controlled. Avoid using downloads, shared sync folders, or untrusted folders as the default module folder.

Severity: medium

## Notes

This was a lightweight review, not a full audit. Main follow-up is operational guidance for trusted module folders.
