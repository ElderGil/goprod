#!/usr/bin/env bash
# Read-only signal inventory for ship-readiness. Prints one small JSON object.
# The agent interprets the signals; this script never decides a status.
# Portable to macOS bash 3.2 (no associative arrays, no mapfile).
set -uo pipefail

ROOT="${1:-.}"
if [[ ! -d "$ROOT" ]]; then
  printf 'detect-signals: not a directory: %s\n' "$ROOT" >&2
  exit 64
fi
cd "$ROOT" || exit 66

LIMIT=15
PRUNE='-name .git -o -name node_modules -o -name vendor -o -name dist -o -name build -o -name target -o -name .venv -o -name venv -o -name coverage -o -name .next -o -name Pods -o -name .terraform'
EXCLUDES=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor
  --exclude-dir=dist --exclude-dir=build --exclude-dir=target --exclude-dir=.venv
  --exclude-dir=venv --exclude-dir=coverage --exclude-dir=.next --exclude-dir=Pods
  --exclude-dir=.terraform --exclude='*.md' --exclude='*.lock' --exclude='*-lock.json'
  --exclude='*.min.js' --exclude='*.map' --exclude='*.svg' --exclude='*.css'
  --exclude='*.scss' --exclude='LICENSE*' --exclude='*.po' --exclude='*.pot')

# find_files <find predicates...>  -> newline list of paths (bounded)
find_files() {
  # shellcheck disable=SC2086
  find . \( $PRUNE \) -prune -o \( "$@" \) -print 2>/dev/null | sed 's|^\./||' | sort | head -n "$LIMIT"
}

# grep_files <regex> [paths...] -> files containing the regex (case-insensitive, bounded)
# With paths, searches only those that exist (used to keep domain code out of
# infra-only signals such as rollback or staging).
grep_files() {
  local re="$1"; shift
  local targets=() p
  if [[ $# -eq 0 ]]; then
    targets=(.)
  else
    for p in "$@"; do [[ -e "$p" ]] && targets+=("$p"); done
    [[ ${#targets[@]} -eq 0 ]] && return 0
  fi
  grep -rIilE "${EXCLUDES[@]}" -- "$re" "${targets[@]}" 2>/dev/null | sed 's|^\./||' | sort | head -n "$LIMIT"
}

# Infra/ops locations: CI, scripts, deploy config, ops docs.
# Docs are searched separately because EXCLUDES drops *.md.
OPS_PATHS=(.github .gitlab-ci.yml .circleci Jenkinsfile bin script scripts deploy
  config/deploy.yml config/deploy Makefile Justfile Procfile fly.toml render.yaml
  vercel.json netlify.toml k8s helm charts infra ops terraform .kamal)
ops_docs() { # ops_docs <regex> -> README/docs/runbooks mentioning it
  find . \( $PRUNE \) -prune -o -type f \( -iname 'README*' -o -iname 'RUNBOOK*' -o -iname 'DEPLOY*' -o -iname 'CONTRIBUTING*' -o -path './docs/*.md' -o -name AGENTS.md -o -name CLAUDE.md \) -print0 2>/dev/null \
    | xargs -0 grep -IilE -- "$1" 2>/dev/null | sed 's|^\./||' | sort | head -n "$LIMIT"
}

json_escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g'; }

# json_array <newline list> -> ["a","b"]
json_array() {
  local out="" line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line=$(printf '%s' "$line" | json_escape)
    out="${out:+$out,}\"$line\""
  done <<< "$1"
  printf '[%s]' "$out"
}

json_str() { printf '"%s"' "$(printf '%s' "$1" | json_escape)"; }

FIRST=1
emit() { # emit <key> <raw-json-value>
  if [[ $FIRST -eq 1 ]]; then FIRST=0; printf '{\n'; else printf ',\n'; fi
  printf '  "%s": %s' "$1" "$2"
}

# --- Repository -------------------------------------------------------------
IS_GIT=false; REMOTE=""; DEFAULT_BRANCH=""; LAST_COMMIT=""; TAGS=""; LATEST_TAG=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT=true
  REMOTE=$(git remote get-url origin 2>/dev/null || true)
  DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
  LAST_COMMIT=$(git log -1 --format=%cs 2>/dev/null || true)
  TAGS=$(git tag 2>/dev/null | wc -l | tr -d ' ')
  LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
fi
HOST="none"
case "$REMOTE" in
  *github.com*) HOST="github" ;;
  *gitlab*) HOST="gitlab" ;;
  *bitbucket*) HOST="bitbucket" ;;
  "") HOST="none" ;;
  *) HOST="other" ;;
esac
GH=false; command -v gh >/dev/null 2>&1 && GH=true

emit repo "{\"git\": $IS_GIT, \"host\": $(json_str "$HOST"), \"default_branch\": $(json_str "$DEFAULT_BRANCH"), \"last_commit\": $(json_str "$LAST_COMMIT"), \"tag_count\": ${TAGS:-0}, \"latest_tag\": $(json_str "$LATEST_TAG"), \"gh_cli\": $GH}"

# --- Stack --------------------------------------------------------------------
emit manifests "$(json_array "$(find_files -name package.json -o -name Cargo.toml -o -name pyproject.toml -o -name setup.py -o -name go.mod -o -name Gemfile -o -name '*.gemspec' -o -name pom.xml -o -name 'build.gradle*' -o -name '*.csproj' -o -name mix.exs -o -name composer.json -o -name pubspec.yaml -o -name Package.swift)")"
emit lockfiles "$(json_array "$(find_files -name package-lock.json -o -name yarn.lock -o -name pnpm-lock.yaml -o -name bun.lockb -o -name Cargo.lock -o -name poetry.lock -o -name uv.lock -o -name Pipfile.lock -o -name go.sum -o -name Gemfile.lock -o -name composer.lock -o -name mix.lock -o -name pubspec.lock)")"

# --- Tests --------------------------------------------------------------------
TEST_FILES=$(find . \( $PRUNE \) -prune -o -type f \( -name '*_test.*' -o -name '*.test.*' -o -name '*_spec.*' -o -name '*.spec.*' -o -name 'test_*.py' -o -name '*Test.java' -o -name '*Tests.cs' -o -name '*_test.go' \) -print 2>/dev/null | wc -l | tr -d ' ')
emit tests "{\"test_file_count\": ${TEST_FILES:-0}, \"test_dirs\": $(json_array "$(find_files -type d \( -name test -o -name tests -o -name spec -o -name __tests__ -o -name e2e -o -name integration \))"), \"scenario_hints\": $(json_array "$(grep_files 'concurren|race condition|partial failure|crash|kill -9|timeout|idempoten|deadlock|chaos|fault inject' test tests spec __tests__ e2e integration src/test)")}"

# --- CI -----------------------------------------------------------------------
CI_FILES=$(find_files -path './.github/workflows/*' -o -name .gitlab-ci.yml -o -path './.circleci/config.yml' -o -name Jenkinsfile -o -name azure-pipelines.yml -o -name bitbucket-pipelines.yml -o -path './.buildkite/*' -o -name .travis.yml -o -path './.woodpecker*')
CI_PUSH=""
if [[ -n "$CI_FILES" ]]; then
  CI_PUSH=$(while IFS= read -r f; do [[ -f "$f" ]] && grep -lE '(^|[^a-z_])(push|pull_request|merge_request|branches)' "$f" 2>/dev/null; done <<< "$CI_FILES")
fi
emit ci "{\"files\": $(json_array "$CI_FILES"), \"push_or_pr_triggers\": $(json_array "$CI_PUSH"), \"dependency_bot\": $(json_array "$(find_files -path './.github/dependabot.yml' -o -path './.github/dependabot.yaml' -o -name renovate.json -o -name .renovaterc -o -name renovate.json5)")}"

# --- Deploy, containers, rollback --------------------------------------------
emit deploy "{\"containers\": $(json_array "$(find_files -name 'Dockerfile*' -o -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' -o -name Chart.yaml -o -name kustomization.yaml)"), \"platform_config\": $(json_array "$(find_files -name fly.toml -o -name render.yaml -o -name vercel.json -o -name netlify.toml -o -name Procfile -o -name app.yaml -o -name 'serverless.y*ml' -o -name '*.tf' -o -path './config/deploy*.yml' -o -name railway.json -o -name wrangler.toml)"), \"image_publish\": $(json_array "$(grep_files 'docker push|build-push-action|ghcr\.io|ecr|gcr\.io|registry\.fly|kamal deploy|helm upgrade' "${OPS_PATHS[@]}")"), \"rollback_hints\": $(json_array "$( { grep_files 'rollback|roll back|previous release|blue.?green|canary|releases:rollback|helm rollback|fly releases' "${OPS_PATHS[@]}"; ops_docs 'rollback|roll back|revert (the|a) deploy|previous release'; } | sort -u | head -n "$LIMIT")"), \"staging_hints\": $(json_array "$( { grep_files 'staging|preview environment|pre-?prod|homolog' "${OPS_PATHS[@]}"; ops_docs 'staging|pre-?prod|homolog'; find_files -name '.env.staging*' -o -path './config/environments/staging.rb'; } | sort -u | head -n "$LIMIT")")}"

# --- Persisted state ---------------------------------------------------------
emit migrations "$(json_array "$(find_files -type d \( -name migrations -o -name migrate -o -name alembic -o -name flyway -o -name liquibase \) -o -path './prisma/schema.prisma' -o -name 'V1__*.sql')")"

# --- Flags, observability ----------------------------------------------------
emit feature_flags "$(json_array "$(grep_files 'launchdarkly|unleash|flipper|growthbook|flagsmith|configcat|openfeature|split\.io|posthog.*feature|feature_?flag|isFeatureEnabled|feature_enabled')")"
emit observability "$(json_array "$(grep_files 'sentry|datadog|dd-trace|ddtrace|newrelic|new_relic|honeybadger|bugsnag|rollbar|opentelemetry|prometheus|appsignal|skylight|scout_apm|logtail|betterstack|grafana|healthz|health_check|healthcheck|rails/health')")"

# --- Blast radius / irreversibility ------------------------------------------
emit irreversible_effects "{\"payments\": $(json_array "$(grep_files 'stripe|paypal|adyen|braintree|mercadopago|pagar\.me|pagarme|pagseguro|asaas|iugu|\bpix\b|checkout session|payment_intent')"), \"outbound_messages\": $(json_array "$(grep_files 'twilio|sendgrid|mailgun|postmark|amazon ses|aws-sdk.*ses|smtp|resend|push notification|fcm|apns|whatsapp')"), \"health_or_regulated\": $(json_array "$(grep_files 'fhir|hl7|hipaa|\blgpd\b|gdpr|pci[- ]dss|prontu|patient|paciente|anvisa')"), \"physical_devices\": $(json_array "$(grep_files 'modbus|mqtt|gpio|serialport|plc|opc-?ua|bluetooth')")}"

# --- Distribution ------------------------------------------------------------
PUBLISH=$(grep_files 'npm publish|gem push|twine upload|cargo publish|poetry publish|uv publish|mvn deploy|dotnet nuget push|goreleaser|semantic-release|changesets')
PRIVATE_PKG=false
[[ -f package.json ]] && grep -qE '"private"[[:space:]]*:[[:space:]]*true' package.json && PRIVATE_PKG=true
emit distribution "{\"publish_hints\": $(json_array "$PUBLISH"), \"package_json_private\": $PRIVATE_PKG, \"app_store\": $(json_array "$(find_files -type d -name fastlane -o -name eas.json -o -path './android/app/build.gradle*' -o -name '*.xcodeproj' -o -name pubspec.yaml)")}"

# --- Knowledge and specs -----------------------------------------------------
emit knowledge "{\"changelog\": $(json_array "$(find_files -iname 'CHANGELOG*' -o -iname 'HISTORY*' -o -iname 'NEWS*')"), \"decision_records\": $(json_array "$(find_files -type d \( -iname adr -o -iname adrs -o -iname decisions \) -o -iname 'ADR-*.md')"), \"agent_files\": $(json_array "$(find_files -name AGENTS.md -o -name CLAUDE.md -o -name .cursorrules -o -name GEMINI.md)"), \"spec_kit_constitution\": $(json_array "$(find_files -path './.specify/memory/constitution.md')"), \"spec_dirs\": $(json_array "$(find_files -path ./specs -type d)")}"

# --- Existing profile and staleness ------------------------------------------
PROFILE="docs/ship-readiness.md"
PROFILE_DATE=""; CHANGED=""
if [[ -f "$PROFILE" ]]; then
  PROFILE_DATE=$(sed -n 's/^[Ll]ast [Aa]ssessed:[[:space:]]*\([0-9-]*\).*/\1/p' "$PROFILE" | head -n 1)
  if [[ "$IS_GIT" == true && -n "$PROFILE_DATE" ]]; then
    CHANGED=$(git log --since="$PROFILE_DATE" --name-only --format= -- \
      .github/workflows .gitlab-ci.yml .circleci Jenkinsfile 'Dockerfile*' '*compose*.y*ml' \
      fly.toml render.yaml vercel.json netlify.toml Procfile '*.tf' config/deploy.yml \
      2>/dev/null | sort -u | head -n "$LIMIT")
  fi
fi
emit profile "{\"exists\": $([[ -f $PROFILE ]] && echo true || echo false), \"last_assessed\": $(json_str "$PROFILE_DATE"), \"infra_files_changed_since\": $(json_array "$CHANGED")}"

printf '\n}\n'
