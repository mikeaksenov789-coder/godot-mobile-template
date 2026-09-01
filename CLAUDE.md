# Godot Mobile Template — Standing Instructions

These are persistent project instructions and apply to all future sessions
and delegated tasks in this repository. They are cumulative: new updates
are added as sections below and do **not** override previous sections
unless explicitly stated otherwise.

## Role: Fast Developer

In this repository Claude Code acts as **Fast Developer** — the executor
who implements tasks delegated by the CTO (the user) quickly and
correctly, while preserving the approved Master Godot 3D Mobile Template
architecture (Godot 4.7.2, built-in Jolt Physics, Android-only/portrait,
cloud-first CI — see `docs/ARCHITECTURE.md`). Implementation work happens
phase by phase; a phase starts only once the CTO explicitly approves it
("APPROVED. Proceed with PHASE N ..."). A standing-instructions update
like this one is a permanent policy, not by itself an instruction to
retroactively rewrite already-shipped phases — see "Compliance status"
below for how this specific rule interacts with existing Phase 3 code.

## PERMANENT AUDIO ASSET RULE

From now on, do **not** generate final production audio with AI.

AI-generated sounds/music are **not** considered shipping-quality by
default. The CTO provides real audio files manually when needed.

Godot Code / Claude Code must support importing and using user-supplied
audio files such as:

- WAV
- OGG
- MP3
- M4A
- MP4 audio/video files (if needed for extraction/reference)

### Rules

1. **Final game audio must come from user-supplied files** whenever
   production audio is required.
2. AI-generated sounds/music may be used **only** as temporary
   placeholders during development.
3. When the CTO uploads audio, Claude Code must:
   - detect what each file is for;
   - convert/transcode if needed;
   - normalize if needed;
   - trim silence if needed;
   - loop music cleanly if needed;
   - import it into Godot correctly;
   - connect it to the existing AudioManager/AudioBank;
   - preserve original quality as much as possible.
4. Do not replace CTO-supplied sounds with AI-generated alternatives.
5. If several candidate sounds are provided for the same purpose, choose
   the best technically suitable one and explicitly say which one was
   used.
6. Keep gameplay code independent from concrete audio files: gameplay
   calls **semantic audio IDs**, while the actual WAV/OGG/MP3 assets live
   in the Presentation/Audio layer.
7. If a required sound is missing, do **not** generate a scary/low-quality
   final AI sound as a substitute. Use a neutral temporary placeholder and
   explicitly mark it as **TEMP** until the CTO uploads the real asset.
8. The same rule applies to music, ambience, UI sounds, impact sounds,
   destruction sounds, machinery, explosions, notifications, and all
   other production audio.

This is a permanent rule for every future game built from this template.

### How this maps onto the existing Foundation/Presentation split

`addons/core/audio/` (Foundation — `AudioManager`) is the shared, generic
playback mechanism every cloned game reuses unchanged: buses, pooling,
volume routing. The **concrete** audio assets for a specific game (real
WAV/OGG/MP3 files, and the semantic-ID → file mapping) belong in that
game's replaceable `presentation/` layer, not in `addons/core/`, exactly
like `VFXBank`/`default_vfx_bank.tres` already does for VFX
(`addons/core/pooling/README.md`) — Foundation ships an empty default
bank, a real game supplies its own populated bank.

### Compliance status (as of Phase 4)

`AudioManager.play_music()/play_sfx()/play_ui()` (Phase 3) currently take
a concrete `AudioStream` argument directly — there is no semantic-ID
lookup or `AudioBank` resource yet, unlike `VFXPool`/`VFXBank` (Phase 4),
which already follow the id → asset pattern this rule requires. Rule 6
is therefore **not yet fully satisfied** by the current Foundation code.
Closing that gap (an `AudioBank` resource + `play_sfx_id()`-style methods
on `AudioManager`, mirroring `VFXBank`/`VFXPool`) is a small, additive
Foundation change — but it touches already-shipped, tested Phase 3 code,
so per this repo's phase-approval workflow it should be scoped and
approved as its own task rather than assumed. Flag this to the CTO before
building it, unless a future standing instruction says otherwise.

## PERMANENT PRODUCTION HANDOFF PROTOCOL

Set by Phase 9 (AI Agent Production Handoff). This is the permanent
governing protocol for every future real-game task built from this
template — the full implementation-ready detail (exact per-game startup
commands, required handoff inputs, the visual/audio integration
workflows, the cloud build/test/screenshot/APK workflow, failure
recovery, and the MVP completion checklist) lives in
`docs/README_FOR_AI_AGENTS.md`; this section is the permanent, always-
loaded summary of the rules that document expands on. Read
`docs/README_FOR_AI_AGENTS.md` in full before starting any real-game
task — this section is not a substitute for it.

1. **Foundation (`addons/core/`) must remain unchanged unless explicitly
   approved.** A clone's `addons/core/` stays byte-identical to the
   template unless the CTO has approved a specific Foundation upgrade
   task — verify with `diff -rq` before every handoff, not just once.
2. **Gameplay/physics must be independent from Presentation.** `game/`
   never hardcodes a concrete visual/audio asset; it references
   `presentation/` resources by path (materials, models, VFX/audio bank
   entries), so Presentation can be replaced without touching Gameplay
   — the exact swap boundary Phase 8's dry-run proved.
3. **Final visuals come from user-supplied/generated target
   references and production assets.** Never invent final art direction
   without them.
4. **AI must NOT invent or keep placeholder visual design when
   production references/assets exist.** Once the CTO supplies a target
   visual package, Presentation must be rebuilt to match it — a
   placeholder left in place after references arrive is not compliant,
   regardless of how the task was originally scoped.
5. **User-supplied audio is authoritative for final production audio.**
   AI-generated audio may only be a temporary, explicitly TEMP-marked
   placeholder — see the PERMANENT AUDIO ASSET RULE above; this line
   does not relax it.
6. **A real game task follows this order, every time:** INPUT PACKAGE →
   GAMEPLAY IMPLEMENTATION → PRESENTATION IMPLEMENTATION → CLOUD BUILD →
   TEST → SCREENSHOT CAPTURE → COMPARE AGAINST TARGET REFERENCES → FIX →
   APK.
7. **Do not declare a real game complete just because it compiles.**
   Completion requires everything in `docs/README_FOR_AI_AGENTS.md`'s
   MVP completion checklist — gameplay/physics/controls/required screens
   actually working, the target visual package actually implemented, no
   shipping placeholders, tests passing, CI green, an APK produced, and
   screenshots visually checked against the target references.
8. **The normal production path must never require the CTO's local PC.**
   Clone, implement, build, test, and screenshot all run in cloud CI.
9. **Godot 4.7.2 + built-in Jolt Physics is the pinned stack** unless the
   CTO explicitly changes it later.
10. Real-game implementation itself is never assumed from a standing
    rule alone — it still requires the CTO's explicit task approval, the
    same phase-by-phase gate every Foundation phase in this repository
    has followed.
