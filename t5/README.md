# Tilt Five port — setup & verification

This folder holds the Tilt Five AR integration for Wayang. Everything is gated
behind runtime detection, so the game still runs as a normal flat-screen build
(keyboard + mouse) on machines without the Tilt Five hardware/driver — including
the macOS dev machines, where the extension binaries don't exist at all.

## What's in the repo

- `addons/tiltfive/` — the TiltFiveGodot4 plugin **v1.1.0** (GDScript release),
  Windows-only binaries. `compatibility_minimum = 4.1.2`, so it should load on
  Godot 4.6; watch the Windows console for GDExtension init errors and report
  any (don't work around silently).
- `t5/t5_runtime.gd` — autoload (already registered in `project.godot`). Detects
  the interface, spawns the `T5Manager` + `T5Gameboard` at runtime, tracks rigs,
  and injects wand input. Contains **no static Tilt Five type references** so it
  compiles everywhere.
- `t5/wand_pointer.gd` — per-wand laser pointer for the world-space menus.
- `project.godot` — adds the `T5Runtime` autoload and `xr/shaders/enabled=true`.

The three menus (`main_menu/main_menu.gd`, `pause_menu.gd`, `win_screen.gd`) each
expose `wants_pointer()` / `pointer_hover(area)` / `pointer_click(area)` and join
the `t5_pointer_menu` group. The mouse path is unchanged; the wand drives the
same code.

## One-time setup on Windows (with hardware)

The plugin is intentionally **not enabled** in the committed `project.godot`,
because enabling it forces `addons/tiltfive/T5Interface.gd` to compile at
startup — which references the extension type `TiltFiveXRInterface` and hard-
crashes the game (debugger break) on any machine where the extension isn't
loaded, e.g. macOS. So enabling is a per-Windows-machine step:

1. Install the Tilt Five driver **1.4.1+** and connect the glasses via SuperSpeed
   USB.
2. Open the project in Godot 4.6 on Windows.
3. **Project → Project Settings → Plugins → enable "Tilt Five".** This adds the
   `T5Interface` autoload.
4. Make sure `T5Interface` is ordered **before** `T5Runtime` in
   Project Settings → Autoload (drag it above). `T5Runtime` also re-checks and
   initialises the interface deferred, so order isn't fatal, but before is
   cleanest.
5. **Do not commit** the resulting `T5Interface` autoload line or the
   `[editor_plugins] enabled=...` line back to `project.godot` — they break the
   macOS devs. Keep them local (or gitignore that diff).

## Controls (wand)

| Wand input        | Action                                                    |
|-------------------|-----------------------------------------------------------|
| Stick left/right  | Player 1 (Anoman) tilt — `p1_left` / `p1_right`, analog   |
| Trigger           | In a menu: click the pointed button. In-game: `p1_attack` |
| T5 button / A     | Toggle pause (`ui_cancel`)                                |

Keyboard/gamepad still work for both players, so P2 (and P1) can play on the
spectator monitor. Future: gyro/wand-orientation → analog P1 tilt (extension
point marked in `t5_runtime.gd::_process`).

## Tuning knobs (`t5/t5_runtime.gd`)

- `BOARD_CONTENT_SCALE` (default `12.0`) — how many world units the physical
  0.7 m board spans. The gameplay quad is ~6 units wide; try 10–15.
- `BOARD_ORIGIN` (default `(0, -3.0, -0.5)`) — where the diorama's ground centre
  sits on the board, so the puppet stage stands upright facing the viewer.
- To see the board outline while tuning, set `show_at_runtime = true` on the
  gameboard (add it next to the `content_scale` set call).

## Hardware verification checklist (can only be done on Windows + glasses)

1. Console is clean of GDExtension init errors on 4.6; `XRServer.find_interface("TiltFive")`
   is non-null (T5Runtime prints "interface detected" instead of "unavailable").
2. Glasses connect → the puppet stage appears upright on the board. Tune
   `BOARD_CONTENT_SCALE` / `BOARD_ORIGIN`.
3. Fog renders in the glasses (it now lives on the arena `WorldEnvironment`,
   not the camera). Under `gl_compatibility` only the standard `fog_*` renders;
   `volumetric_fog_*` is a no-op (pre-existing "Forward+ only" warning is benign).
4. Check transparent Sprite3D sorting from the above/side viewing angles
   (castles, ground, clouds) — they were only ever authored for a head-on view;
   this is the main visual-quality unknown. Fixes if needed: `render_priority`
   or alpha-scissor on the offending materials.
5. The 2D fight (SubViewport → ViewportTexture quad, `Player3D`) renders in the
   glasses (nested-SubViewport sanity check).
6. Wand: laser + hover/click on all three menus; T5 button pauses; stick moves
   Anoman; trigger attacks in-game and clicks in menus; tracking stays live
   while paused (the whole T5 subtree is `PROCESS_MODE_ALWAYS`).
7. Desktop monitor still shows the spectator view; a second player on
   keyboard/gamepad is unaffected.

## What's verified on macOS (no hardware)

- Project boots to flat-screen fallback; `T5Runtime` logs "Tilt Five unavailable".
  The only errors are three "No GDExtension library for macos.arm64" lines
  (expected — Windows-only binaries) plus the game's own pre-existing warnings.
- Full menu → arena → fight → win pipeline runs with mouse + keyboard.
- No T5 node types in any game `.tscn`; no addon `preload` in game code.
