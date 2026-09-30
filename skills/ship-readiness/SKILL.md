---
name: ship-readiness
description: Assess whether a project can safely ship fast — automated tests, scenario tests, CI on every push, hostile pre-merge review, feature flags, real staging, fast rollback, observability, migration safety, semver discipline, and controls for irreversible consequences — calibrated to the project's risk tier (T0–T3). Produces an evidence-backed pillar report, a binary fast-ship verdict, a prioritized remediation plan, and a delivery profile (docs/ship-readiness.md plus a Spec Kit constitution "Delivery" section) that the audit/resolution/release skills read. Use when onboarding a project, before speeding up delivery or reducing human review, when asked "is this project ready to ship fast / can we trust our pipeline / what's missing in our infra", when the profile is missing or stale (CI/deploy/infra files changed since it was written), or when a Spec Kit /plan flags the Delivery section. Assesses and proposes; it does not implement fixes without per-item approval.
---

# Ship Readiness

Decide whether this project's safety net is strong enough that holding code
for human review is waste — and if not, exactly what to fix first.

The governing idea: **if you cannot roll back quickly, the problem is not
delivery speed, it is the infrastructure.** Nobody skips real rollback. Once
rollback, CI, and observability exist, the review bar is set by the *domain's*
cost of error, never by who (or what) wrote the code.

## Why this skill is strict about wording

A readiness report that says "consider adding more tests" is useless — it
cannot be verified, prioritized, or closed. Every statement this skill makes
must be one of:

- a **status** from the closed set below, with evidence (path, command output,
  URL, or the user's explicit answer);
- a **gap** with a concrete minimal fix, a verifiable acceptance criterion, and
  a size (S/M/L);
- an **explicit non-applicability** with the reason.

Banned in output: "best practices", "consider", "as appropriate", "robust",
"ensure proper", or any recommendation without an acceptance criterion.

### Status set (closed)

| Status | Meaning | Requirement |
|---|---|---|
| `MET` | Exists and works for this project | cite evidence |
| `PARTIAL` | Exists but misses a named part | name the missing part |
| `MISSING` | Required at this tier and absent | cite where you looked |
| `N/A` | Not required for this project | reason tied to the risk profile |
| `OUT OF OUR CONTROL` | A gate owned by someone else (app store review, legal/compliance sign-off, client acceptance) | name the owner and its impact on speed |
| `NOT VERIFIED` | Could not establish either way | name the missing evidence and how to get it |

Never upgrade `NOT VERIFIED` to `MET` because something "looks configured".
A workflow file that exists but never runs on push is `PARTIAL`, not `MET`.

## Modes

- **Quick (default):** Phases 0–2 using the signal script plus targeted reads,
  then verdict, gaps, and profile. Aim for a few thousand tokens of reading.
- **Deep:** also verify rollback was ever exercised, find stale feature flags,
  sample scenario-test quality, and inspect CI run history. Run when the user
  asks, when the tier is T3, or when a quick-mode status is `NOT VERIFIED` on
  rollback or observability.
- **Refresh:** a profile exists. Re-run the signal script, re-assess only
  pillars whose evidence changed (the script reports infra files changed since
  `Last assessed`), and report the delta. A refresh updates `Last updated`
  (date, SHA, what changed) and appends to History; only a full re-assessment
  of every pillar moves `Last assessed` / `Assessed at`. The header must never
  claim a freshness the content does not have.

## Phase 0: Collect signals (read-only)

Run the bundled script from the project root; do not read the repository file
by file to discover what it already reports:

```bash
bash <skill-dir>/scripts/detect-signals.sh .
```

It prints one JSON object: repo host, manifests, lockfiles, test counts, CI
files and triggers, containers, deploy config, rollback/staging hints,
migrations, feature-flag and observability libraries, payment/messaging/
health/device integrations, publish and app-store signals, changelog, decision
records, Spec Kit constitution, and an existing profile's staleness.

Signals are leads, not verdicts. A hit on "stripe" in a test fixture is not a
payment integration. Read `references/signals.md` for how to confirm each
signal and which follow-up reads settle it. Also read the project's
`AGENTS.md`/`CLAUDE.md`/README deploy section when present — stated policy
beats inference.

If the project is not a git repository, say so: rollback-by-git is then
`MISSING` by definition and becomes gap #1.

## Phase 1: Classify the risk tier

The tier sets which pillars are required. Infer what you can from Phase 0;
ask the user only what evidence cannot answer, as short closed questions
(yes/no or pick one). Ask all open questions in one batch.

| Question | Why it matters |
|---|---|
| Does any code path cause an effect outside the system that a redeploy cannot undo (money moved, message sent, device actuated, clinical/legal record written)? | Reverting code does not revert consequences. |
| Is there persisted state changed by migrations? | Reverting a binary is trivial; reverting a migration that moved or dropped data is not. |
| Do external parties depend on this as a library, API, or package? | Their reaction time is slower than yours; breaking them silently is the real risk. |
| Is it distributed through an app store? | Store review sits inside your release path and you do not control its timing. |
| Is the domain regulated (finance, health, safety, personal-data law)? | Requires more than one check per identified failure mode. |
| Who approves a release — only the owner, or a chain (legal, compliance, PM, client)? | The principle generalizes; the pace does not. |

Tiers (take the highest that applies):

- **T0 — disposable:** prototype, personal script, no users relying on it.
- **T1 — standard app:** real users, errors are recoverable by redeploy.
- **T2 — stateful or depended-upon:** migrations on live data, public
  library/API, or app-store distribution.
- **T3 — irreversible or regulated:** money, health, physical safety,
  outbound effects that cannot be recalled, or regulated domain.

State the tier with the answers that produced it. If the user's intuition and
the evidence disagree (they say "just a side project", the code calls Stripe
live keys), show the evidence and ask them to confirm.

## Phase 2: Assess the pillars

Read `references/pillars.md` for each pillar's "counts as evidence", "does NOT
count", and per-tier requirement. The pillars:

1. Unit tests on isolated logic (TDD not required — existence and signal are)
2. Scenario/integration tests: concurrency, partial failure, conflict, process death mid-write
3. CI builds and tests on every push, on the platforms actually shipped
4. Hostile automated review before merge
5. Feature flags and flag hygiene
6. Real staging as a gate before real users
7. Fast rollback — **the filter**
8. Observability: "how would you know it broke?"
9. Migration safety (expand–contract)
10. Public contract and semver discipline
11. Controls for irreversible consequences
12. Decision and research record

Assess only what the tier requires plus anything already present (a present
but broken pillar is still a finding). Mark the rest `N/A` with the reason.

## Phase 3: Verdict

**Fast-ship eligible: YES / NO** — binary. It is NO when any of:

- pillar 7 (rollback) is not `MET`;
- pillar 3 (CI) is not `MET`;
- pillar 8 (observability) is `MISSING` at T1 or above;
- at T2 with migrations, pillar 9 is not `MET`;
- at T3, pillar 11 is not `MET` or pillar 2 is not `MET`.

A NO is not a judgment of the team; it names the shortest path to YES.
`OUT OF OUR CONTROL` gates never flip the verdict — they are reported as the
ceiling on speed that remains after the verdict is YES.

## Phase 4: Remediation plan

Order is fixed, because each step makes the next one safe:

1. Rollback (7) → 2. CI (3) → 3. Observability (8) → 4. Migration safety (9, if
applicable) → 5. Scenario tests on the riskiest paths (2) → 6. Irreversible-
consequence controls (11, T3) → 7. Everything else by tier requirement.

Each gap entry:

```markdown
- [G1] Pillar 7 Rollback — MISSING
  Evidence: no deploy config; releases are `scp` of a build (README:42)
  Minimal fix: containerize and deploy by immutable image tag; document
    `deploy <previous-tag>` as the rollback command
  Acceptance: a deliberate rollback to the previous tag completes in < 10 min
    and is recorded in docs/ship-readiness.md with the date
  Size: M
```

**Do not implement anything in this skill run.** Present the plan; implement a
single gap only after the user explicitly approves that gap, then re-assess
that pillar.

## Phase 5: Output and persistence

1. Report in chat using this template:

```markdown
## Ship readiness: <project> — <date>

Tier: T<n> — <one line of why, with evidence>
Fast-ship eligible: YES | NO — <blocking pillars>
Speed ceiling outside our control: <store review / compliance / none>
Mode: quick | deep | refresh (<delta summary>)

| # | Pillar | Required at tier | Status | Evidence |
|---|---|---|---|---|

### Remediation plan (ordered)
<gap entries>

### Not verified
<what could not be established and how to establish it>
```

2. With the user's approval, write or update `docs/ship-readiness.md` using
   `templates/profile.md`. Its header lines are machine-read, so keep their
   `Label: value` shape:
   - `Last assessed` — the signal script uses it to detect staleness;
   - `Release scheme` and `Last release marker` — how this project marks a
     release (annotated tags, image stamp, build number, or none). The
     post-merge-audit and release skills take their range base from here
     instead of assuming tags exist;
   - `Last clean post-audit` and `Post-audit threshold` — read by
     `scripts/audit-distance.sh`. On first write, set the baseline to the
     current HEAD and label it `baseline at hook install, not audited`.
   Also fill "What the build also validates" and "Tests skipped without
   environment" in the Gates section; both have cost real debugging time.

3. **Propose the push guard.** The ">3 tickets → post-merge-audit before push"
   rule fails when it depends on an agent's discipline, and work done outside
   the skills never triggers it. Offer to install
   `scripts/audit-distance.sh` as the project's `pre-push` hook (copy to
   `.git/hooks/pre-push`, or call it from an existing husky/lefthook setup).
   It blocks pushes to the default branch when code commits since the last
   clean post-audit exceed the threshold; `git push --no-verify` remains a
   deliberate human override. State its limit: merges done on the forge's web
   UI bypass local hooks — for those, a required CI job running the same
   script is the equivalent. Install only on approval.

4. If a Spec Kit constitution exists (`.specify/memory/constitution.md`),
   propose the "Delivery" section from `templates/constitution-delivery.md`,
   filled for this tier, and the per-feature risk section from
   `templates/spec-risk-section.md`. Show the diff; apply only on approval.
   The constitution gets the short rules; the evidence stays in the profile.
   If there is no Spec Kit, put the same rules in the canonical agent file
   (`AGENTS.md`/`CLAUDE.md`) instead, and say so.

5. If an ai-memory (or equivalent) is available, record the tier decision and
   its rationale as a durable decision — not the whole report.

## What this skill is not

- Not a security audit, not a code review, not a test-writing session.
- Not a place to be polite about a missing rollback. "Your infra cannot
  revert; fix that before any conversation about speed" is the expected tone
  when the evidence supports it.
- Not a substitute for the user's judgment on how much speed their context
  tolerates. The report says what the net can catch; the user decides the pace.
