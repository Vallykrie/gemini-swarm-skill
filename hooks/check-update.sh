#!/usr/bin/env bash
# check-update.sh — SessionStart hook: warn when a newer gemini-swarm plugin
# version is published.
#
# Checks at most once per GEMINI_SWARM_UPDATE_TTL seconds (default: 86400).
# Never fails the session: network or parse problems produce no output.
# Set GEMINI_SWARM_NO_UPDATE_CHECK=1 or GEMINI_SWARM_OFFLINE=1 to disable.

set -u

[ "${GEMINI_SWARM_NO_UPDATE_CHECK:-0}" = "1" ] && exit 0
[ "${GEMINI_SWARM_OFFLINE:-0}" = "1" ] && exit 0

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}"
MANIFEST_URL="${GEMINI_SWARM_MANIFEST_URL:-https://raw.githubusercontent.com/Vallykrie/gemini-swarm-skill/main/.claude-plugin/plugin.json}"
CACHE_DIR="${GEMINI_SWARM_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/gemini-swarm}"
TTL="${GEMINI_SWARM_UPDATE_TTL:-86400}"
LATEST="$CACHE_DIR/latest-version"

# version_of FILE — the "version" field of a plugin manifest
version_of() {
  sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1
}

# newer A B — succeed if dotted version A is greater than B
newer() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
    for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
    exit 1 }'
}

installed="$(version_of "$PLUGIN_ROOT/.claude-plugin/plugin.json")"
[ -n "$installed" ] || exit 0

age=999999999
if mtime="$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)"; then
  age=$(( $(date +%s) - mtime ))
fi

if [ "$age" -ge "$TTL" ] && command -v curl >/dev/null 2>&1 && mkdir -p "$CACHE_DIR" 2>/dev/null; then
  tmp="$(mktemp "$CACHE_DIR/plugin.json.XXXXXX")" || exit 0
  if curl -fsSL --max-time 4 --max-filesize 16384 "$MANIFEST_URL" -o "$tmp" 2>/dev/null; then
    remote="$(version_of "$tmp")"
    [ -n "$remote" ] && printf '%s\n' "$remote" > "$LATEST"
  fi
  rm -f "$tmp"
fi

latest="$(head -n 1 "$LATEST" 2>/dev/null)"
printf '%s' "$latest" | grep -Eq '^[0-9]+(\.[0-9]+)*$' || exit 0
newer "$latest" "$installed" || exit 0

msg="gemini-swarm $latest is available (installed: $installed). Update with: claude plugin marketplace update gemini-swarm-skill && claude plugin update gemini-swarm@gemini-swarm-skill, then run /reload-plugins. Model choice already follows agy's live model list; the update brings new skill instructions."
printf '{"systemMessage": "%s", "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "%s"}}\n' "$msg" "$msg"
