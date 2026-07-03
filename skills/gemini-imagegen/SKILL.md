---
name: gemini-imagegen
description: Use when the user asks to generate, create, draw, edit, or restyle an image, or when a task needs image assets — logos, icons, illustrations, hero images, textures, photos, placeholder art, social/OG cards. Claude cannot produce raster images; a Gemini session via the agy (Antigravity) CLI has a generate_image tool that can. Trigger words include "generate an image", "make a picture/logo/icon", "draw", "nano banana", "image asset".
---

# gemini-imagegen

Claude cannot generate raster images. Gemini sessions launched through the
`agy` (Antigravity CLI) have a **`generate_image`** tool that can — this skill
dispatches an agy job that generates the image and saves it to a file you
specify.

Verified against agy **1.0.15** (model `Gemini 3.1 Pro (High)`, tool name
`generate_image`). Re-check `agy --help` if flags seem wrong.

## Step 0 — Preflight

1. `command -v agy` — if missing, stop and tell the user to install the
   Antigravity CLI (https://antigravity.google).
2. Decide the **absolute** output path(s) for the image(s). agy `--print`
   sessions do not run in your invocation cwd, so relative paths land in the
   wrong place — always pass absolute paths in the prompt and `--add-dir` the
   destination directory.

## Step 1 — Write the image prompt

Be specific — the quality of the image tracks the prompt. Include:

- **Subject** — what the image shows.
- **Style** — photo, flat illustration, 3D render, watercolor, pixel art,
  logo mark, etc.
- **Composition** — framing, background, negative space.
- **Colors / mood** — palette, lighting.
- **Intended use** — favicon, hero banner, OG card — so the model picks a
  sensible aspect ratio and level of detail.

For **editing an existing image** (restyle, variation, background removal),
give the absolute path of the source image in the prompt, `--add-dir` its
directory too, and ask Gemini to load it before generating the edited version.

## Step 2 — Dispatch

One image (verified command shape — adapt prompt and paths):

```bash
agy --print "Use your generate_image tool to create: <detailed image prompt>. Save the final image to /abs/path/out.png. When it is saved, print IMAGE_OK followed by the file path. If you cannot generate images, print IMAGE_UNSUPPORTED and stop." \
  --model "Gemini 3.1 Pro (High)" \
  --print-timeout 5m \
  --add-dir /abs/path \
  --dangerously-skip-permissions --sandbox
```

- `--dangerously-skip-permissions --sandbox` lets the job write the file
  without an approval TTY (there is none in `--print` mode). If the user runs
  you in review mode and objects to auto-approval, ask before dispatching.
- **Multiple images:** dispatch them in parallel, one agy job per image —
  either background several of the above commands, or reuse the gemini-swarm
  dispatcher (`scripts/dispatch.sh`) with one `NN-slug.prompt.md` per image
  (`MODEL: Gemini 3.1 Pro (High)` header). Never generate sequentially.

## Step 3 — Verify and deliver

1. Check the output: file exists, non-zero size, `IMAGE_OK` in stdout.
2. **Look at the image** (read/view the file) — confirm it actually matches
   the request before claiming success.
3. Wrong or off-brief result → refine the prompt (state what to change) and
   re-dispatch; for small revisions, include the previous image as a source
   to edit.
4. Deliver: send/show the file to the user, or wire it into the project
   (HTML `<img>`, README, app asset) if that was the task.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Relative output path | agy print jobs don't run in your cwd — absolute paths only, plus `--add-dir`. |
| Claiming success from exit code alone | View the image; models sometimes save a wrong or blank file. |
| Generating N images in one sequential session | One parallel agy job per image. |
| Trying to generate the image yourself (SVG "art", ASCII, base64) when the user wanted a real image | That's the failure this skill exists to prevent — dispatch to Gemini. |
| Telling the user "I can't generate images" | You can't, but Gemini via agy can. Use this skill instead of refusing. |
