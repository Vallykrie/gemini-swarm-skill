# Contributing

Keep changes focused and describe the user-visible behavior and validation in
pull requests. Do not commit credentials, local agent settings, or run logs.

## Local checks

From the repository root, run:

```bash
bash scripts/check-model-catalog.sh
git diff --check
```

The check validates the active routing profile, catalog links, standalone
catalog and dispatcher copies, retired model references, and Bash syntax.
It requires Bash and standard Unix utilities; no API access is needed.
GitHub Actions runs these checks for pushes and pull requests.

## Model updates

The source catalog is `skills/gemini-swarm/references/models.md`. Confirm model
names with `agy models`, update the catalog, and copy it to
`skills/gemini-imagegen/references/models.md`. Both skills must remain usable
when installed separately. Keep exact model versions out of other instructions.

All workloads currently use `flash-high`, including heavy reasoning. A future
Pro route requires an explicit policy change and corresponding validation
updates; availability alone must not activate it.

## Dispatcher changes

Edit `scripts/dispatch.sh`, then copy it to
`skills/gemini-swarm/scripts/dispatch.sh`. Validate argument forwarding, failure
reporting, and both permission modes with a mock `agy` executable before testing
against a live account. Never treat a successful process exit alone as proof
that generated artifacts are correct.
