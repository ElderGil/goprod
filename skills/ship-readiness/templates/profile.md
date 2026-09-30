Last assessed: YYYY-MM-DD
Assessed at: <commit SHA> (ship-readiness <quick|deep> — full assessment)
Last updated: YYYY-MM-DD at <commit SHA> (<what changed: refresh, gap closed, drill>)
Last clean post-audit: <commit SHA> (YYYY-MM-DD, post-merge-audit | baseline at hook install, not audited)
Post-audit threshold: 3
Release scheme: <annotated tags | image stamp | build number | none>
Last release marker: <tag | image stamp | build id> at <commit SHA>

<!-- Header lines are machine-read: detect-signals.sh reads "Last assessed" to
     detect staleness; audit-distance.sh reads "Last clean post-audit" and
     "Post-audit threshold". Keep the "Label: value" shape. -->


# Ship readiness profile — <project>

This file holds the *state and evidence* of the delivery safety net. The
*rules* derived from it live in the Spec Kit constitution ("Delivery") or the
canonical agent file. Skills (pr-audit, issue-audit, ticket-resolution,
post-merge-audit, dep-bump, release) read this file to calibrate strictness.

## Risk tier

Tier: T<n>
Why: <answers/evidence that produced the tier>
Irreversible effect paths: <list of modules/endpoints, or "none">
External consumers: <library/API/CLI users, or "none">
Speed ceiling outside our control: <app store review | compliance sign-off | none>

## Verdict

Fast-ship eligible: YES | NO — <blocking pillars>

## Gates (commands the other skills run)

- Focused tests: `<command>`
- Full local gate: `<command>`
- What the build also validates: <e.g. `next build` typechecks test/ | none beyond compile>
- Tests skipped without environment: <e.g. 14 Postgres tests need DATABASE_URL | none>
- Hosted CI: <workflow names / required jobs>
- Release matrix: <platforms/targets that must be green before a tag>
- Rollback: `<command or procedure>` — expected time <n> min — last exercised <date|never>
- Branch strategy: <single mainline + tags | split fix/feature | release branches>
- Versioning: <semver from changelog categories | calendar | N/A: closed app>

## Pillars

| # | Pillar | Required | Status | Evidence |
|---|---|---|---|---|
| 1 | Unit tests | | | |
| 2 | Scenario tests | | | |
| 3 | CI on every push | | | |
| 4 | Hostile pre-merge review | | | |
| 5 | Feature flags | | | |
| 6 | Staging gate | | | |
| 7 | Rollback | | | |
| 8 | Observability | | | |
| 9 | Migration safety | | | |
| 10 | Public contract/semver | | | |
| 11 | Irreversible-consequence controls | | | |
| 12 | Decision record | | | |

## Open gaps (ordered)

<gap entries: pillar, status, evidence, minimal fix, acceptance, size>

## History

- YYYY-MM-DD: <what changed since the previous assessment>
