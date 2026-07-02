#!/usr/bin/env bash
# dispatch.sh — launch a swarm of parallel agy (Antigravity CLI / Gemini) jobs.
#
# Each TASKFILE is a subtask prompt file. Its first line must be a model header:
#
#     MODEL: Gemini 3.1 Pro (High)
#
#     <the subtask prompt, any number of lines>
#
# All jobs are launched concurrently (no cap, no throttling) and waited on.
# Raw output is collected under LOG_ROOT/<ISO-timestamp>/ :
#
#     <name>.out      raw agy stdout
#     <name>.err      raw agy stderr
#     results.tsv     name <TAB> model <TAB> exit_code <TAB> duration_seconds
#
# A short per-job status table is printed to stdout (safe to read into an
# agent's context — raw Gemini output is NOT printed).
#
# Usage:
#   dispatch.sh [--auto | --request] [--timeout DUR] [--log-root DIR] TASKFILE...
#
#   --auto      run agy with --dangerously-skip-permissions --sandbox
#               (full autonomy inside agy's terminal-restricted sandbox)
#   --request   run agy without skipping permissions; agy's configured
#               toolPermission policy (e.g. request-review) governs.
#               Note: in non-interactive print mode there is no TTY to grant
#               approvals, so gated tool calls will not be auto-approved.
#   --timeout   passed to agy --print-timeout (default: 15m)
#   --log-root  where run directories are created (default: .gemini-swarm/logs)
#
# Exit code: 0 if every job succeeded, 1 otherwise.

set -u

MODE="auto"
TIMEOUT="15m"
LOG_ROOT=".gemini-swarm/logs"
TASKFILES=()

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --auto)     MODE="auto" ;;
    --request)  MODE="request" ;;
    --timeout)  shift; TIMEOUT="${1:?--timeout needs a value}" ;;
    --log-root) shift; LOG_ROOT="${1:?--log-root needs a value}" ;;
    -h|--help)  usage 0 ;;
    -*)         echo "dispatch.sh: unknown option: $1" >&2; usage 1 ;;
    *)          TASKFILES+=("$1") ;;
  esac
  shift
done

[ "${#TASKFILES[@]}" -gt 0 ] || { echo "dispatch.sh: no task files given" >&2; usage 1; }

command -v agy >/dev/null 2>&1 || {
  echo "dispatch.sh: 'agy' not found on PATH — install the Antigravity CLI first" >&2
  exit 1
}

TS="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
RUN_DIR="$LOG_ROOT/$TS"
mkdir -p "$RUN_DIR"

AGY_FLAGS=()
if [ "$MODE" = "auto" ]; then
  AGY_FLAGS+=(--dangerously-skip-permissions --sandbox)
fi

run_one() {
  # run_one NAME MODEL PROMPTFILE — executed in a background subshell per job
  local name="$1" model="$2" promptfile="$3"
  local start end rc
  start="$(date +%s)"
  agy --print "$(cat "$promptfile")" \
      --model "$model" \
      --print-timeout "$TIMEOUT" \
      "${AGY_FLAGS[@]+"${AGY_FLAGS[@]}"}" \
      > "$RUN_DIR/$name.out" 2> "$RUN_DIR/$name.err"
  rc=$?
  end="$(date +%s)"
  printf '%s\t%s\t%s\t%s\n' "$name" "$model" "$rc" "$((end - start))" \
    > "$RUN_DIR/$name.meta"
  return "$rc"
}

NAMES=()
PIDS=()
CLEANUP=()

for f in "${TASKFILES[@]}"; do
  [ -f "$f" ] || { echo "dispatch.sh: task file not found: $f" >&2; exit 1; }

  header="$(head -n 1 "$f")"
  case "$header" in
    MODEL:*|model:*|Model:*) ;;
    *) echo "dispatch.sh: $f: first line must be 'MODEL: <agy model name>'" >&2; exit 1 ;;
  esac
  model="$(printf '%s' "$header" | sed 's/^[Mm][Oo][Dd][Ee][Ll]:[[:space:]]*//')"
  [ -n "$model" ] || { echo "dispatch.sh: $f: empty MODEL header" >&2; exit 1; }

  name="$(basename "$f")"
  name="${name%.prompt.md}"; name="${name%.md}"; name="${name%.txt}"

  # strip the header (and one following blank line) into the prompt actually sent
  promptfile="$RUN_DIR/$name.prompt"
  tail -n +2 "$f" | sed '1{/^[[:space:]]*$/d;}' > "$promptfile"
  [ -s "$promptfile" ] || { echo "dispatch.sh: $f: prompt body is empty" >&2; exit 1; }
  CLEANUP+=("$promptfile")

  run_one "$name" "$model" "$promptfile" &
  PIDS+=($!)
  NAMES+=("$name")
  echo "dispatched: $name  [$model]  (pid $!)"
done

echo "waiting on ${#PIDS[@]} parallel agy job(s)..."

FAILED=0
for i in "${!PIDS[@]}"; do
  wait "${PIDS[$i]}" || FAILED=1
done

rm -f "${CLEANUP[@]+"${CLEANUP[@]}"}"

RESULTS="$RUN_DIR/results.tsv"
: > "$RESULTS"
echo ""
echo "run directory: $RUN_DIR"
printf '%-24s %-28s %-6s %s\n' "SUBTASK" "MODEL" "STATUS" "SECONDS"
for name in "${NAMES[@]}"; do
  if [ -f "$RUN_DIR/$name.meta" ]; then
    IFS=$'\t' read -r _ model rc secs < "$RUN_DIR/$name.meta"
  else
    model="?"; rc="?"; secs="?"
  fi
  cat "$RUN_DIR/$name.meta" >> "$RESULTS" 2>/dev/null || \
    printf '%s\t%s\t%s\t%s\n' "$name" "?" "?" "?" >> "$RESULTS"
  status="ok"; [ "$rc" = "0" ] || status="FAIL"
  printf '%-24s %-28s %-6s %s\n' "$name" "$model" "$status" "$secs"
done

exit "$FAILED"
