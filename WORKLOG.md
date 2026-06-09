# Worklog

This public copy was prepared from a local AutoHotkey hub that was iterated with Codex.

Codex-assisted changes included:

- adding a shell folder picker for the default module folder
- adding a Windows startup toggle through a user Startup shortcut
- adding per-module edit actions
- switching control buttons to compact icon-only actions
- adding a script-folder open button
- improving popup panel outline rendering
- closing the popup when focus moves to another window
- validating the script with AutoHotkey v2 syntax checks during development

Private local runtime files such as generated runner scripts, backups, and `.ini` configuration were excluded from this repository.

## 2026-06-09 - Public repository hardening pass

- Expanded README into a project-oriented overview with setup, validation, and privacy notes.
- Added CHANGELOG, ROADMAP, CONTRIBUTING, design notes, validation checklist, and issue templates.
- Kept the public copy free of generated runners, local settings, backups, and machine-specific paths.

## 2026-06-09 - Subagent review follow-up

- Maintenance reviewer and open-source readiness reviewer both flagged a README template substitution bug in the Quick Start section.
- Fixed the script filename reference and normalized the MIT license text for GitHub license detection.
- Kept the change limited to user-facing documentation and license metadata; no runtime behavior changed.
