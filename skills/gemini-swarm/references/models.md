# Choosing a Gemini model

This file holds no model names on purpose. Models change too fast to pin them
here: you, the orchestrator, read the live list and choose for each subtask.

## 1. See what is available

Run the lister next to the dispatcher (`scripts/list-models.sh`, or
`${CLAUDE_PLUGIN_ROOT}/scripts/list-models.sh` in a plugin install) once per
run, before routing:

```bash
bash <scripts-dir>/list-models.sh
```

It calls `agy models` and prints only Gemini models, and only the **newest
version of each family**, with their thinking levels. Older versions are
filtered out, so anything it prints is current. Never use a model name from
memory, from an earlier run, or from this repository's history.

## 2. Choose per subtask

Read each family from the list and place it on this ladder. New families and
code names appear over time; judge them by their position in the lineup (a
newer, non-Flash flagship sits at the top), not by a fixed name.

| Tier | Typical family names | Route here |
|------|----------------------|------------|
| Lightweight | `Flash-Lite`, `Lite`, `Nano` | Trivial mechanical work: renames, formatting, boilerplate from an exact template, simple data extraction. |
| Fast | `Flash` | The default. Most code and content writing, tests, docs, bulk edits, research summaries, image generation. |
| Flagship | `Pro`, `Ultra`, or a newer non-Flash family / code name | Hard reasoning: architecture, subtle debugging, tricky refactors across many call sites, security-sensitive code, ambiguous specs, anything a previous Fast attempt got wrong. |

Then pick the thinking level the model offers:

| Level | Use for |
|-------|---------|
| Low | Mechanical, fully specified work. |
| Medium | Ordinary writing with some judgment. |
| High | Reasoning-heavy or ambiguous work, and the first attempt at anything that must be right. |

Rules of thumb:

- Default to the Fast family at High thinking when unsure; it is the best
  balance of quality and speed.
- Escalate to Flagship for the hard subtasks only, not the whole swarm.
- When a subtask hard-fails and you re-dispatch it, move it up one tier or
  one thinking level.
- If the tier you want is missing from the list, take the nearest tier that
  is present. Never fall back to an older version.
- Different subtasks in one run can, and usually should, use different models.

## 3. Write the choice into the task file

Put the **model id** (the first column of the list) in the task file's header:

```
MODEL: <model id from list-models.sh>
```

The dispatcher checks every header against the live list before it launches
anything. A misspelled, unavailable or superseded model stops the whole run
and prints the valid ids, so fix the header and dispatch again.

Image generation also requires the session's `generate_image` tool; report
`IMAGE_UNSUPPORTED` if that tool is unavailable.
