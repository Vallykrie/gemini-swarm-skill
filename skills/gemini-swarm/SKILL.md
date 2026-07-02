---
name: gemini-swarm
description: Decompose a task into independent subtasks, dispatch them to parallel Gemini sessions via the agy (Antigravity) CLI, and integrate the results. Use when the user asks to swarm/fan out/parallelize work across Gemini, invokes /gemini-swarm, or when a task splits cleanly into independent token-heavy chunks (bulk edits, migrations, multi-topic research, boilerplate generation) that Gemini can execute while you plan and review.
---

# gemini-swarm

You are the **orchestrator**: you plan, decompose, route, and review. Parallel
`agy` (Antigravity CLI) sessions running Gemini do the token-heavy bulk work.

Verified against agy **1.0.15**. Re-check `agy --help` if flags seem wrong —
this CLI changes fast.

## Step 0 — Preflight

1. `command -v agy` — if missing, stop and tell the user to install the
   Antigravity CLI.
2. Locate the dispatcher script, in this order:
   - `${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh` (plugin install)
   - `scripts/dispatch.sh` next to this SKILL.md (standalone skill install)

## Step 1 — Resolve the autonomy mode

The `/gemini-swarm` command (or the user directly) supplies one of three modes.
If none was given, use `default`.

| Mode | Dispatch flag | Meaning |
|------|---------------|---------|
| `default` | mirror the host | If you (the host agent) are currently running with auto-accepted/bypassed permissions, use `--auto`. If your own edits require user review, use `--request`. |
| `auto` | `--auto` | agy jobs run with `--dangerously-skip-permissions --sandbox` — full autonomy inside agy's terminal-restricted sandbox. |
| `request` | `--request` | agy jobs never skip permissions; agy's configured `toolPermission` policy (`request-review`) governs gated tool calls. |

Never ask the user to pick a mode mid-run; resolve it yourself from the rule
above.

## Step 2 — Decompose the task

Split the task into **independent** subtasks:

- No two subtasks may write the same file or depend on each other's output.
  Prefer splits along existing boundaries: different files, modules,
  directories, or research topics.
- If a task has a genuinely sequential core, keep that core for yourself and
  swarm only the independent parts.
- Each subtask prompt must be **fully self-contained**. The Gemini sessions
  share nothing — no conversation history, no knowledge of the other subtasks.
  Include in every prompt: the goal, the exact file paths to read/write,
  relevant constraints/conventions, and the expected output format.
- For write tasks, tell each subtask exactly which files it owns and to touch
  nothing else. End each prompt with: "When done, print a line starting with
  `TOUCHED:` listing every file you created or modified, then a one-paragraph
  summary of what you did."
- Typical fan-out is 2–10 subtasks. Do not throttle or batch: quota is not a
  constraint, and all subtasks launch concurrently.

## Step 3 — Route a model per subtask

Choose per subtask, automatically — never ask the user which model:

- **`Gemini 3.1 Pro (High)`** — reasoning-heavy or ambiguous work: debugging,
  architecture, tricky refactors, analysis with judgment calls, anything where
  a wrong answer is expensive.
- **`Gemini 3.5 Flash`** — bulk, boilerplate, or mechanical work: mass
  renames, format conversions, test scaffolding, doc generation, summarizing
  files, straightforward CRUD. Use the exact string `Gemini 3.5 Flash (High)`
  for mechanical-but-fiddly work and `Gemini 3.5 Flash (Medium)` for plain
  bulk work.

These are exact `agy models` names — pass them verbatim to the `MODEL:` header.

## Step 4 — Write the subtask files

Create one prompt file per subtask in a temp directory (e.g.
`$(mktemp -d)/01-slug.prompt.md`). Format — first line is a model header,
then a blank line, then the prompt:

```
MODEL: Gemini 3.5 Flash (Medium)

Summarize the public API of src/parser/ ...
```

Name files `NN-short-slug.prompt.md`; the basename (minus `.prompt.md`)
becomes the subtask name in logs.

## Step 5 — Dispatch (always parallel)

**If the `gemini-dispatcher` subagent is available** (plugin install), delegate
to it: pass the task-file paths, the mode flag, and the project root. It runs
the script, waits, writes the run log, and returns only a summary — keeping
raw Gemini output out of your context.

**Otherwise**, run the script yourself from the project root:

```bash
bash <dispatcher>/dispatch.sh --auto 01-foo.prompt.md 02-bar.prompt.md ...
```

(substitute `--request` per Step 1; add `--timeout 30m` for long jobs).

The script launches every job concurrently with `&` + `wait` — never loop over
subtasks sequentially, never cap concurrency. Its stdout is a short status
table (subtask, model, ok/FAIL, seconds) plus the run directory path — safe to
read. **Do not** cat the raw `.out` files wholesale into your context; read
them selectively when integrating.

## Step 6 — Write the run log

After all jobs finish, write `.gemini-swarm/logs/<ISO-timestamp>.md` (same
timestamp as the run directory the script printed). If the dispatcher subagent
ran, it writes this log. Template:

```markdown
# gemini-swarm run <ISO-timestamp>

<One plain-English paragraph: what the task was, how it was split, what
succeeded/failed, and total wall-clock time.>

- **Mode**: auto | request (how it was resolved)
- **Wall-clock**: NNs total

## Subtasks

### 01-short-slug — ok | FAIL
- **Model**: Gemini 3.5 Flash (Medium)
- **Duration**: NNs
- **Files/artifacts touched**: `path/a`, `path/b` (from the TOUCHED: line;
  "none" for research tasks — note the .out artifact instead)
- **Result**: one or two sentences from the subtask summary.
```

## Step 7 — Integrate and finish

- **Auto-accept** the swarm's output. Do not gate on a diff-review step — the
  run log is the audit trail.
- Verify integration-level correctness yourself (build/tests if relevant),
  fix small seams between subtask outputs, and only re-dispatch a subtask if
  it hard-failed (non-zero exit).
- Report to the user: the one-paragraph summary, per-subtask pass/fail, and
  the log file path.
