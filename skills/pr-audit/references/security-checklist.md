# Security coverage ledger

Use when a change touches a security-sensitive surface. It is a coverage
ledger, not a substitute for tracing the real data and authority flow. Mark
each applicable item: `reviewed (evidence)`, `finding`, or `N/A (reason)`.
Skip whole sections the project does not have (no web server → skip 6).

## 1. Map the flow
- Pin commit/range and deployment mode.
- List trust boundaries touched: public, authenticated, admin, internal, CI,
  plugin, dependency.
- Trace input → parse → validate → authorize → side effect → persist → output/log.
- Find alternate entry points (jobs, CLI, webhooks) that skip the main path.

## 2. Authentication
- Established library/protocol; signature verified before claims are read.
- Issuer, audience, expiry, algorithm validated; no unsigned/downgraded tokens.
- CSPRNG tokens; secrets never logged; constant-time comparison for fixed secrets.
- Expiry, rotation, revocation exist.

## 3. Authorization and tenancy
- Deny by default at one policy boundary.
- Every route/method/job/alternate protocol checks object ownership and tenant scope.
- Missing or ambiguous identity fails closed.
- No IDOR, mass assignment, self-promotion, check/use race.
- Counts, errors, timings, search results do not leak other tenants.

## 4. Input and injection
- Validate after decoding, at one typed boundary; bound sizes and depth.
- Parameterized queries; subprocess argv without shell.
- Output escaped for its exact context (HTML, URL, header, CSV, log, terminal).
- Paths constrained under canonical roots, symlinks handled.
- Archive extraction bounded; server-side fetch restricts scheme/host/private ranges.
- No unsafe deserialization.
- LLM prompts, retrieved text, tool output treated as data; tool permissions
  enforced outside the model.

## 5. Files, processes, plugins
- Least privilege; atomic temp files; no predictable paths.
- Subprocess time/output bounded; environment scrubbed.
- Build scripts, lifecycle hooks, macros, migrations treated as code execution.

## 6. Network and web
- Least exposed bind; auth before parsing expensive bodies; size/time/rate limits.
- CORS narrow; CSRF on cookie-authenticated mutations; secure cookie flags.
- Webhook signatures verified over raw bytes, replay prevented.
- No stack traces/secrets/internal URLs in responses; TLS verified.

## 7. Persistence and lifecycle
- Authorization inside the transaction boundary.
- Atomic writes where required; one ownership model for concurrent writers.
- Destructive operations explicit, scoped, audited, recoverable.
- Migrations: expand–contract; tested on representative data; restore tested.

## 8. Secrets and privacy
- No secrets in source, history, fixtures, logs, telemetry, command lines.
- Redaction before persistence/transport, including nested fields.
- Data minimization toward external providers (including LLM providers).

## 9. Cryptography
- Standard primitives; unique nonces; keys separated by purpose; authenticated
  encryption; no homemade formats or silent downgrades.

## 10. Availability and abuse
- Caps on sizes, counts, regex work, decompression, log cardinality.
- Timeouts, retry limits with backoff; no retry of non-idempotent side effects
  without dedupe.
- Rate limits on expensive auth/search/generation/upload paths.

## 11. Supply chain and CI
- Every new dependency explained; registry/source unchanged or justified.
- Lockfile, checksums, lifecycle hooks reviewed.
- CI permissions minimal; third-party actions pinned per policy.
- Untrusted PR code never runs with secrets or write tokens.
- Publish only exact tagged, tested commits.

## 12. Malicious-code leads (intent and reachability still to be proven)
- New network destinations, telemetry, uploads.
- Reads of credentials, home, browser, cloud metadata.
- eval/dynamic loading/downloaded execution; encoded blobs decoded at runtime.
- Bidi controls, homoglyphs, invisible conditions, minified code without source.
- Time/host/CI-triggered behavior; hidden accounts; static keys; debug bypasses.
- Persistence via startup files, cron, hooks, workflows.
- Disabling tests, logging, TLS, auth, sandboxing, limits.
- Tests or mocks that hide real side effects.

## 13. Evidence quality
- Reachability proven, not a grep hit.
- Attacker prerequisites stated.
- Legitimate control case tested alongside the attack case.
- Fix verified on the exact final commit.
- Residual risk stated; unknown is never reported as pass.
