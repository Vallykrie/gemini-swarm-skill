#!/usr/bin/env bash
# Validate the skills, bundled script copies and live model selection without
# calling the real agy (a fake agy stands in for it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
GUIDE="$ROOT/skills/gemini-swarm/references/models.md"

fail() {
  echo "check-repo: $*" >&2
  exit 1
}

[ -f "$GUIDE" ] || fail "missing model routing guide"
cmp -s "$GUIDE" "$ROOT/skills/gemini-imagegen/references/models.md" || \
  fail "standalone image routing guide differs from swarm guide"
cmp -s "$ROOT/scripts/dispatch.sh" "$ROOT/skills/gemini-swarm/scripts/dispatch.sh" || \
  fail "standalone dispatcher differs from source"
for copy in "$ROOT"/skills/gemini-swarm/scripts/list-models.sh \
            "$ROOT"/skills/gemini-imagegen/scripts/list-models.sh; do
  cmp -s "$ROOT/scripts/list-models.sh" "$copy" || fail "$copy differs from source"
done

for consumer in "$ROOT/skills/gemini-swarm/SKILL.md" "$ROOT/skills/gemini-imagegen/SKILL.md"; do
  grep -Fq 'references/models.md' "$consumer" || fail "$consumer lacks a routing guide link"
  grep -Fq 'list-models.sh' "$consumer" || fail "$consumer does not use the live model list"
done

# Model choice is live: no versioned model names or fixed profiles anywhere.
pattern='Gemini [0-9]+(\.[0-9]+)* [A-Z]|gemini-[0-9]+(\.[0-9]+)*-[a-z]|flash-high|resolve-model'
while IFS= read -r -d '' file; do
  if grep -EHn "$pattern" "$file"; then
    fail "$file hard-codes a model name or the retired profile resolver"
  fi
done < <(find "$ROOT/skills" "$ROOT/commands" "$ROOT/agents" "$ROOT/docs" "$ROOT/hooks" \
  "$ROOT/README.md" "$ROOT/CONTRIBUTING.md" "$ROOT/scripts/dispatch.sh" "$ROOT/scripts/list-models.sh" \
  -type f \( -name '*.md' -o -name '*.sh' \) -print0)

for script in "$ROOT"/scripts/*.sh "$ROOT"/skills/*/scripts/*.sh "$ROOT"/hooks/*.sh; do
  bash -n "$script"
done

# Exercise list-models.sh and dispatch.sh against a fake agy.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/agy" <<'FAKE'
#!/usr/bin/env bash
if [ "${1:-}" = "models" ]; then
  echo "Fetching available models..."
  printf 'gemini-9-pro-high\tGemini 9 Pro (High)\n'
  printf 'gemini-8.5-pro-high\tGemini 8.5 Pro (High)\n'
  printf 'gemini-9.1-flash-low\tGemini 9.1 Flash (Low)\n'
  printf 'gemini-9.1-flash-high\tGemini 9.1 Flash (High)\n'
  printf 'gemini-9.0-flash-high\tGemini 9.0 Flash (High)\n'
  printf 'other-model\tOther Model 2 (High)\n'
  exit 0
fi
model=""
while [ $# -gt 0 ]; do [ "$1" = "--model" ] && model="$2"; shift; done
echo "TOUCHED: none"
echo "ran on $model"
FAKE
chmod +x "$tmp/agy"
export PATH="$tmp:$PATH"

ids="$(bash "$ROOT/scripts/list-models.sh" --ids | cut -f1 | sort | tr '\n' ' ')"
[ "$ids" = "gemini-9-pro-high gemini-9.1-flash-high gemini-9.1-flash-low " ] || \
  fail "list-models kept the wrong models: $ids"
[ "$(bash "$ROOT/scripts/list-models.sh" --check 'Gemini 9 Pro (High)')" = "gemini-9-pro-high" ] || \
  fail "list-models --check does not accept display names"
bash "$ROOT/scripts/list-models.sh" --check gemini-9.0-flash-high 2>/dev/null && \
  fail "list-models --check accepted a superseded model"

work="$tmp/work"; mkdir -p "$work"
printf 'MODEL: gemini-9.1-flash-high\n\nSay hi.\n' > "$work/01-ok.prompt.md"
printf 'MODEL: gemini-8.5-pro-high\n\nSay hi.\n' > "$work/02-old.prompt.md"
(cd "$work" && bash "$ROOT/scripts/dispatch.sh" --log-root logs 01-ok.prompt.md >/dev/null) || \
  fail "dispatch rejected a current model"
grep -q 'ran on gemini-9.1-flash-high' "$work"/logs/*/01-ok.out || fail "dispatch passed the wrong model"
if (cd "$work" && bash "$ROOT/scripts/dispatch.sh" --log-root logs2 01-ok.prompt.md 02-old.prompt.md >/dev/null 2>&1); then
  fail "dispatch launched a superseded model"
fi
[ ! -d "$work/logs2" ] || [ -z "$(ls -A "$work/logs2")" ] || fail "refused dispatch left a run directory"

echo "check-repo: ok"
