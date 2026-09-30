<!--
Add to the Spec Kit spec template (.specify/templates/spec-template.md) and
fill per feature. Depth follows the project tier in docs/ship-readiness.md:
T0/T1 → answer the five questions in one line each; T2 → full table for the
stateful/public parts; T3 → full table, every row with two controls.
-->

## Risk & Failure Modes

**Tier (from docs/ship-readiness.md):** T<n>

1. **Irreversible effects:** Does this feature cause an effect a redeploy cannot
   undo (money, messages, devices, records)? <no | which>
2. **Persisted state:** Does it change schema or transform existing data?
   <no | expand step / contract step, in which releases>
3. **External consumers:** Does it change a public API/CLI/package surface?
   <no | additive | breaking → major>
4. **Rollback path:** How is this change undone in production, and what does
   rollback NOT undo? <command + limits>
5. **Blast radius:** Who sees it first? <flag name + initial audience | all users, because …>

### Failure modes (T2 for stateful parts; always at T3)

| Failure mode | Trigger | Consequence | Control 1 | Control 2 | Scenario test |
|---|---|---|---|---|---|
| e.g. duplicate charge | client retry after timeout | customer billed twice | idempotency key on provider call | nightly reconciliation alert | `test_retry_after_timeout_charges_once` |

### Tasks this section generates (for /tasks)

- Regression/scenario tests for each failure mode, written before the code.
- Flag creation task and a scheduled flag removal task.
- Expand and contract as separate tasks (and separate releases when data moves).
