# Gemini model catalog

Use `flash-high` for every task, including reasoning-heavy work, debugging,
architecture, refactors, bulk edits, documentation, and image-generation sessions.
Copy the exact `agy` model name below into the `MODEL:` header or `--model` flag.

| Profile | Exact `agy` model name | Use for |
|---------|------------------------|---------|
| `flash-high` | `Gemini 3.8 Flash (High)` | All workloads, including heavy tasks. |

## Routing policy

Pro routing is disabled. Do not fall back to an older Pro model or a lower
thinking level. If the configured model is unavailable, report the issue.
Image generation also requires the session's `generate_image` tool; report
`IMAGE_UNSUPPORTED` if that tool is unavailable.

Gemini 4 Pro is a future candidate for heavy tasks, not an active route. Enable
it only after it is released, appears in `agy models`, and is explicitly adopted
by this repository. Until then, heavy tasks use `flash-high`.

## Updating models

1. Run `agy models` and verify the exact display name.
2. Update this catalog in `skills/gemini-swarm/references/models.md`.
3. Copy it to `skills/gemini-imagegen/references/models.md` so both skills can
   be installed independently.
4. Run `bash scripts/check-model-catalog.sh`.

Keep versioned model names in these catalogs. Keep the bundled catalog copies
identical; the repository check detects drift.
