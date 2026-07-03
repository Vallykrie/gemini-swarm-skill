# gemini-swarm

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Vallykrie/gemini-swarm-skill?style=social)](https://github.com/Vallykrie/gemini-swarm-skill/stargazers)
[![GitHub last commit](https://img.shields.io/github/last-commit/Vallykrie/gemini-swarm-skill)](https://github.com/Vallykrie/gemini-swarm-skill/commits/main)

**Gemini does the writing. Your orchestrator plans and reviews.** gemini-swarm is a Claude Code plugin/skill (portable to other harnesses) that makes Gemini the *default* writer for substantial work: whenever a task means writing more than a trivial amount of code or content, the orchestrator splits it into subtasks, fans each one out to a live `agy` (Antigravity CLI) session running the right Gemini model, and integrates the results — all while its own context stays clean. It also ships **gemini-imagegen**, a skill that generates real images through Gemini's `generate_image` tool — something Claude cannot do on its own.

<!-- Demo: docs/demo.gif or an asciinema cast showing `/gemini-swarm auto` fanning out and returning a run log. -->

Concretely, the orchestrator:

1. **Decomposes** a task into independent subtasks (different files, modules, or research topics — no shared-state conflicts),
2. **Routes** each subtask to the right Gemini model via the [Antigravity CLI](https://antigravity.google) (`agy`) — reasoning-heavy work to `Gemini 3.1 Pro (High)`, bulk/mechanical work to `Gemini 3.5 Flash`,
3. **Dispatches** all subtasks in parallel `agy` sessions, and
4. **Integrates** the results, writing a run log to `.gemini-swarm/logs/`.

The orchestrator model does planning and review; Gemini does the token-heavy bulk work.

## Requirements

- [`agy`](https://antigravity.google) (Antigravity CLI) on your `PATH`, logged in. Built and tested against agy **1.0.15**.
- Your project directory must be a trusted workspace in agy (run `agy` once interactively in the directory to trust it).
- Bash (the dispatcher is a plain shell script).

## Install

### Claude Code — as a plugin (recommended)

```
/plugin marketplace add Vallykrie/gemini-swarm-skill
/plugin install gemini-swarm@gemini-swarm-skill
```

This gives you both skills (gemini-swarm, gemini-imagegen), the `/gemini-swarm` and `/gemini-imagegen` commands, and the `gemini-dispatcher` subagent.

### Claude Code — as a plain skill (zero plugin machinery)

Copy the skill folder into your personal skills directory:

```bash
git clone https://github.com/Vallykrie/gemini-swarm-skill
cp -r gemini-swarm-skill/skills/gemini-swarm ~/.claude/skills/
cp -r gemini-swarm-skill/skills/gemini-imagegen ~/.claude/skills/
```

The skill folders are self-contained: each `SKILL.md` holds the full playbook, and gemini-swarm's bundled `scripts/dispatch.sh` is the only dependency.

### Other harnesses (Codex CLI, OpenCode, Antigravity CLI)

The core logic is one Markdown playbook (`skills/gemini-swarm/SKILL.md`) plus one shell script. See [`docs/harnesses.md`](docs/harnesses.md) for thin adapter instructions per harness.

## Usage

In Claude Code:

```
/gemini-swarm                 # same as "default"
/gemini-swarm default         # mirror the host agent's current permission mode
/gemini-swarm auto            # force full autonomy (sandboxed) for all agy jobs
/gemini-swarm request         # force request-review for all agy jobs
```

Then just describe the task:

> /gemini-swarm auto
> Port every module under `src/legacy/` to TypeScript and write a migration report.

The orchestrator splits the work into independent subtasks, assigns a model per subtask (never asking you which), launches all of them concurrently, auto-accepts the results, and writes a run log.

You don't need to invoke it explicitly. With the plugin installed, the skill's trigger is **delegate by default**: any writing work spanning more than one file or more than ~20 lines should activate it, so ordinary requests like "build a todo app" or "add tests for the parser" get written by Gemini with the orchestrator planning and reviewing. A single coherent task is dispatched as a swarm of one — parallel fan-out is an optimization, not a requirement. Explicit phrases ("swarm this across Gemini", "fan this out") also work, with `default` mode.

### Image generation (`/gemini-imagegen`)

Claude can't generate raster images — Gemini via `agy` can. The bundled **gemini-imagegen** skill dispatches an agy session whose `generate_image` tool creates the image and saves it wherever you ask:

```
/gemini-imagegen a flat-style logo of a hummingbird in teal and orange, transparent background, save as assets/logo.png
```

It also triggers implicitly whenever a task needs image assets ("make me a hero image for the landing page") or the user asks to generate/edit an image. Multiple images are dispatched in parallel, one agy job per image, and the orchestrator views each result to verify it matches before delivering.

### Autonomy modes

| Mode | What the `agy` jobs get |
|------|------------------------|
| `default` | Mirrors the host: if Claude Code is in auto-accept/bypass mode, jobs run with `--dangerously-skip-permissions --sandbox`; if Claude Code is in review mode, jobs run under agy's configured `request-review` tool permission. |
| `auto` | Always `--dangerously-skip-permissions --sandbox` (full autonomy, terminal-restricted sandbox). |
| `request` | Never skips permissions; jobs run under agy's `request-review` policy. |

### Run logs

Every swarm run writes `.gemini-swarm/logs/<ISO-timestamp>.md` in your project, containing:

- a one-paragraph plain-English summary at the top,
- each subtask dispatched and the model used for it,
- files/artifacts touched,
- wall-clock duration and pass/fail per subtask.

Output is auto-accepted — the log is the audit trail, not a review gate. Add `.gemini-swarm/` to your project's `.gitignore` if you don't want logs committed.

## Repo layout

```
gemini-swarm/
├── LICENSE                        # MIT
├── README.md
├── .claude-plugin/
│   ├── plugin.json                # Claude Code plugin manifest
│   └── marketplace.json           # so /plugin marketplace add works on this repo
├── skills/
│   ├── gemini-swarm/
│   │   ├── SKILL.md               # the decomposition + dispatch + logging playbook
│   │   └── scripts/
│   │       └── dispatch.sh        # symlink-free copy for standalone skill installs
│   └── gemini-imagegen/
│       └── SKILL.md               # image generation via Gemini's generate_image tool
├── agents/
│   └── gemini-dispatcher.md       # cheap Bash-only subagent that runs the dispatch
├── commands/
│   ├── gemini-swarm.md            # /gemini-swarm default|auto|request
│   └── gemini-imagegen.md         # /gemini-imagegen <image description>
├── docs/
│   └── harnesses.md               # Codex CLI / OpenCode / Antigravity adapter notes
└── scripts/
    └── dispatch.sh                # parallel dispatcher (source of truth)
```

## How it works

- **One source of truth**: all orchestration logic lives in `SKILL.md`; the plugin command, the subagent, and the other-harness adapters are thin wrappers around it.
- **Context hygiene**: the `gemini-dispatcher` subagent (a cheap model with only Bash/Read/Write) calls `scripts/dispatch.sh`, waits for all jobs, writes the run log, and returns *only a short summary plus the log path*. Raw Gemini stdout never enters the orchestrator's context.
- **True parallelism**: `dispatch.sh` launches every `agy --print` job concurrently with `&` and `wait`s for all of them. No concurrency cap, no throttling.

## License

[MIT](LICENSE)
