# Character Studio 3D

**An offline 3D character animation & preview studio for Android.**

Browse GLB characters, detect their embedded animations automatically, preview
them in an interactive 3D viewer, import new models from device storage, save
favorites and recents, build animation projects, and export real videos —
**all on-device, with zero network access**.

```
No backend · No Firebase · No REST APIs · No AI APIs · No login · No internet
```

| | |
|---|---|
| Platform | Android (minSdk 29 / Android 10+, targetSdk 35) |
| Framework | Flutter (Dart 3) + Kotlin native layer |
| 3D engine | `<model-viewer>` / three.js — **bundled as an app asset, fully offline** |
| State management | Provider (single, consistent solution) |
| Local storage | SharedPreferences (favorites, recents, settings, metadata, projects) |
| Video export | Real on-device recording via Android MediaProjection → H.264 MP4 → MediaStore |

---

## 1. Running the project

Requirements: [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.22+ (validated on 3.24.5), Android SDK 35, JDK 17.

```bash
cd character_studio_3d
flutter pub get
flutter run                # on a connected device / emulator
```

The analysis is clean: `flutter analyze` → **No issues found**.
Both debug and release APKs build successfully (validated):

```bash
flutter build apk --release          # single universal APK
flutter build apk --split-per-abi    # smaller per-device APKs
```

> Output: `build/app/outputs/flutter-apk/app-release.apk`.
> The release build is currently signed with the **debug** key — replace the
> `signingConfig` in `android/app/build.gradle` with your own keystore before
> publishing.

---

## 2. Adding bundled sample GLB files

1. Drop any `.glb` file into `assets/characters/` (optionally with a matching
   `<name>.png` thumbnail).
2. That's it. `assets/characters/` is already declared in `pubspec.yaml`, and
   the app **scans the asset manifest dynamically** at first launch — no Dart
   code changes, no hardcoded lists.

On first start, every bundled GLB is copied once into the app's private
character directory and marked as a "Sample". Deleting a sample in the app
removes it permanently (it is not re-copied).

Bundled samples in this repo (both legal, redistribution-friendly):

| Model | Animations | License |
|---|---|---|
| Fox | Survey · Walk · Run | CC0 1.0 (PixelMannen / TomKranis, via Khronos glTF samples) |
| CesiumMan | 1 walk cycle (unnamed clip → "Animation 1") | CC-BY 4.0 (Cesium GS, via Khronos glTF samples) |

---

## 3. How users import GLB files

**Characters → Import** (or Home → Quick Actions → Import GLB):

1. The Android **system file picker** opens (Storage Access Framework — no
   storage permission required), filtered for `.glb` / `.gltf`
   (`model/gltf-binary`, `model/gltf+json`). If the cross-platform picker
   cannot return a path, the app falls back to a native
   **ACTION_OPEN_DOCUMENT** intent with the same MIME filtering.
2. Select a `.glb` (or a `.gltf` **together with** its `.bin` + textures).
3. The staged pipeline runs with live progress
   (*Reading file → Loading 3D model → Checking skeleton → Checking
   animations → Preparing preview*): magic-byte/chunk validation, glTF 2.0
   check, size limits, `.gltf`→GLB conversion, skeleton/bone extraction.
4. The **Character Validation** screen opens: live 3D preview, ✅/⚠️/❌
   validation report, the Animation Status table
   (Stand/Walk/Run/Sit/Sleep/Talk → Found/Missing/Not Found with confidence),
   manual mapping dropdowns, bone mapping, and **Save Character / Discard**.
5. Saving generates a `char_<timestamp>` id, copies the model into
   `documents/characters/`, stores full metadata + mapping, and the character
   appears in the **Imported Characters** section immediately.

Discarding removes every temporary file. Failures show friendly messages
(e.g. "❌ Invalid GLB file — This 3D model could not be loaded…") with Retry.

Imported characters are ordinary files in the characters directory, so they
are discovered automatically on every launch — `dragon.glb`, `boy.glb`,
`monster.glb` … all work with **zero code changes** (Meshy/mixamo/Blender
exports with named clips are fully supported).

### Animation detection & confidence

The six required actions are detected via alias tables with normalization
(case-insensitive, separators & trailing numbers stripped) and scored:

| Clip name in GLB | Detected as | Confidence |
|---|---|---|
| `Walk_Cycle` | Walk | 98% (auto-mapped) |
| `Walk_Cycle_01`, `walk-cycle`, `Walking` | Walk | auto-mapped |
| `Human_Locomotion_02` | Walk | 71% (suggestion — user confirms) |
| `Idle`, `idle_01`, `default_idle`, `Standing` | Stand | auto-mapped |
| unknown (`Zombie Roar`) | — | never mapped |

Auto-mapping requires ≥ 75% confidence; 40–75% becomes a "⚠️ Missing"
suggestion the user can accept with one tap (*Use?*) or remap manually.
Missing actions are disabled in the UI with the honest message
"*Walk animation is not available for this character*" — nothing is faked.

### Skeleton / humanoid detection

The parser extracts skins → joints (bone names, count, hierarchy depth) and
the humanoid detector matches the 17 standard bones against mixamo
(`mixamorig:LeftArm`), Blender (`upper_arm.L`), Unreal (`upperarm_l`) and
glTF-standard naming. Results appear in the validation report and can be
reviewed/overridden in the **Bone Mapping** sheet. (Runtime animation
*retargeting* between different skeletons is not performed by the rendering
engine — the mapping powers detection, validation and future tooling.)

### Where characters are saved

```
<app documents>/characters/        ← library models + sibling thumbnails
<app documents>/characters_pending/ ← staged imports awaiting Save/Discard
SharedPreferences                   ← metadata (charId, name, mapping,
                                       bones, favorites, recents, settings)
```

Every character's metadata follows this structure (persisted locally):

```json
{
  "id": "char_172839482", "name": "Farmer", "source": "imported",
  "fileName": "farmer.glb", "modelPath": "…", "thumbnailPath": "…",
  "hasSkeleton": true, "boneCount": 52, "animations": [],
  "animationMapping": { "stand": "…", "walk": "…", "run": "…",
                        "sit": "…", "sleep": "…", "talk": "…" },
  "boneMapping": { "hips": "mixamorig:Hips", "head": "mixamorig:Head" },
  "createdAt": "…", "updatedAt": "…"
}
```

### Library management

The Characters screen groups **Recently Used → Built-in → Imported** with
readiness badges (🟢 Ready / 🟡 Partial / 🔴 Invalid), bone counts, imported
dates, search (names + animations), filters, 5 sort modes, and per-card
Details / Rename / **Duplicate** / Share / Delete. Duplicate copies the GLB +
thumbnail with fresh metadata and a new `charId`.

### 3D preview upgrades

Rotate (1 finger) · zoom (pinch) · pan (2 fingers, toggleable) · double-tap
reset · auto-rotate · studio floor grid · 5 lighting presets · 6 backgrounds
with custom color picker · fullscreen mode. Characters are auto-centered and
framed via the engine's bounding-box camera.

---

## 4. Supported animation naming

Animation names are read from the GLB itself — nothing is assumed. The
normalizer (`lib/core/utils/animation_names.dart`) maps raw clip names to
friendly labels while **always preserving the original identifier** internally:

| Raw clip name(s) in the GLB | Displayed as | Icon |
|---|---|---|
| `Walk`, `walk`, `WALKING`, `Walk_01`, `walk_cycle` | Walk | walking |
| `Run`, `running`, `Jog` | Run | running |
| `Idle`, `Standby`, `Breathing`, `TPose` | Idle | person |
| `Armature\|mixamo.com\|Take 001\|Walk` (mixamo) | Walk | walking |
| `Sit`, `SitDown`, `sit_idle` | Sit | chair |
| `Sleep`, `Lying`, `Rest` | Sleep | moon |
| `Talk`, `Speaking`, `Conversation` | Talk | speech |
| `Dance`, `Attack`, `Jump`, `Wave`, `Cry`, `Laugh`, `Fight`, `Fall`, `Clap`, `Punch`, `Kick`, `Die`, `Fly`, `Swim`, … | same, title-cased | mapped per action |
| Anything else (`ZombieAttackSlow`) | `Zombie Attack Slow` | generic animation icon |
| *(unnamed clip)* | `Animation 1`, `Animation 2`… | generic |

Unknown clips are **never hidden** — every clip embedded in the file is listed
and playable.

---

## 5. How animation detection works

Two independent layers, both offline:

1. **Primary — pure-Dart GLB parser** (`lib/services/glb_parser_service.dart`).
   A GLB is a 12-byte header + chunks; the first `JSON` chunk contains the full
   glTF scene graph including the `animations` array. The parser walks the
   container, validates the structure, and extracts:
   - every animation clip name,
   - each clip's duration (max `accessor.max` of its sampler inputs),
   - node/mesh/material/texture/skin counts and the exporter (`asset.generator`).
   Parsing runs in a background isolate (`compute`) so the UI never janks, and
   it powers the whole library grid, search, stats and details screens **before
   any model is rendered**.
2. **Verification — the live engine.** When a character opens, model-viewer
   reports `availableAnimations` over the JS bridge, which is cross-checked
   against the parsed list. A mismatch (e.g. clip cannot be played) surfaces
   the "Animation unavailable" card with Try Again / Choose Another Animation.

```
GLB file ──► GLBParserService ──► Character (+ AnimationClips)
                                     │
Player ──► ThreeDController ──► WebView(model-viewer) ──► three.js/WebGL
                 ▲   ▲                                   (served from the
                 │   └── JS bridge events (load/tick/error/thumbnail)   on-device
                 └── playAnimation(model, name, loop)      loopback server)
```

Architecture roles (see §10 for the file map): `CharacterRepository` owns
library state, `AnimationService` normalizes/aggregates animations,
`ThreeDController` is the reusable generic `AnimationPlayer`, `ThreeDViewer`
is the render surface, `CharacterService`/`GLBParserService` handle discovery
and parsing.

---

## 6. Building the APK

```bash
flutter build apk --release        # universal APK (~59 MB)
flutter build apk --split-per-abi  # ~20-25 MB per architecture
```

Android Studio → *Build → Generate Signed Bundle/APK* for store-ready builds
(set your keystore in `android/app/build.gradle` first).
Build machine needs ~8 GB RAM for the release build (standard Flutter/Gradle
requirements).

---

## 7. Known limitations of the 3D engine

model-viewer (three.js in a WebView) is a deliberate choice: it is the only
mature, offline GLB renderer with skeletal animation, orbit camera and PBR
lighting available to Flutter today. Honest limitations:

- **glTF 2.0 only.** glTF 1.x / COLLADA / FBX / OBJ are not supported
  (`.gltf` 2.x is auto-converted to GLB on import).
- **Animation features:** loop playback, per-clip selection, play/pause/seek,
  speed (`timeScale`) and morph-target animations are supported; **blending
  two clips simultaneously and root-motion retargeting are not**.
- **KTX2 textures require the meshoptimizer codec path** — most exports work;
  exotic texture formats (e.g. some DDS variants) may fail with the "Animation
  unavailable" card.
- Very large models (> ~80 MB) import with a warning and may load slowly or
  skip on low-RAM devices; > 250 MB is refused.
- The renderer draws at device resolution inside a WebView; on very old GPUs
  frame rate drops with heavy scenes (the app shows loading states and never
  hard-crashes on WebGL context loss).
- Backgrounds "Transparent" is displayed as a checkerboard on-screen (true
  alpha export only exists for the PNG poster, which does support
  transparency).

## 8. Video export implementation details

Nothing is faked. The pipeline is a real on-device recording:

1. WebView frame buffers are not directly accessible from Dart, so the app
   uses Android's **MediaProjection** API: a native foreground service
   (`ExportRecordingService.kt`, type `mediaProjection`) mirrors the app
   window into a hardware **MediaRecorder** (H.264 MP4) at the chosen
   resolution (720p/1080p), FPS (24/30/60) and duration (5/10/15/30 s).
2. The MP4 is written **directly into MediaStore**
   (`Movies/Character Studio 3D`) — no storage permission needed on
   Android 10+; the file is visible in every gallery app.
3. The player shows a live `REC` badge with elapsed/remaining time; recording
   auto-stops after the chosen duration or via the Stop button / notification
   action.
4. On success the app reports the real file size and offers **Open / Share /
   Delete** on the actual content URI. If the user denies the projection
   permission, or the encoder fails, a clear error is shown — the app never
   claims success without a file.

Additionally, the 📷 button in the player captures the **current frame as a
real PNG** (model-viewer `toDataURL`) and saves it to
`Pictures/Character Studio 3D` — this is also how automatic thumbnails are
generated the first time a character plays.

---

## 9. Offline-first design

- The 3D engine (`model-viewer.min.js`, ~935 KB) ships inside the APK and is
  served to the renderer by a **loopback HTTP server** (127.0.0.1, random
  port) — no CDN, ever. `network_security_config.xml` permits cleartext
  **only** to 127.0.0.1/localhost; all remote cleartext stays blocked.
  The `INTERNET` permission exists solely for the loopback socket; the app
  works in airplane mode (validated by design — no remote URL appears
  anywhere in the code).
- Favorites, recents (last 40 uses), sort preference, settings, project data
  and character metadata live in SharedPreferences; the characters
  themselves live in the app-private documents folder.

## 10. Project structure

```
lib/
├── main.dart / app.dart                  bootstrap, providers, theme, onboarding gate
├── core/      theme · constants · utils (formatters, animation_names)
├── models/    character · animation_clip · recent_entry · studio_project · viewer_enums
├── services/  glb_parser · gltf_converter · character · animation · thumbnail
│              storage · viewer_server (loopback) · export (native bridge)
├── repositories/ character_repository · project_repository
├── state/     settings_ · library_ · projects_ · export_ · shell_provider
├── navigation/app_shell.dart             IndexedStack + bottom navigation
├── screens/   onboarding · home · characters (+ import) · actions · player
│              export · favorites · projects (+ wizard) · settings
└── widgets/   glass_card · premium_button · character_card · animation_card
               three_d_viewer(+ThreeDController) · search_bar · filter_chip
               empty_state · loading_view · error_view · premium_dialog · …

android/app/src/main/kotlin/…/
├── MainActivity.kt            MethodChannel bridge (recording, gallery, open/share/delete)
└── ExportRecordingService.kt  MediaProjection foreground service → MP4 → MediaStore
```

## 11. Acceptance-test matrix (spec §51)

| # | Test | Where it passes |
|---|---|---|
| 1 | Launch offline → home loads | No network calls anywhere; all resources in-APK |
| 2 | Characters → sample GLBs appear | Bundled Fox + CesiumMan installed on first launch |
| 3 | Animations detected | GLB JSON-chunk parser + engine verification |
| 4/5 | Walk / Run plays | Fox.glb ships `Walk` and `Run` clips |
| 6 | Touch rotate + pinch zoom | model-viewer `camera-controls`, double-tap resets |
| 7 | Favorite persists after restart | SharedPreferences |
| 8 | Recent (character + Walk) persists | Recents store keyed by character+clip |
| 9 | Import GLB → appears automatically | SAF picker → validated copy → directory scan |
| 10 | Imported model's real animations detected | Same parser, zero per-character code |
| 11 | Plays without internet | Entire pipeline is local |
| 12 | Delete imported character | File + metadata + recents removed |
| 13 | Rename updates display name | Metadata-only rename (GLB untouched) |
| 14 | Export produces a real video | MediaProjection → MP4 → MediaStore (verified path) |
| 15 | Airplane mode repeat | Works — see §9 |

## 12. Troubleshooting

- **Blank 3D view** → the loopback server failed to start (extremely rare);
  reopening the screen restarts it.
- **"Not a GLB" on import** → re-export with *embed textures* (single .glb),
  or select the .gltf **plus** its .bin/textures together.
- **Release build OOM on a small machine** → keep the default
  `org.gradle.jvmargs=-Xmx4G` and close other applications.

See `CREDITS.md` for all bundled third-party assets and their licenses.
