<!--
Paste into .specify/memory/constitution.md as a principle section (or into the
canonical AGENTS.md/CLAUDE.md when the project does not use Spec Kit).
Keep it short: rules only. Evidence and state live in docs/ship-readiness.md.
Delete the lines that do not apply to this project's tier before pasting.
-->

### Delivery Safety (Tier T<n>)

Evidence and gate commands: `docs/ship-readiness.md`. The tier reflects the
cost of an error in this domain and applies equally to code written by humans
and by agents.

- Every change MUST pass `<full gate command>` locally and hosted CI on the
  exact SHA before merge; pending or skipped jobs are not passing.
- A release MUST be revertible with `<rollback command>`. A change that cannot
  be reverted this way (data migration, external effect) MUST say how it is
  undone or contained in its plan.
- [T2+ with database] Schema changes MUST follow expand–contract: add the new
  shape, migrate consumers, remove the old shape in a later release. No drop or
  rename ships together with the code that stops using it.
- [T2+ public contract] Version comes from the changelog category: fix → patch,
  additive → minor, breaking → major. Breaking changes never ship in a patch
  or minor.
- [T3] Every spec touching `<irreversible paths>` MUST include the "Risk &
  failure modes" section; every identified failure mode MUST have a scenario
  test and at least two independent controls, plus a kill switch that works
  without a deploy.
- [User-facing, T2+] Behavior changes reach users behind a flag; each flag has
  a removal task.
- Plan gate: if `docs/ship-readiness.md` is missing, or CI/deploy/infra files
  changed after its `Last assessed` date, the plan MUST flag it and recommend
  running `ship-readiness` before implementation.
