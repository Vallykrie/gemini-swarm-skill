---
description: Swarm a task across parallel Gemini (agy) sessions with automatic decomposition and model routing
argument-hint: [default|auto|request] [task...]
---

Run the **gemini-swarm** skill (`skills/gemini-swarm/SKILL.md` in this plugin —
read it now and follow it exactly).

Arguments given: `$ARGUMENTS`

Interpret them as follows:

- If the first word is `default`, `auto`, or `request`, that is the **autonomy
  mode**; everything after it is the task description.
- Otherwise the mode is `default` and the whole argument string is the task.
- Mode meanings (details in the skill's Step 1):
  - `default` — mirror your own current permission mode: auto-accept host →
    dispatch with `--auto`; review-mode host → dispatch with `--request`.
  - `auto` — always dispatch with `--auto` (agy runs sandboxed, permissions
    skipped).
  - `request` — always dispatch with `--request`.

If no task description remains, treat the mode as set for this conversation,
confirm it in one line, and apply it when the user gives the next swarmable
task. Do not ask which model to use for any subtask — routing is your job.

Decompose the task, route models, dispatch all subtasks in parallel via the
`gemini-dispatcher` subagent (it calls `${CLAUDE_PLUGIN_ROOT}/scripts/dispatch.sh`),
auto-accept the results, ensure the run log exists at
`.gemini-swarm/logs/<ISO-timestamp>.md`, then integrate and report.
