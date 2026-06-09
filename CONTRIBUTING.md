# Contributing

Thanks for taking a look at this AutoHotkey utility. The project is intentionally small, so useful contributions are usually focused and easy to review.

## Good Contributions

- Clear bug reports with Windows version, AutoHotkey v2 version, and reproduction steps.
- Small compatibility fixes for keyboard layouts, mouse hardware, or app versions.
- Documentation improvements that make setup and validation easier.
- Conservative defaults that avoid surprising global behavior.

## Before Opening a Pull Request

1. Run AutoHotkey validation against the script.
2. Test the affected hotkey or workflow manually.
3. Update README, ROADMAP, or CHANGELOG when behavior changes.
4. Do not commit personal paths, generated runner files, local .ini files, or backups.

## Development Style

Keep the script direct and inspectable. Avoid adding dependencies unless they remove real complexity. Prefer named constants for timings and hotkeys so users can adjust behavior without reading the whole file.