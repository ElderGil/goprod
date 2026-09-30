# goprod

**Ship to production fast, with a real safety net.** Agent skills for Claude
Code (and other agents that read `SKILL.md`) that decide whether a project can
safely drop slow human review, and then run the daily loop of auditing,
fixing, and releasing with evidence instead of vibes.

(`goprod` = "go to production". Unrelated to the Go language; works on any
stack.)

## The idea

Holding code for human review is waste **once** you have tests, CI on every
push, a real ability to roll back, and observability that tells you when
something broke. Without rollback, the problem is not delivery speed; it is
the infrastructure, and that gets fixed first.

Two refinements keep this honest:

- **The review bar follows the domain, not the author.** Payments, health,
  physical devices, and anything whose effect leaves your system before you
  can react get a stricter bar (scenario tests, two controls per failure mode)
  whether a senior human or an LLM wrote the code.
- **Some state doesn't revert.** Database migrations use expand–contract;
  public libraries treat semver as a gate; app-store review is a speed ceiling
  outside your control, and the skills say so instead of pretending.

Based on Fabio Akita's approach
([akitaonrails/my-skills](https://github.com/akitaonrails/my-skills)). These
skills are rewritten and generalized for any project, not copied. As he puts
it: a good skill is your own. Read these, then adapt them.

## The skills

| Layer | Skill | Use it |
|---|---|---|
| Precondition | `ship-readiness` | Once per project, and again when CI/deploy/infra changes. Writes `docs/ship-readiness.md` (risk tier, pillars with evidence, gates, rollback command). |
| Judgment | `pr-audit` | Before any merge. Treats every claim as unverified until proven. |
| Judgment | `issue-audit` | Before implementing an issue, or to check an incident or a diagnosis. |
| Execution | `ticket-resolution` | After an approved audit. Test first, mutation proof, no slop. |
| Execution | `dep-bump` | Dependabot/Renovate PRs, batched into one update. |
| Gate | `post-merge-audit` | Before pushing a batch of more than 3 changes, and before any release. |
| Publication | `release` | Only when you ask. |

Every flow skill reads `docs/ship-readiness.md` first; the risk tier (T0–T3)
sets how strict it is. Without a profile they assume T1 and tell you.

## Rules enforced mechanically, not by discipline

- **Push guard:** `skills/ship-readiness/scripts/audit-distance.sh` counts code
  commits since the last clean post-merge-audit. Installed as a `pre-push`
  hook, it blocks pushes to the default branch above the threshold (default
  3), including work done outside the skills. `git push --no-verify` stays a
  deliberate human override. Merges through the forge's web UI bypass local
  hooks; run the same script as a required CI job to cover those.
- **Independent review:** when the auditor also wrote the change,
  `pr-audit`/`post-merge-audit` run the review in an isolated subagent.
  Without one, the report is stamped `SELF-REVIEW` and cannot approve at T2+.
- **Mutation proof:** `ticket-resolution` breaks what each new test protects
  and records that the test failed.

## Install

### Claude Code (plugin)

```
/plugin marketplace add ElderGil/goprod
/plugin install goprod@goprod
```

Start a new session afterwards. Update later with
`/plugin marketplace update goprod`. Skills show up namespaced
(`goprod:pr-audit`); asking "run pr-audit" works as well.

### Other agents (Codex, etc.) or manual install

```sh
git clone https://github.com/ElderGil/goprod.git
for s in goprod/skills/*/; do
  ln -sfn "$PWD/$s" "$HOME/.claude/skills/$(basename "$s")"   # or ~/.codex/skills, ~/.agents/skills
done
```

## Requirements

- `git` and `bash` (macOS bash 3.2 is fine)
- `gh` CLI for GitHub features (optional: without it, forge state is reported
  as not verified)
- Python 3 (only for the JSON check in CI)
- Optional: [Spec Kit](https://github.com/github/spec-kit). `ship-readiness`
  proposes a "Delivery" section for the constitution and a "Risk & Failure
  Modes" section for specs.

## First run

1. Open a session in a project where a mistake is cheap.
2. `run ship-readiness`. It runs a read-only scan, asks a few yes/no
   questions about risk, and gives you a verdict, the pillar table, and an
   ordered gap list. It writes nothing without your approval.
3. Daily loop:

   ```
   run pr-audit and issue-audit, then run ticket-resolution
   ```

   Add `then run release` when a release is due. Only dependency bumps
   queued? `run dep-bump and release`.

## Feedback

After using it on a real project, ask your agent for a usage report: what
worked, what broke, and what it had to improvise, with evidence. Open an issue
with it. The kit was shaped by exactly such a report.

## Contributing

PRs welcome. Note that a PR changing a `SKILL.md` changes instructions that
run on every user's machine, so contributions go through `pr-audit` before
merge, and users should install released versions.

## License

MIT. See [LICENSE](LICENSE).
