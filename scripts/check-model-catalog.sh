#!/usr/bin/env bash
# Validate routing policy and standalone installation assets without calling agy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
CATALOG="$ROOT/skills/gemini-swarm/references/models.md"

fail() {
  echo "check-model-catalog: $*" >&2
  exit 1
}

[ -f "$CATALOG" ] || fail "missing model catalog"
# There must be exactly one active route, targeting Flash with High thinking.
[ "$(grep -c '^| `' "$CATALOG")" -eq 1 ] || fail "expected one active profile"
grep -Eq '^\| `flash-high` \| `Gemini [0-9]+\.[0-9]+ Flash \(High\)` \|' "$CATALOG" || \
  fail "flash-high must target a High-thinking Flash model"

cmp -s "$CATALOG" "$ROOT/skills/gemini-imagegen/references/models.md" || \
  fail "standalone image catalog differs from swarm catalog"
cmp -s "$ROOT/scripts/dispatch.sh" "$ROOT/skills/gemini-swarm/scripts/dispatch.sh" || \
  fail "standalone dispatcher differs from source"

for consumer in "$ROOT/skills/gemini-swarm/SKILL.md" \
                "$ROOT/skills/gemini-imagegen/SKILL.md" "$ROOT/README.md"; do
  grep -Fq 'references/models.md' "$consumer" || fail "$consumer lacks a catalog link"
  grep -Fq 'flash-high' "$consumer" || fail "$consumer lacks the active profile"
done

# Model versions belong in catalogs, not executable examples or routing prose.
while IFS= read -r -d '' file; do
  case "$file" in */references/models.md) continue ;; esac
  if grep -En 'Gemini [0-9]+\.[0-9]+ (Flash|Pro)|pro-high|flash-medium|flash-low' "$file"; then
    fail "$file contains a hard-coded model or retired profile"
  fi
done < <(find "$ROOT/skills" "$ROOT/commands" "$ROOT/agents" "$ROOT/docs" \
  -type f \( -name '*.md' -o -name '*.sh' \) -print0)
if grep -En 'Gemini [0-9]+\.[0-9]+ (Flash|Pro)|pro-high|flash-medium|flash-low' "$ROOT/README.md" "$ROOT/scripts/dispatch.sh"; then
  fail "README or dispatcher contains a hard-coded model or retired profile"
fi

for script in "$ROOT"/scripts/*.sh "$ROOT"/skills/gemini-swarm/scripts/*.sh; do
  bash -n "$script"
done

echo "check-model-catalog: ok"
