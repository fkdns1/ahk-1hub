# Security review: Windows version gate

Date: 2026-06-23

Scope:
- Reviewed the public repository for credential-like strings, private path exposure, generated artifacts, and runtime behavior that could run on unsupported Windows versions.
- Checked `README.md`, `1Hub.ahk`, existing validation notes, security notes, and git-tracked files.

Findings:
- No public credential, API token, private key, or machine-specific secret was identified in tracked project files.
- The script launches and manages local AutoHotkey modules, so running it on unsupported Windows versions can create unpredictable automation behavior.

Change:
- Added an early `EnsureSupportedWindowsVersion()` startup guard to `1Hub.ahk`.
- The script now continues only on `WIN_10` or `WIN_11`.
- Unsupported versions show an explanatory message and exit with `ExitApp(1)` before module discovery or startup actions run.

Validation:
- Confirmed the guard checks `A_OSVersion` for `WIN_10` and `WIN_11`.
- Confirmed unsupported versions terminate through `ExitApp(1)`.
- Ran AutoHotkey v2 `/Validate /ErrorStdOut`; no parser output was produced.
