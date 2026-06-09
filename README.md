# 1Hub

A tray-first AutoHotkey v2 hub for launching, editing, and supervising small AHK modules from one place.

## Why this exists

Windows automation scripts tend to multiply into separate tray icons, startup shortcuts, and one-off launch commands. 1Hub keeps that workflow in one compact tray panel so individual modules can remain small.

## Features

- Tray popup for module discovery and launch
- Module-level controls for run, edit, and open-folder workflows
- Startup registration helpers for users who want the hub available after login
- Public-safe layout that avoids bundling generated runners, local modules, or private config

## Quick Start

1. Install AutoHotkey v2 on Windows.
2. Download `1Hub.ahk` from this repository.
3. Review the configuration notes below.
4. Run the script with AutoHotkey v2.

## Configuration

Review the constants near the top of the script before first run. Keep machine-specific module folders and private configuration outside the repository.

## Validation

The public copy is checked with AutoHotkey's validation mode:

`powershell
AutoHotkey64.exe /Validate /ErrorStdOut 1Hub.ahk
`

See [docs/VALIDATION.md](docs/VALIDATION.md) for the current manual test checklist.

## Project Status

This is a sanitized public release of a personal Windows automation utility. The repository keeps the useful script, documentation, and project notes while excluding generated runner files, private settings, and machine-specific paths.

## Documentation

- [WORKLOG.md](WORKLOG.md) records the Codex-assisted iteration notes.
- [CHANGELOG.md](CHANGELOG.md) records public release history.
- [ROADMAP.md](ROADMAP.md) tracks planned improvements.
- [CONTRIBUTING.md](CONTRIBUTING.md) explains how to report issues or propose changes.
- [docs/DESIGN.md](docs/DESIGN.md) summarizes the design boundaries.