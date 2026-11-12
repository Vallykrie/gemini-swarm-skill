#!/usr/bin/env bash
# list-models.sh — list the Gemini models agy can run right now, newest
# version of each family only.
#
# Usage:
#   list-models.sh            table for the orchestrator to choose from
#   list-models.sh --ids      one "id<TAB>display name" line per model
#   list-models.sh --check M  succeed if M (an id or display name) is a
#                             latest-version Gemini model; print its id
#
# The list comes from `agy models` at call time, so new releases show up
# without editing this repository. A "family" is the display name minus its
# version and thinking level ("Gemini <version> Flash (High)" -> Flash); for each
# family only the highest version is kept, so superseded models never appear.
#
# Environment:
#   AGY   agy binary to call (default: agy)
#
# Exit code: 0 on success, 1 if agy fails, lists no Gemini model, or --check
# rejects the model.

set -u

AGY="${AGY:-agy}"
FORMAT="table"
CHECK=""

case "${1:-}" in
  '') ;;
  --ids)   FORMAT="ids" ;;
  --check) FORMAT="check"; CHECK="${2:?--check needs a model id or name}" ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "list-models: unknown option: $1" >&2; exit 1 ;;
esac

command -v "$AGY" >/dev/null 2>&1 || {
  echo "list-models: '$AGY' not found on PATH — install the Antigravity CLI first" >&2
  exit 1
}

raw="$("$AGY" models 2>/dev/null)" || {
  echo "list-models: 'agy models' failed" >&2
  exit 1
}

# Parse "id<TAB>Gemini <version> <family> (<level>)" rows and keep the newest
# version per family. Output rows: id<TAB>name<TAB>version<TAB>family<TAB>level
latest="$(printf '%s\n' "$raw" | awk -F'\t' '
  function newer(a, b,   x, y, n, m, i) {
    n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
    for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) return 1; if (x[i] + 0 < y[i] + 0) return 0 }
    return 0
  }
  NF >= 2 && $2 ~ /^Gemini [0-9]+(\.[0-9]+)* / {
    id = $1; name = $2; gsub(/^[ \t]+|[ \t]+$/, "", id); gsub(/^[ \t]+|[ \t]+$/, "", name)
    rest = substr(name, 8)                       # after "Gemini "
    version = rest; sub(/ .*/, "", version)
    family = substr(rest, length(version) + 2)
    level = ""
    if (match(family, / \([^)]*\)$/)) {
      level = substr(family, RSTART + 2, RLENGTH - 3)
      family = substr(family, 1, RSTART - 1)
    }
    n++; ids[n] = id; names[n] = name; vers[n] = version; fams[n] = family; lvls[n] = level
    if (!(family in best) || newer(version, best[family])) best[family] = version
  }
  END {
    for (i = 1; i <= n; i++)
      if (vers[i] == best[fams[i]])
        printf "%s\t%s\t%s\t%s\t%s\n", ids[i], names[i], vers[i], fams[i], lvls[i]
  }')"

[ -n "$latest" ] || { echo "list-models: agy lists no Gemini models" >&2; exit 1; }

case "$FORMAT" in
  ids)
    printf '%s\n' "$latest" | cut -f1,2
    ;;
  check)
    id="$(printf '%s\n' "$latest" | awk -F'\t' -v m="$CHECK" '$1 == m || $2 == m { print $1; exit }')"
    if [ -n "$id" ]; then
      printf '%s\n' "$id"
      exit 0
    fi
    if printf '%s\n' "$raw" | awk -F'\t' -v m="$CHECK" '$1 == m || $2 == m { f = 1 } END { exit !f }'; then
      echo "list-models: '$CHECK' is in agy but is not a newest-version Gemini model; choose one of:" >&2
    else
      echo "list-models: '$CHECK' is not available in agy; choose one of:" >&2
    fi
    printf '%s\n' "$latest" | cut -f1 | sed 's/^/  /' >&2
    exit 1
    ;;
  table)
    printf '%-28s %-10s %-14s %s\n' "MODEL ID" "VERSION" "FAMILY" "THINKING"
    printf '%s\n' "$latest" | awk -F'\t' '{ printf "%-28s %-10s %-14s %s\n", $1, $3, $4, ($5 == "" ? "-" : $5) }'
    ;;
esac
