# gemini-swarm

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Vallykrie/gemini-swarm-skill?style=social)](https://github.com/Vallykrie/gemini-swarm-skill/stargazers)
[![GitHub last commit](https://img.shields.io/github/last-commit/Vallykrie/gemini-swarm-skill)](https://github.com/Vallykrie/gemini-swarm-skill/commits/main)

> **Gemini does the writing. Your orchestrator plans and reviews.**

gemini-swarm is a Claude Code plugin/skill (portable to other harnesses) that makes Gemini the *default* writer for substantial work. Whenever a task means writing more than a trivial amount of code or content, your orchestrator splits it into subtasks, fans each one out to a live `agy` ([Antigravity CLI](https://antigravity.google)) session running the right Gemini model, and integrates the results — all while its own context stays clean. It also ships **gemini-imagegen** for generating real images through Gemini's `generate_image` tool, something Claude can't do on its own.

<!-- Demo: docs/demo.gif or an asciinema cast showing `/gemini-swarm auto` fanning out and returning a run log. -->

## Contents

**New here?**
- [What it does](#what-it-does) — the idea, and the four steps it runs
- [Use cases](#use-cases-when-it-pays-off) — is this the right fit for my task?

**Installing?**
- [Getting started](#getting-started) — full setup, ~5 min from a clean machine
- [Already have `agy`? Jump to Step 3](#step-3-install-the-plugin) — just add the plugin
- [Other install methods](#other-install-methods) — plain skill, or another harness

**Reference**
- [Usage & commands](#usage) · [Autonomy modes](#autonomy-modes) · [Run logs](#run-logs) · [How it works](#how-it-works)

---

## What it does

The orchestrator:

1. **Decomposes** a task into independent subtasks (different files, modules, or research topics — no shared-state conflicts),
2. **Routes** each subtask to the right Gemini model via the [Antigravity CLI](https://antigravity.google) (`agy`) — reasoning-heavy work to `Gemini 3.1 Pro (High)`, bulk/mechanical work to `Gemini 3.5 Flash`,
3. **Dispatches** all subtasks in parallel `agy` sessions, and
4. **Integrates** the results, writing a run log to `.gemini-swarm/logs/`.

The orchestrator model does planning and review; Gemini does the token-heavy bulk work.

---

## Getting started

You need three things: the Antigravity CLI (`agy`), a logged-in + trusted workspace, and this plugin. ~5 minutes from a clean machine.

### Step 1 — Install the Antigravity CLI (`agy`)

`agy` is Google's terminal agent; it's the process that actually runs each Gemini job. Install it with the official one-line script (no Node/Python needed — it's a single Go binary):

```bash
# macOS / Linux
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

```powershell
# Windows PowerShell
irm https://antigravity.google/cli/install.ps1 | iex
```

The script drops the binary at `~/.local/bin/agy` (macOS/Linux) and adds it to your `PATH`. **Open a new terminal**, then confirm it's reachable:

```bash
agy --version      # built & tested against agy 1.0.15
```

If `agy: command not found`, add its directory to your `PATH` (`export PATH="$HOME/.local/bin:$PATH"` in your shell profile) and reopen the terminal.

### Step 2 — Log in and trust your project

Run `agy` once, interactively, **inside the project you want to swarm in**:

```bash
cd /path/to/your/project
agy
```

On first run it opens Google Sign-In (or prints an authorization URL for remote/SSH sessions — complete it in a local browser). It also asks whether to **trust this workspace** — say yes. This trust is per-directory, so repeat `agy` once in each new project. Type `/quit` (or Ctrl-C) to exit once you're logged in and trusted.

> That's the whole `agy` side. Everything below runs `agy` for you — you won't open it by hand again.

### Step 3: Install the plugin

This is **two separate commands** — run them one at a time at the Claude Code prompt:

```
/plugin marketplace add Vallykrie/gemini-swarm-skill
```
```
/plugin install gemini-swarm@gemini-swarm-skill
```

> ⚠️ Don't paste both onto one line, and don't paste `/plugin install …` into the "Add Marketplace / Enter marketplace source" box — that field wants **only** the source (`Vallykrie/gemini-swarm-skill`). The install is a second, separate step.

This gives you both skills (gemini-swarm, gemini-imagegen), the `/gemini-swarm` and `/gemini-imagegen` commands, and the `gemini-dispatcher` subagent. You're ready — jump to [Usage](#usage).

---

## Other install methods

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

---

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

### Use cases: when it pays off

gemini-swarm pays off whenever a task splits into **independent chunks that don't share state** — so they can run at once without stepping on each other — and the bulk of the work is mechanical enough to hand to Gemini while your orchestrator just plans and reviews.

**Scenario:** you have a repo with 20 API-route files and no tests. Writing them serially in your main agent would burn its whole context window on boilerplate.

```
/gemini-swarm auto
Write unit tests for every file in src/routes/. One test file per route,
covering the happy path and the main error cases. Match the existing style
in tests/.
```

What happens:

1. The orchestrator **decomposes** it into ~20 independent subtasks (one per route — no two touch the same file, so no conflicts).
2. It **routes** each: mechanical test-writing → `Gemini 3.5 Flash`; anything needing deeper reasoning → `Gemini 3.1 Pro (High)`. It never asks you which.
3. All ~20 `agy` jobs **run in parallel**, each writing its own test file directly to disk.
4. The orchestrator **integrates**: confirms every file landed, writes a run log to `.gemini-swarm/logs/`, and reports back a short summary — *not* 20 walls of Gemini output.

Your main agent's context stays clean; the token-heavy grind happened in the Gemini sessions. Other good fits: porting many modules to a new language, generating docstrings across a package, researching several topics at once, refactoring a set of unrelated files. **Poor fits:** one big file everything edits, or steps that must happen in order — those have no parallelism to exploit.

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

---

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

---

## How it works

- **One source of truth**: all orchestration logic lives in `SKILL.md`; the plugin command, the subagent, and the other-harness adapters are thin wrappers around it.
- **Context hygiene**: the `gemini-dispatcher` subagent (a cheap model with only Bash/Read/Write) calls `scripts/dispatch.sh`, waits for all jobs, writes the run log, and returns *only a short summary plus the log path*. Raw Gemini stdout never enters the orchestrator's context.
- **True parallelism**: `dispatch.sh` launches every `agy --print` job concurrently with `&` and `wait`s for all of them. No concurrency cap, no throttling.

## License

[MIT](LICENSE)
