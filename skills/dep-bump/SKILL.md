---
name: dep-bump
description: Clear dependency-bot bump PRs (Dependabot, Renovate) fast and safely — batch, never serialize — consolidate all open bumps into one package-manager update to the newest compatible versions, one verification pass, fix forward, one commit closing every PR. Enforces a supply-chain floor (public registry, expected name/version/checksum; git/path sources, typosquat-adjacent names, or new install hooks stop and go to pr-audit) and closes the loop on every PR not consolidated. Use when the user says "run dep-bump"/"run pr-bump", "clear the dependabot PRs", "merge the dependency bumps", or when only bot-authored dependency PRs are queued. Anything touching application code, migrations, Dockerfiles, or non-dependency config goes to pr-audit instead.
---

# Dependency Bump

Several bump PRs are one unit of work. Merging and testing them one at a time
is pipeline churn and produces conflicting lockfiles. Consolidate them, let the
package manager resolve the newest compatible versions (possibly newer than
any PR proposes), verify once, fix forward.

## Calibrate from the delivery profile

Read `docs/ship-readiness.md` for the gate command, default branch, and tier.
No profile → detect from CI/manifests and say so.

- **Major bumps:** never consolidated here unless the user asks — they go to
  `pr-audit` with a disposition (below).
- **T3:** a bump of a dependency used on an irreversible path (payment SDK,
  messaging client, device driver) goes to `pr-audit`, even if minor — the
  change surface is the provider's behavior, not your lockfile.
- **Public library (T2):** bumps that widen your own published dependency
  ranges are a release-impact decision; report them, do not widen silently.

## Preconditions and guardrails

- Only bot-authored, dependency-metadata-only PRs. Check files changed; any
  application code, migration, Dockerfile, CI, or non-dependency config →
  `pr-audit`.
- Never commit unrelated local changes. Inspect `git status --short --branch`,
  `git diff --stat`, `git log --oneline -10`. If the deploy builds from the
  working tree, stash unrelated files during the build and restore them after.
- Do not run broad auto-formatters to make CI pass. Narrow fixes only.

### Supply-chain floor

Before updating, verify each bumped package resolves from the project's
default public registry (npm, PyPI, RubyGems, crates.io, Go proxy, Maven
Central, NuGet…) with the expected name, version, and checksum. **Stop and hand
to `pr-audit`** on: git/path sources, a changed registry, renamed or
republished packages, typosquat-adjacent names, a new maintainer on a
low-download package, or new install/build hooks (npm lifecycle scripts,
`build.rs`, setup hooks). Advisory scanners only flag *known* issues — a
well-formed bump to a trojaned release passes them. This floor exists for that
case.

## No bot PRs (check mode)

When no dependency-bot PRs are open — or no bot is configured — do not invent
work:

1. Run the ecosystem's read-only checks (`npm outdated` + `npm audit
   --omit=dev`, `pip list --outdated` + `pip-audit`, `bundle outdated` +
   `bundle audit`, `cargo outdated` + `cargo audit`, or the project's
   equivalent; note which tools are not installed).
2. Report: advisories affecting production dependencies first (with whether a
   compatible fixed version exists), then outdated majors, then the rest.
3. If no bot is configured, recommend enabling one and show the minimal config
   for the project's ecosystems (`.github/dependabot.yml` or Renovate).
4. Change nothing unless the user approves specific updates. Approved manual
   updates follow Steps 2–4 with the same supply-chain floor. When an advisory
   has no compatible fix, removing or replacing the dependency is often the
   real fix — hand that decision to `issue-audit`/`ticket-resolution` as a
   ticket, not a bump.

## Step 1: Inventory

```bash
gh pr list --state open --json number,title,author,labels,headRefName,baseRefName,isDraft,url
gh pr diff <N> --name-only
gh pr view <N> --json files,statusCheckRollup,mergeable
```

Routine signals: bot author, `dependencies` label, simple "Bump X from a to b"
title, only manifest/lockfile changed, patch or minor. A red bot branch is
often a stale lockfile; judge by the consolidated update, not the branch CI.

## Step 2: Consolidate with the package manager

On the default branch, update all bumped packages together to the newest
version the existing constraints allow:

| Ecosystem | Consolidated update |
|---|---|
| npm / pnpm / yarn | `npm update <a> <b>` · `pnpm update <a> <b>` · `yarn up <a> <b>` |
| Python (uv / poetry / pip-tools) | `uv lock --upgrade-package a --upgrade-package b` · `poetry update a b` · `pip-compile -P a -P b` |
| Ruby | `bundle update <a> <b>` then `bundle check` |
| Rust | `cargo update -p a -p b` |
| Go | `go get a@latest b@latest && go mod tidy` (within the major) |
| Others | the project's documented equivalent |

Do not widen manifest constraints or cross a major unless the user asks. If
the true upstream latest needs a constraint change, apply the latest
compatible version and report what going further would require. Note
transitive updates in the summary.

## Step 3: Verify once

Run the full gate from the profile (or CI-equivalent) once over the
consolidated set — never per bump. On failure:

1. Reproduce the failing subset.
2. Decide: dependency change, CI environment, or pre-existing flakiness.
3. Smallest fix that removes the cause; re-run focused then full gate.
4. **Fix forward** inside the consolidated change (pin, constraint tweak, code
   fix). To isolate a culprit, bisect in a scratch worktree — do not un-bundle
   back into per-PR merges.

## Step 4: Commit and push

Detect the default branch (`gh repo view --json defaultBranchRef --jq
.defaultBranchRef.name`) — never assume `main` or `master`; `Closes #N` only
works on the default branch.

Stage only the intended files, commit dependency changes separately from any
test/CI hardening, reference every consolidated PR (`Closes #N` for each),
push. Then confirm the PRs closed and watch hosted CI on the pushed SHA. Do
not deploy before CI is green unless the user explicitly accepts the risk.

## Step 5: Close the loop on everything not consolidated

"Deferred", "escalated", or "declined" is a disposition, not a resting state.
Before finishing, every PR you did not consolidate gets a comment on the forge
saying why (major bump, suspicious source, non-metadata change, failing build)
and is either **closed** or **linked to a tracking issue** (and handed to
`pr-audit` if it needs review). Mentioning it only in your summary is not
resolving it.

## Output

```markdown
## Dependency bump

Closed PRs: #a, #b
Updated: pkg 1.2.3 → 1.2.5 (newer than PR target 1.2.4), transitive: dep 0.8 → 0.9
Supply-chain floor: passed | stopped on <pkg>: <reason> → pr-audit
Local gate: <command> — pass/fail
Hosted CI: <run> on <SHA>
Not consolidated: #c (major) — commented + closed, tracking #d
Local changes left untouched: <files | none>
Deploy: not requested | done, health: <result>
```
