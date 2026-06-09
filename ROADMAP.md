# Roadmap

This roadmap keeps future work practical and reviewable. Items here should become issues before implementation.

## Near Term

- [ ] Add a sample module manifest format
- [ ] Document recommended folder layout for portable setups
- [ ] Add optional status grouping for long-running modules

## Quality Bar

- Keep the script readable as a single-file utility unless complexity clearly justifies splitting it.
- Prefer documented configuration constants over hidden local assumptions.
- Validate syntax before each release.
- Keep private machine paths and personal runtime files out of the repository.

## Out of Scope

- Background services.
- Installer bundles.
- Telemetry or network features.
- Automation that depends on private local folders.