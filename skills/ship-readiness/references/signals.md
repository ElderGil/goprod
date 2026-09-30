# Interpreting signals

`scripts/detect-signals.sh` reports leads. This file says how to confirm each
one cheaply and what a false positive looks like. Read only the rows you need.

## Confirmation reads by signal

| JSON key | Confirm by reading | Common false positive |
|---|---|---|
| `repo.host` | — | `other` may still be GitHub Enterprise; check the URL |
| `manifests` | the root manifest's scripts/tasks (test, build, lint) | monorepo: several manifests; assess root plus shipped components |
| `tests.test_file_count` | the test command in manifest/CI; one test file per business module | generated scaffolds; vendored tests |
| `tests.scenario_hints` | test files among the hits; names describing failure modes | hits in app code (retry logic), not in tests |
| `ci.files` | each workflow's `on:` block and the job steps | lint-only workflow; `workflow_dispatch` only |
| `ci.push_or_pr_triggers` | that the triggered job runs tests, not only builds | `branches:` filter excluding the default branch |
| `ci.dependency_bot` | config present → `dep-bump` skill applies | — |
| `deploy.containers` | Dockerfile builds the shipped app (not only dev) | dev-only compose files |
| `deploy.platform_config` | how a release is identified (tag, image, release ID) and whether previous ones are retained | Terraform for unrelated infra |
| `deploy.image_publish` | images/artifacts pushed with immutable tags (SHA or version), not only `latest` — the basis for rollback | `latest`-only pushes: previous version is overwritten |
| `deploy.rollback_hints` | a documented rollback command/runbook (searched only in CI, scripts, deploy config, and ops docs) | a doc that mentions rollback as a wish, not a procedure |
| `deploy.staging_hints` | a staging target in deploy config or CI promotion job | a `.env.staging` never used |
| `migrations` | the last few migration files | ORM schema file with no migration history |
| `feature_flags` | a flag client initialized in app code | a dependency listed but unused |
| `observability` | SDK initialized in production config; alert destination | SDK only in dev; a `/health` route nothing polls |
| `irreversible_effects.*` | live-mode calls in app code (not tests/fixtures) | test doubles, docs examples, sandbox-only keys |
| `distribution.publish_hints` | a publish step in CI or release script | `npm publish --dry-run` in a template |
| `distribution.package_json_private` | `true` → not a public npm package | — |
| `distribution.app_store` | fastlane lanes or store upload steps | Android dir for a local debug build only |
| `knowledge.*` | recency of entries | empty ADR template dir |
| `profile.*` | staleness drives refresh mode | — |

## Platform notes

- **GitHub + `gh` available:** use `gh run list`, `gh api repos/{o}/{r}/branches/{b}/protection` (may need admin; if it fails, mark branch protection `NOT VERIFIED`).
- **GitLab:** `glab` if installed; otherwise read `.gitlab-ci.yml` only and mark run history `NOT VERIFIED`.
- **No remote:** CI and hosted review are `MISSING` unless a local gate (pre-push hook, `make ci`) is documented and used; say that local-only gates depend on discipline.

## Stack-specific quick checks

| Stack | Test command source | Rollback idiom to look for |
|---|---|---|
| Node | `package.json` scripts | platform release history (Vercel/Netlify/Fly), image tags |
| Python | `pyproject.toml` / `tox.ini` / `noxfile.py` | image tags; platform releases |
| Ruby/Rails | `bin/ci`, `Rakefile`, CI yaml | Kamal `kamal rollback`, Heroku releases, Capistrano releases dir |
| Go/Rust | `Makefile`, CI yaml | versioned binaries/images; GitHub Releases |
| Mobile | fastlane, EAS | store phased rollout/halt; OTA update channels (Expo) — store review is `OUT OF OUR CONTROL` |
| Static site | build script | platform deploy history |
