---
description: Generate or edit an image via a Gemini (agy) session — Gemini's generate_image tool does what Claude cannot
argument-hint: [image description...]
---

Run the **gemini-imagegen** skill (`skills/gemini-imagegen/SKILL.md` in this
plugin — read it now and follow it exactly).

Arguments given: `$ARGUMENTS`

Treat the whole argument string as the image request. If it is empty, ask the
user what image they want and where to save it, then proceed.

Follow the skill: build a detailed image prompt, pick an absolute output path
(ask only if no sensible default exists in the project), dispatch the agy job,
verify by viewing the resulting file, and deliver it. Multiple requested
images are dispatched in parallel, one agy job each.
