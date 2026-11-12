# Contributing

Keep changes focused and describe the user-visible behavior and validation in
pull requests. Do not commit credentials, local agent settings, or run logs.

## Local checks

From the repository root, run:

```bash
bash scripts/check-repo.sh
git diff --check
```

The check validates the routing-guide links, the standalone copies of the
guide and scripts, that no model names are hard-coded, Bash syntax, and model
listing and dispatch validation against a fake `agy`.
It requires Bash and standard Unix utilities; no API access is needed.
GitHub Actions runs these checks for pushes and pull requests.

## Models

There is nothing to update when Gemini releases a model. The orchestrator
reads the live list from `scripts/list-models.sh` (which wraps `agy models`
and keeps the newest version of each family) and chooses per subtask using
`skills/gemini-swarm/references/models.md`. Keep that guide free of model
names and versions; the check enforces it. Edit the guide only to change how
tiers are chosen, then copy it to `skills/gemini-imagegen/references/models.md`
so both skills work when installed separately.

## Publishing updates

Bump `version` in `.claude-plugin/plugin.json` for every skill, script, or
policy change, run the checks, and merge to `main`. Keep the version in that
manifest only. The plugin's SessionStart hook (`hooks/check-update.sh`) tells
users when a newer version is published; manual folder copies need to be
recopied. See the README for user instructions.

## Dispatcher changes

Edit `scripts/dispatch.sh` and `scripts/list-models.sh`, then copy them to
`skills/gemini-swarm/scripts/` (and `list-models.sh` to
`skills/gemini-imagegen/scripts/`). `list-models.sh` honours an `AGY`
environment variable, so you can point it at a mock. Validate argument forwarding, failure
reporting, and both permission modes with a mock `agy` executable before testing
against a live account. Never treat a successful process exit alone as proof
that generated artifacts are correct.
