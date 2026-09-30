# Changelog

All notable changes to goprod. Categories drive the version number:
Fixed → patch, Added → minor, Changed (breaking) → major.

## [Unreleased]

## [0.1.0] - 2026-09-30

### Added

- `ship-readiness`: risk tier T0–T3, 12 pillars with a closed status set,
  binary fast-ship verdict, ordered remediation plan, delivery profile
  (`docs/ship-readiness.md`), Spec Kit constitution and spec-risk templates.
- `detect-signals.sh`: read-only signal inventory as one JSON object.
- `audit-distance.sh`: counts code commits since the last clean
  post-merge-audit; doubles as a `pre-push` hook that blocks pushes to the
  default branch above the threshold.
- `pr-audit`: hostile pre-merge audit with claim ledger, static hostile-change
  gate, ops-script checks, reviewer-independence rule, security ledger.
- `issue-audit`: skeptical audit of issues, incidents, and diagnoses, with safe
  reproduction and an anti-deferral rule.
- `ticket-resolution`: approved-only execution, test first, mutation proof,
  measured batch rule, close on landing, mandatory left-behind list.
- `post-merge-audit`: combined-tree audit with range base taken from the
  profile; records the clean SHA the push guard reads.
- `dep-bump`: consolidated dependency updates with a supply-chain floor and a
  check mode when no bot is configured.
- `release`: version from changelog classification, works with tags, image
  stamps, or build numbers; exact-SHA CI gate; rollback check.
- CI: manifest and skill validation, `audit-distance` behavior test,
  `detect-signals` JSON check, on Linux, macOS, and Windows (Git Bash).
- `.gitattributes` forcing LF line endings so scripts run on Windows checkouts.

[Unreleased]: https://github.com/ElderGil/goprod/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ElderGil/goprod/releases/tag/v0.1.0
