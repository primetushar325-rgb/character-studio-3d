# Device Smoke-Test Checklist — v2.4.0 (Phases 1–4)

Automated coverage: 138 unit/widget tests + CI-gated APK builds. This checklist is the
**manual on-device pass** for the things automation cannot see (touch feel, audio
playback, encoder output on real hardware). ~20 minutes.

Install: `2DCharacterStudio-v2.4.0-arm64-v8a.apk` (or armv7 for 32-bit devices).

Legend: ☐ = to verify · everything below should behave EXACTLY as written.

---

## 0 · First run (P1)

- ☐ App opens on **Home** with NEW PROJECT / MY PROJECTS / CHARACTERS — no project
      auto-created, no character auto-added to Home.
- ☐ NEW PROJECT → name + 16:9 / 9:16 / 1:1 → editor opens empty (no character).
- ☐ Back → project listed with thumbnail + orientation badge.

## 1 · Multi-object scene graph (P2 — spec §21)

- ☐ Background: gallery image → appears; kill app → reopen → still there
      (file was copied into the project, not linked).
- ☐ + Char → Farmer; + Char again → Village Girl — **both visible, nothing replaced**.
- ☐ Drag one character — the other does not move. Scale/rotate via handles affects
      only the selection. Locked object (Layers → lock) can be selected but not moved.
- ☐ Layers panel: hide a character → gone from canvas; reorder → paint order changes.
- ☐ + Image (PNG from gallery) → independent layer, movable/scalable/rotatable.
- ☐ + Text → type text → rendered INSIDE the canvas (zoom/pan the canvas to confirm).
- ☐ + Shape → rectangle/circle/line renders and transforms.
- ☐ Save (back) → kill app → reopen project → **all objects, positions, layers,
      visibility and lock states restored**.
- ☐ Export PNG → image contains background + both characters + image + text + shape.

## 2 · Story timeline (P3 — spec §25 A–I)

Setup: 20 s landscape project, background, one character, one text object.

- ☐ A/B — Character track: add WALK 0–5 s and WAVE 5–8 s. Play: walks 0–5, waves
      5–8 (with a smooth transition, no frozen jump), then idles after 8 s.
- ☐ C — Text track: visibility range 8–12 s. Text appears only in that window.
- ☐ D/E — Keyframes: x 0.2→0.9 and scale 1→1.5 across 0–5 s (AUTO KEY on: drag the
      character at 0 s, then again at 5 s). Character walks AND travels AND grows.
- ☐ F — Set the scale keyframe easing to Ease In-Out → motion visibly eases.
- ☐ G — Drag playhead: 2 s = walk · 6 s = wave · 10 s = text visible · 15 s = text gone.
- ☐ Clip editing: drag clip body (move), drag edges (trim), long-press (duplicate),
      tap (sheet: loop / speed / blend). Undo/redo buttons revert each operation.
- ☐ Zoom 25–200% + snap: dragging a clip near 5 s clicks to the grid/other clip edges.
- ☐ Playback speeds 0.25×–2× affect the whole scene (characters + audio together).
- ☐ H — Save → kill → reopen: duration, clips, keyframes, easing all restored.
- ☐ I — Export MP4 20 s → the video matches the preview exactly (walk 0–5, wave 5–8,
      text 8–12, movement + scale interpolation).

## 3 · Audio (P4 — spec §28–32)

Setup: the same 20 s project.

- ☐ Import — + AUDIO → Music / Voice / SFX → system picker → clip appears at the
      playhead. Import a huge/odd file → friendly error, no crash.
- ☐ §28 mix — Music 0–20 s @30% with 2 s fades + Voice 2–7 s @100% + SFX 5–5.5 s
      (0.5 s) @80%. Play from 0: fade-in 0–2, music+voice 2–7, +SFX at 5–5.5,
      second voice 8–13 (add another), fade-out 18–20.
- ☐ §29 seek — Play, pause at 4 s, drag playhead to 10 s: audio jumps instantly to
      the 10 s state. No stale audio, no doubled audio, no drift after 30+ s of play.
- ☐ §30 trim — 30 s file, clip start 5 s / source start 10 s / length 8 s: audio
      plays 5→13 s only, sourced from 10 s into the file. Trim via clip edge drag
      AND via the sheet fields.
- ☐ Volume/mute/fades — mute a clip: silent in preview; export it muted → silent in
      the MP4 too. Volume slider changes loudness live.
- ☐ Loop — short 8 s music on a 0–20 s clip: loops gaplessly to fill the clip.
- ☐ §31 — Save → kill → reopen: position, trim, volume, mute, fades all restored.
- ☐ §32 — Export MP4 → play outside the app (e.g. Files/media player): video has
      background, characters, timeline behavior AND audible mixed audio with fades.
- ☐ Missing file — use a file manager to delete one audio file from the project
      folder → reopen: clip shows FILE UNAVAILABLE, sheet offers Locate File /
      Remove Clip; neither crashes; export succeeds without the dead clip.

## 4 · Regression

- ☐ GIF + PNG-sequence exports still work.
- ☐ A v2.1-phase1 project (if you have one) opens with its single character intact.
- ☐ Airplane mode: everything above still works.

---

Report anything that fails with: project export (share), exact step, and device model.
