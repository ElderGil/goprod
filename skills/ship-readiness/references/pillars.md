# Pillar criteria

For each pillar: what it protects against, the per-tier requirement, what
counts as evidence, what does NOT count, and the deep-mode check.

Tier requirement key: **R** required · **R\*** required when the condition
holds · **—** not required (mark `N/A` unless present and broken).

## Contents

1. Unit tests · 2. Scenario tests · 3. CI · 4. Hostile review · 5. Feature
flags · 6. Staging · 7. Rollback · 8. Observability · 9. Migration safety ·
10. Public contract/semver · 11. Irreversible-consequence controls ·
12. Decision record

---

## 1. Unit tests on isolated logic

Protects against: regressions in pure logic that every other layer assumes.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R | R | R |

Counts: a test suite that runs with one documented command and exercises the
modules holding business rules; the command exits 0 on the default branch.

Does NOT count: a test directory with scaffold-generated placeholders only;
tests that are skipped/pending by default; snapshot-only suites for logic;
"we test manually".

Deep: run the suite once (in the project's own way) and record duration and
pass/fail. Sample three business-rule modules and check each has at least one
test that would fail if the rule changed.

## 2. Scenario and integration tests

Protects against: what unit tests cannot see — two writers racing, a disk or
network failing mid-operation, two sessions consolidating the same data, the
process dying before a write completes, conflict resolution.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R\* (if concurrent writes or external calls exist) | R | R (every identified failure mode has a test) |

Counts: tests that set up a real (or containerized) dependency and assert on
behavior under concurrency, injected failure, timeout, retry, or interrupted
writes. Named failure modes in the test names or descriptions.

Does NOT count: integration tests that only exercise the happy path; tests
that mock the very boundary whose failure is the risk.

Deep: list the project's failure modes (from code paths that write state or
call out), map each to a test or mark it uncovered. At T3 an uncovered failure
mode is `MISSING`, not `PARTIAL`.

## 3. CI on every push

Protects against: "works on my machine" and unverified merges.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R | R | R |

Counts: a pipeline triggered on push and/or pull request to the default
branch that builds and runs the tests; for multi-platform artifacts, a matrix
covering the platforms actually published; recent runs green on the default
branch.

Does NOT count: a workflow that only lints; a workflow triggered manually
only; tests marked `continue-on-error`; a pipeline that has been red on main
for days (that is `PARTIAL` — CI exists but is not a gate).

Deep: `gh run list --branch <default> --limit 20` (or host equivalent) and
report the pass rate and whether failures blocked merges (branch protection).

## 4. Hostile automated review before merge

Protects against: contributor/agent claims accepted as fact, supply-chain
tricks, prompt injection in PR text, semver mistakes.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R | R | R |

Counts: an automated review step run on every change before merge that treats
claims as unverified — the `pr-audit` skill run as routine, a configured review
bot with a written checklist, or equivalent; branch protection requiring it
where the host supports it.

Does NOT count: "the agent looks at it"; a generic review with no checklist;
review that happens after merge only.

## 5. Feature flags and flag hygiene

Protects against: every user seeing a change at once; limits blast radius.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | — (R\* if multi-tenant or many users) | R\* (user-facing behavior changes) | R |

Counts: a flag mechanism (library or in-house) that can turn a change off
without a deploy, and a way to target a subset of users.

Does NOT count: environment variables that require a redeploy to change
(acceptable only at T1, mark `PARTIAL`); commented-out code.

Deep: list flags; for each, find its evaluation sites and last change
(`git log -S<flag>`). A flag unchanged and evaluated to the same value for
more than 90 days is stale — list it as a cleanup gap.

## 6. Real staging as a gate

Protects against: obvious errors reaching real users.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | — | R\* (migrations or public API) | R |

Counts: an environment that mirrors production's topology (same deploy path,
same kind of data store, realistic config), that every release passes through
before production, with a documented promotion step.

Does NOT count: a developer laptop; a "staging" that is deployed differently
from production; a staging that releases skip.

## 7. Fast rollback — the filter

Protects against: everything else failing. This is the pillar that decides
whether speed is allowed at all.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| R (git revert suffices) | R | R | R |

Counts: a documented command or procedure that returns production to the
previous version, based on immutable artifacts (image tag, release ID,
platform release history), with an expected time; for T2+, evidence it was
exercised at least once (a date, a log, a runbook entry).

Does NOT count: "we'd rebuild the old commit"; mutable deploys (`git pull` on
the server, `scp`) with no previous artifact kept; rollback that requires
reverting a migration (then pillar 9 is the real gap).

Scope limit — state it in the report when relevant: rollback reverts code,
not consequences that already left the system (see pillar 11), and not data
already transformed by a migration (see pillar 9).

Deep: ask when rollback was last performed; if never, the acceptance criterion
of the gap is a deliberate rollback drill.

## 8. Observability

Protects against: not knowing it broke.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R | R | R (with alerting on business invariants) |

Counts: error tracking capturing unhandled errors from production; a health
check the platform or a monitor polls; at least one alert that reaches a human
(email, chat, pager); for T3, alerts on business invariants (payment
mismatches, duplicate charges, queue backlog), not only on HTTP 5xx.

Does NOT count: logs nobody reads; an SDK installed but not initialized in
production; dashboards without alerts.

Question to put in the report verbatim: "If the last deploy broke checkout at
03:00, who would know, and how, and when?"

## 9. Migration safety (expand–contract)

Protects against: state that `git revert` cannot undo.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R\* (live data) | R\* (migrations exist) | R\* (migrations exist) |

Counts: a stated rule (agent file, constitution, CONTRIBUTING) that
destructive changes follow expand–contract — add the new shape, migrate
readers/writers, remove the old shape in a later release; recent migrations
that comply; backups with a tested restore.

Does NOT count: reversible `down` migrations alone (a `down` that drops a
column restored from nothing does not restore data); backups never restored.

Deep: scan the last 10 migrations for drops/renames/type changes in the same
release as the code that stops using them.

## 10. Public contract and semver discipline

Protects against: surprising people who depend on you and cannot react fast.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | — | R\* (library, public API, CLI used by others) | R\* |

Counts: a changelog with categories (fixed/added/changed/breaking) under an
Unreleased heading; versions derived from those categories; breaking changes
only in majors; tags annotated.

Does NOT count: version numbers chosen by feel; a changelog written at
release time from commit titles.

N/A reason when closed app: "no external consumers of the code or API".

## 11. Controls for irreversible consequences

Protects against: damage that left the system before anyone could react —
money moved, message sent, device actuated.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R\* (if any irreversible effect exists) | R\* | R |

Counts: for each irreversible effect path — idempotency keys or dedupe on the
external call; at least two independent checks per identified failure mode
(for example, amount validation plus reconciliation job; rate limit plus
approval threshold); a kill switch (flag) that stops the effect without a
deploy; scenario tests of the failure modes (pillar 2); a stricter pre-merge
review rule for changes touching these paths, written down.

Does NOT count: a single check; "the provider handles it"; relying on
rollback.

The bar is set by the domain, not by the author: a senior human's change to
the payment path gets the same scrutiny as an agent's.

## 12. Decision and research record

Protects against: knowledge evaporating at the end of a session.

| T0 | T1 | T2 | T3 |
|---|---|---|---|
| — | R | R | R |

Counts: a place where decisions, rejected alternatives, and research are
written and found again — ai-memory, `docs/decisions/` or ADRs, Spec Kit
`specs/*/research.md`; recent entries (last 90 days) if the project is active.

Does NOT count: commit messages alone; chat history.
