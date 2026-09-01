# 2D Character Studio — v2.0

**A 100% offline, professional 16:9 2D character rigging & animation editor.**
No 3D. No network. No accounts. Everything runs on-device.

> v2.0 is a full 3D→2D reversal: all GLB/GLTF/WebGL pipelines are gone. The app is now a
> 2D skeletal animation studio with a real frame-rendered video export.

---

## What's inside

| System | What it does |
|---|---|
| **2D bone rigs** | Hierarchical bones with pivots at anatomical joints. `humanoid_v1` (Root→Hips→Torso→Neck→Head→arms/legs, 20+ bones) and `quadruped_v1` (Root→Body→Neck/Head→4×(Upper/Lower/Paw)→Tail×4, 22 bones). Children follow parents — rotating a thigh moves the knee, not the hips. |
| **14 standard animations** | Idle, Walk, Run, Sit, Sleep, Talk, Jump, Wave, Action, Happy, Sad, Think, Turn, Fall — every character, same engine. Humanoid walk is a real gait (contact/down/passing/up, counter-swinging arms, weight shift, head stabilization); quadruped walk is the diagonal pattern FL+BR → FR+BL with body bounce, head counter-nod, tail follow-through and ear flop. |
| **Character engine** | Keyframe clips with Linear/EaseIn/EaseOut/EaseInOut per-bone tracks, a locomotion state machine (walk_start/walk_stop blending), procedural talk visemes + blink scheduler, layered gestures. Any character can replace the Tiger — no per-character code. |
| **Characters** | Tiger (default, quadruped), BD Farmer, Village Girl, School Teacher (humanoids) + unlimited prompt-generated variants + imported PNG characters. |
| **16:9 editor** | 1920×1080 default (1280×720 / 854×480 presets), ratio locked. Pinch zoom, pan, drag reposition, fullscreen. Composition layers: Background / Character / Character Shadow / Effects / Foreground with show-hide + lock. |
| **Backgrounds** | 15 built-ins across Nature/Village/City/Room/Office/Street/Forest/Farm/School/Studio/Night/Day/Fantasy + gallery upload (PNG/JPG/WEBP, Cover/Contain/Fit + scale/offset), gradients, solids, transparent. Brightness/contrast/blur/opacity per background. |
| **Timeline** | Second marks, playhead, keyframe dots, loop range, frame stepping, speed 0.25–2×. |
| **REAL video export** | The composition is **rendered frame-by-frame** (timeline → rig solver → background → character → effects → composite) and encoded with **FFmpeg (libx264)** to MP4. *Never* screen recording — the exported file contains exactly the 16:9 canvas, zero editor UI. Also GIF (pure-Dart GIF89a encoder with median-cut palette + Floyd–Steinberg dithering), PNG, and PNG sequences. 1080p/720p/480p × 24/30/60fps × Low→Ultra quality. |
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
scene/        scene_renderer — one 16:9 frame → ui.Image (used by editor AND export)
export2d/     export_service2d (MP4/PNG/sequence) + gif_encoder (pure Dart GIF89a)
screens/      editor (canvas, panels, timeline, export dialog), characters, settings
state/        editor_provider, library2d_provider, shell_provider (Provider only)
```

## Tests

`flutter test` — 33 tests covering the rig hierarchy, gait mechanics (walk phase
alternation, counter-swing, bounce; quadruped diagonal pairs), state machine
transitions, talk/blink layering, persistence round-trips, the GIF encoder
(GIF89a header, NETSCAPE loop, palette) and the character.json contract
(all 14 animations, keyframe track shape, diagonal-pair phase).
