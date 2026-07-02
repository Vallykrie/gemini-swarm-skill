# Running gemini-swarm in other harnesses

The whole plugin is one Markdown playbook (`skills/gemini-swarm/SKILL.md`) plus
one shell script (`scripts/dispatch.sh`). Every harness adapter below is a thin
wrapper that (a) makes the playbook load into the agent's context at the right
time and (b) makes `dispatch.sh` reachable. **Do not fork the logic** — if you
change the behavior, change `SKILL.md` and let every wrapper pick it up.

The script has no harness dependencies at all: any agent that can run Bash can
use it. Structural inspiration: [`wshobson/agents`](https://github.com/wshobson/agents),
which ships one source of truth adapted into idiomatic artifacts per harness.

In all cases the requirements are the same as Claude Code's: `agy` on `PATH`,
logged in, project directory trusted.

---

## Codex CLI (OpenAI)

Codex has no plugin marketplace; it loads instructions from `AGENTS.md` and
custom slash prompts from `~/.codex/prompts/`.

**Install:**

```bash
git clone https://github.com/Vallykrie/gemini-swarm-skill ~/.gemini-swarm
mkdir -p ~/.codex/prompts
{ echo '---'
  echo 'description: Swarm a task across parallel Gemini (agy) sessions'
  echo '---'
  echo 'The dispatcher script is at ~/.gemini-swarm/scripts/dispatch.sh.'
  echo 'Mode/task arguments: $ARGUMENTS'
  cat ~/.gemini-swarm/skills/gemini-swarm/SKILL.md
} > ~/.codex/prompts/gemini-swarm.md
```

Now `/gemini-swarm auto <task>` works in Codex. Alternatively, for an
always-on version, append a short pointer to your project's `AGENTS.md`:

> For tasks that split into independent chunks, follow the playbook in
> `~/.gemini-swarm/skills/gemini-swarm/SKILL.md` (dispatcher:
> `~/.gemini-swarm/scripts/dispatch.sh`).

**Mode mapping:** Codex approval modes → swarm `default` mode: `--full-auto` /
`--yolo` ⇒ dispatch `--auto`; `suggest`/`auto-edit` (approval required) ⇒
dispatch `--request`.

**Notes:** Codex has no subagents, so skip the `gemini-dispatcher` layer — the
main agent runs `dispatch.sh` itself (the script already keeps raw Gemini
output on disk, not in stdout, so context stays clean).

---

## OpenCode

OpenCode supports Claude-compatible skills, custom commands, and subagents
natively.

**Install (skill — recommended):**

```bash
git clone https://github.com/Vallykrie/gemini-swarm-skill /tmp/gsw
mkdir -p ~/.config/opencode/skills
cp -r /tmp/gsw/skills/gemini-swarm ~/.config/opencode/skills/
```

OpenCode discovers `skills/*/SKILL.md` with the same frontmatter format, and
the bundled `scripts/dispatch.sh` travels with the folder. Project-local
install: `.opencode/skills/gemini-swarm/` instead.

**Optional command wrapper** (`~/.config/opencode/commands/gemini-swarm.md`):

```markdown
---
description: Swarm a task across parallel Gemini (agy) sessions
---
Use the gemini-swarm skill. Arguments (mode then task): $ARGUMENTS
```

**Optional subagent** — copy `agents/gemini-dispatcher.md` into
`~/.config/opencode/agents/` and change the frontmatter `model:` to an
OpenCode model id (e.g. `anthropic/claude-haiku-4-5`) and `tools:` to
OpenCode's `tools:` map format:

```yaml
mode: subagent
tools:
  bash: true
  read: true
  write: true
  edit: false
```

**Mode mapping:** OpenCode permission config `"bash": "allow"` ⇒ `--auto`;
`"ask"` ⇒ `--request`.

---

## Antigravity CLI (agy) itself — Gemini orchestrating Gemini

agy can consume the Claude plugin directly; no translation needed:

```bash
git clone https://github.com/Vallykrie/gemini-swarm-skill
cd gemini-swarm-skill
agy plugin import claude      # imports skills/commands from the Claude layout
agy plugin list               # verify; enable if needed
```

(Verified against agy 1.0.15 — `agy plugin import [source]` accepts `claude`
as a source and copies the whole plugin directory, including `scripts/`.)

Then inside an agy session, invoke the `gemini-swarm` skill. Two quirks when
the host *is* agy:

- **Mode mapping for `default`:** read the host's own `toolPermission`
  setting (`always-proceed` ⇒ dispatch `--auto`; `request-review`/`strict` ⇒
  dispatch `--request`).
- agy has native async subagents; the playbook's dispatch step still uses
  `dispatch.sh` so behavior (logging, model routing, parallelism) stays
  identical across harnesses.

---

## Anything else

Minimum viable adapter for any agent that can run shell commands:

1. Put `SKILL.md` where the agent will read it when the user asks to "swarm"
   a task (system prompt include, rules file, `AGENTS.md`, etc.).
2. Make sure `scripts/dispatch.sh` exists at a path mentioned alongside it.
3. Map the host's permission mode to `--auto` / `--request` for the skill's
   `default` mode.

That's the entire contract.
