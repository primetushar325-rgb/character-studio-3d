# 2D Story / Video Editor — v2.4 (Phases 1–4)

**A 100% offline, mobile 2D story/video editor with rigged 2D characters.**
No 3D. No network. No accounts. Everything runs on-device.

> **Flow:** HOME → NEW PROJECT (16:9 / 9:16 / 1:1) → EDITOR → story TIMELINE → export MP4 (video + audio).
> Projects autosave to `<appDocuments>/projects/<id>/project.json` and survive app close,
> restart and process death. Everything a project references (images, audio) is copied
> into the project folder, so projects stay playable forever.

> v2.0 removed every 3D pipeline (GLB/GLTF/WebGL). v2.1–v2.4 add the project system,
> the multi-object scene graph, the real story timeline with animation clips and
> keyframes, and the audio system (music/voice/SFX with MP4 audio export) on top of
> the existing 2D engine, renderer and export.

**Download:** [Latest release](https://github.com/primetushar325-rgb/character-studio-3d/releases) —
`2DCharacterStudio-v2.4.0-arm64-v8a.apk` (most devices) or `…-armeabi-v7a.apk` (32-bit).

---

## What's inside

| System | What it does |
|---|---|
| **2D bone rigs** | Hierarchical bones with pivots at anatomical joints. `humanoid_v1` (Root→Hips→Torso→Neck→Head→arms/legs, 20+ bones) and `quadruped_v1` (Root→Body→Neck/Head→4×(Upper/Lower/Paw)→Tail×4, 22 bones). Children follow parents — rotating a thigh moves the knee, not the hips. |
| **14 standard animations** | Idle, Walk, Run, Sit, Sleep, Talk, Jump, Wave, Action, Happy, Sad, Think, Turn, Fall — every character, same engine. Humanoid walk is a real gait (contact/down/passing/up, counter-swinging arms, weight shift, head stabilization); quadruped walk is the diagonal pattern FL+BR → FR+BL with body bounce, head counter-nod, tail follow-through and ear flop. |
| **Character engine** | Keyframe clips with Linear/EaseIn/EaseOut/EaseInOut per-bone tracks, a locomotion state machine (walk_start/walk_stop blending), procedural talk visemes + blink scheduler, layered gestures. Any character can replace the Tiger — no per-character code. |
| **Characters** | Tiger (default, quadruped), BD Farmer, Village Girl, School Teacher (humanoids) + unlimited prompt-generated variants + imported PNG characters. |
| **Multi-object scene graph** | Every layer is a real object: characters, imported images, text and shapes with independent move/scale/rotate, z-order, hide and lock. Multiple characters coexist — each with its own animation, expression and direction. Selection handles, layers panel, canvas-relative coordinates (identical on every screen size). |
| **Backgrounds** | 15 built-ins across Nature/Village/City/Room/Office/Street/Forest/Farm/School/Studio/Night/Day/Fantasy + gallery upload (PNG/JPG/WEBP, Cover/Contain/Fit + scale/offset), gradients, solids, transparent. Brightness/contrast/blur/opacity per background. |
| **Story timeline** | One deterministic scene clock (default 20 s; 10/15/20/30/60 presets) drives EVERYTHING: character animation clips (walk 0–5 s, wave 5–8 s …) with move/trim/duplicate, loop, speed 0.25–2× and pose blending; object visibility ranges; transform keyframes (x/y/scale/rotation/opacity) with linear/easeIn/easeOut/easeInOut; AUTO KEY; zoomable tracks with snapping; playhead scrubbing (00:00.00); timeline undo/redo. **Preview and export use the exact same evaluator** — what you see is what you encode. |
| **Audio system** | Music / voice / SFX clips imported via the system picker and **copied into the project** (`assets/audio/`). Audio tracks live on the same story timeline: drag to move, non-destructive trim (source start + duration), volume 0–150%, mute, fade in/out, loop. Multi-clip preview mixing driven by the scene clock — seeks stay perfectly in sync. **MP4 export contains the mixed audio**, rendered deterministically from the project data (per-clip trim/volume/fades/position → amix → AAC), never a blind file attach. Missing files offer Locate / Remove and never crash. |
| **REAL video export** | The composition is **rendered frame-by-frame** from the story timeline (same evaluator as the preview: `evaluate(tMs) → paintScene → encode`) with **FFmpeg (libx264 + AAC)** to MP4 — video and mixed audio in one deterministic pass. *Never* screen recording — the exported file contains exactly the 16:9 canvas, zero editor UI. Also GIF (pure-Dart GIF89a encoder with median-cut palette + Floyd–Steinberg dithering), PNG, and PNG sequences. 1080p/720p/480p × 24/30/60fps × Low→Ultra quality. |
| **Character export** | One self-contained HTML file (canvas rig solver + animations + player UI, opens in any browser, zero dependencies) and a portable `character.json`. |

---

## Import a PNG character

1. Editor → **Character** panel → **Import PNG** (or the Characters tab → **PNG**).
2. Pick a PNG/JPG/WEBP from your gallery.
3. Choose the body type: **Humanoid (2 arms, 2 legs)** or **Quadruped (4 legs + tail)**.
4. The artwork is copied into the app's private storage and mounted **unchanged** on the
   matching cutout rig — the full-body artwork is preserved exactly (design, colors,
   proportions are never altered); the rig animates the whole cutout with a correct
   gait, breathing, squash & stretch and follow-through.
5. The character appears in your library and gets all 14 standard animations.

Tips: use artwork with a **transparent background**, standing pose, full body visible,
arms not fused to the torso. Pixel-art and flat-cartoon styles animate best.

## Generate a character from a prompt

1. Character panel → **From Prompt**.
2. Describe the character, e.g. `"orange cartoon tiger"`, `"blue village girl"`,
   `"green farmer with lungi"`.
3. The studio picks the closest base template (feline→Tiger rig, human→villager rigs),
   recolors it from your color words, and saves it as a new variant. Built-ins are
   never modified.

## character.json format

```json
{
  "name": "Tiger",
  "version": "1.0",
  "type": "2D_RIGGED_CHARACTER",
  "rigKind": "quadruped_v1",
  "canvas": { "width": 1080, "height": 1080 },
  "palette": { "fur": "#f09a2e", "stripe": "#2e2620", "...": "..." },
  "bones": [ { "name": "flUpper", "parent": "body", "attach": [0,38],
               "restAngle": 90, "length": 30 } ],
  "layers": [ { "bone": "body", "z": 4, "shapes": [ ... ] } ],
  "animations": [
    { "id": "walk", "duration": 1.05, "loop": true,
      "tracks": [ { "bone": "flUpper",
                    "keyframes": [ { "time": 0, "rotation": -26, "easing": "easeInOut" } ] } ] }
  ]
}
```

Baked at 30 fps from the live clip library; every one of the 14 standard animations is
included. Reusable in any engine that can lerp numbers.

## Single-file HTML export

Character panel → **EXPORT CHARACTER → Single-file HTML** writes one `.html` file that
embeds the character JSON plus a complete canvas rig solver (bones, easing, shapes,
face rig, blink scheduler, direction flip) and a player: animation buttons
(IDLE WALK RUN SIT SLEEP TALK JUMP WAVE + more), play/pause/stop, loop, timeline,
speed, prev/next frame, fullscreen, reset. Open it in any browser — no server, no
dependencies.

---

## Offline & privacy

* No backend, no Firebase, no REST, no analytics, no URLs — airplane-mode capable.
* Storage via MediaStore (`Movies/2DCharacterStudio`); no storage permission needed
  (Android 10+ scoped storage).
* Imported files are treated as untrusted data: decoded read-only, stored inside app
  directories, validated before use.

## Build

```bash
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm64   # 46 MB arm64
flutter build apk --release --target-platform android-arm -PtargetAbi=armeabi-v7a
```

Requires Flutter 3.24.x, JDK 17, Android SDK 35. Video encoding is
`ffmpeg_kit_flutter_new_min_gpl` (libx264, offline, on-device).

## Project format (project.json)



```json
{
  "format": 1, "id": "…", "name": "My Story",
  "orientation": "landscape",
  "canvas": { "width": 1920, "height": 1080 },
  "background": { "kind": "image", "imagePath": "assets/bg/bg_…png" },
  "scene": { "objects": [ { "type": "character", "id": "obj_…",
              "characterId": "bd_farmer_male", "actionId": "walk",
              "transform": { "x": 0.5, "y": 0.78, "scaleX": 1, "rotation": 0 },
              "zIndex": 1, "visible": true, "locked": false } ] },
  "timeline": { "durationMs": 20000,
    "tracks": { "obj_…": {
      "clips": [ { "animId": "walk", "startMs": 0, "endMs": 5000,
                   "speed": 1, "loop": true, "blendInMs": 250 } ],
      "keyframes": [ { "timeMs": 0, "props": { "x": 0.2 }, "ease": "linear" } ],
      "visClips": [ { "startMs": 8000, "endMs": 12000 } ] } } },
  "audioClips": [ { "name": "Theme", "filePath": "assets/audio/…mp3",
    "sourceType": "music", "startMs": 0, "durationMs": 20000,
    "sourceStartMs": 0, "volume": 0.3, "fadeInMs": 2000, "fadeOutMs": 2000 } ]
}
```

Older project files (v2.1–v2.3) open with safe migrations: Phase-1 single-character
projects get a synthesized scene object; missing `timeline`/`audioClips` default cleanly.

## Architecture (lib/)

```
characters2d/
  engine/    rig2d, pose2d, animator2d (keyframes + easing), clips + quadruped_clips
             (14+ animations each), state_machine2d, face_rig, shapes, palette_resolver
  art/       tiger, bd_farmer, village_girl, school_teacher, body_kit, draw_utils,
             palettes, character_catalog (dynamic registry)
  widgets2d/ puppet stage + thumbnails
  puppet_controller.dart   playback, talk layer, direction, gestures
  character_json.dart      portable character.json builder
  html_export.dart         single-file HTML exporter
  png_character.dart       PNG cutout import
backgrounds/  15 painted backgrounds + image/gradient/solid modes (BgConfig)
scene/        scene_object model + scene_renderer — paints the full composition
              (background → objects in z-order) for the editor, playback AND export
timeline/     story_timeline (tracks/clips/keyframes/easing/snap, pure math) +
              playback_clock (the ONE scene clock)
audio/        audio_clip model, audio_timeline (preview mixer on the scene clock),
              audio_export (deterministic ffmpeg mix args)
project/      project_document + repository (create/save/load/migrate, autosave)
export2d/     export_service2d (MP4+audio/PNG/sequence) + gif_encoder (pure Dart GIF89a)
screens/      editor (canvas, selection, panels, timeline panel, audio picker,
              export dialog), home (projects), characters, settings
state/        editor_provider (scene graph + evaluation), projects_provider,
              library2d_provider, shell_provider (Provider only)
```

## Tests

`flutter test` — **138 tests** covering the rig hierarchy, gait mechanics (walk phase
alternation, counter-swing, bounce; quadruped diagonal pairs), state machine
transitions, talk/blink layering, persistence round-trips, the GIF encoder
(GIF89a header, NETSCAPE loop, palette), the character.json contract, the project
system (create/save/load/migration/autosave), the scene graph (multi-object
coexistence, z-order, lock/visibility, serialization round-trips), the story
timeline (easing math, clip local time/loop/speed, visibility windows, keyframe
interpolation, snap, deterministic evaluation, undo/redo, panel smoke test) and
the audio system (serialization, trim/source-offset math, fades, export mix args,
seek sync with no stale/duplicate audio, missing-file flow, undo/redo, project
round-trip). CI runs analysis + the full suite on every push and gates the APK
build on them.
