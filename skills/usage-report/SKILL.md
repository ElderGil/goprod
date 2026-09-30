---
name: usage-report
description: Collect evidence while the goprod skills are used and turn it into a sanitized usage report for the goprod maintainer. Two moments — "start goprod usage log" at the beginning of a session creates a local, git-ignored log that every goprod skill appends to after it runs; "write the goprod usage report" at the end turns the log plus the session into a structured report (what each skill produced, what worked, what was bad or strange, the agent's own mistakes, numbers, recommendations), strips confidential data, and shows it for approval before anything is shared. Use whenever the user wants to test, pilot, evaluate, or give feedback on goprod, asks for a usage log or usage report, or says they will send feedback about the skills.
---

# Usage Report

The kit improves from reports of real use: what each skill did on a real
project, where it did not fit, and what broke. Reports written from memory at
the end of a long session lose exactly those details, because long sessions
get summarized. So this skill works in two moments: log while working, write
at the end.

## Moment 1: start the log

Trigger: "start goprod usage log", "I'm testing goprod", or any request to
pilot the skills.

1. Create `.goprod/usage-log.md` in the project root (if it does not exist).
2. Keep it out of git without touching the project's `.gitignore`: append
   `.goprod/` to `.git/info/exclude` (local-only ignore). The log may contain
   project details and must never be committed by accident.
3. Write the header:

   ```markdown
   # goprod usage log
   Started: YYYY-MM-DD
   goprod version: <from the plugin manifest or the skills' install path, or "unknown">
   Agent / model: <agent name and model, if known>
   OS / shell: <e.g. Windows 11 / Git Bash, macOS / zsh>
   Project stack: <languages, frameworks, database, deploy style>
   ```

4. Tell the user the log is active and where it lives.

From then on, **every goprod skill appends an entry when it finishes** (each
skill has a "Usage log" note pointing here). Also append an entry when you
notice a skill defect mid-run; do not wait for the end.

### Entry format

```markdown
## YYYY-MM-DD HH:MM — <skill>
- Input: <what it ran on: PR #, issue, range, "no input">
- Produced: <verdicts, findings, commits, files — with counts>
- Improvised / skipped: <where the skill did not fit this project, and what you did instead>
- Skill defect: <wrong/unclear/missing instruction, broken script output — with evidence | none>
- My mistake: <errors that were yours, not the skill's, and how they were caught | none>
- Numbers: <tests before→after, failures caught, time, gate results>
- Evidence: <commands, files, SHAs>
```

Keep entries factual and short. Separate skill defects from your own
mistakes: the maintainer can fix the first, only the lesson helps with the
second.

## Moment 2: write the report

Trigger: "write the goprod usage report", "send feedback on goprod", end of a
pilot.

1. Read `.goprod/usage-log.md`. If it does not exist, write the report from
   the session alone and state at the top: "No usage log — details may be
   missing."
2. Draft `.goprod/usage-report-YYYY-MM-DD.md` with these sections:

   1. **Summary** — 3–6 bullets: what ran, where the value was, the most
      important problem.
   2. **Context** — stack, risk tier, goprod version, agent/model, OS; which
      skills ran on real input vs. no input (and why).
   3. **What each skill produced** — per skill, from the log.
   4. **What worked** — with evidence.
   5. **What was bad or strange in the skills** — each item: what happened,
      evidence, a suggested change.
   6. **The agent's own mistakes** — with the lesson; kept apart from 5.
   7. **Numbers** — write "not measured" where there is no data; never
      estimate silently.
   8. **Prioritized recommendations** for the maintainer.

   Every claim carries evidence (command, file, number, SHA). What you cannot
   support, say you cannot.

3. **Sanitize before showing.** The report is written for a public issue
   tracker. Replace, never just delete:

   | Found | Replace with |
   |---|---|
   | company, client, product, or project names | `<company>`, `<client>`, `<project>` |
   | people's names, e-mails, usernames | `<person>`, `<email>` |
   | hostnames, domains, IPs, internal URLs | `<host>`, `<url>` |
   | secrets, tokens, keys, connection strings | `<redacted-secret>` (and flag it: a secret in the log is itself a finding) |
   | private filesystem paths | `<path>` |
   | customer or personal data of any kind | remove the sample; describe its shape |

   Public, generic facts stay: stack names, open-source libraries, error
   messages without identifiers, counts, timings.

4. Show the user the sanitized report and a list of what was redacted (by
   category and count, not the original values). Ask them to review it.

5. Share only on explicit approval, and only the way the user chooses:
   - they send the file themselves; or
   - open an issue with `gh issue create --repo ElderGil/goprod --title
     "Usage report: <stack>, <date>" --label usage-report --body-file
     <report>` (drop `--label` if it fails), or point them to the "Usage
     report" issue form on the repository.

   Opening an issue publishes the report; never do it without that approval.

## Rules

- The log and the report stay under `.goprod/`, excluded from git.
- Never paste raw log content into an issue; only the sanitized report.
- A report of "everything worked" with no evidence is not useful. If nothing
  broke, say what was exercised and what was not.
