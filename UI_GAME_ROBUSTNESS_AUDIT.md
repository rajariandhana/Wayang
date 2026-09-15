# UI and game robustness audit

Audited 9 September 2026 with Godot 4.6.2 on macOS. Findings only; no game implementation changes.

## Assessment and coverage

The active desktop game completes a match, displays a winner, resets on replay, and returns to the main menu. However, pause-menu hit testing and pause-time combat behavior need correction before release. Eight actionable findings follow: two P1, five P2, and one P3. P1 means high-priority functional failure; P2 means a normal-priority defect; P3 means a lower-priority usability issue.

Reviewed the configured main scene, shared 3D controls, instructions, settings, pause/win screens, HUD, active fighter/hitbox/hurtbox logic, scene management, input map, Tilt Five runtime/pointer, and export configuration. Older prototype scenes are not the active gameplay path and were not gameplay-tested. Third-party Tilt Five internals were not exhaustively audited.

Runtime validation used temporary scripts outside the repository, actual scene instances, physics raycasts, and injected gameplay actions. Visual validation rendered the main menu, instructions, settings, arena, and pause screen at desktop window sizes around 1280×800 and 1152×720. This is not a certification of every display, controller, or export target.

## Findings

### 1. P1 — Hidden win-screen buttons intercept pause-menu clicks

**Evidence:** `ui/menu_3d_base.gd:42–54`, `pause_menu.gd:56–63`, `win_screen.tscn`.

Both hidden menus initialize their main panels with collision layer 1. Hiding a parent does not remove its physics colliders. The pointer query returns the first area without filtering out closed menus.

**Reproduction:** Load the arena, open pause, wait for its entrance animation, and raycast through each visible button center. Settings hits `/WinScreen/MenuContainer/MainMenuButton/Area3D`; Main Menu hits `/WinScreen/MenuContainer/QuitButton/Area3D`. The pause controller cannot resolve these foreign colliders, so the intended buttons do not activate. Resume, How to Play, and Quit hit their own colliders in this check.

**Fix:** Enable collision only for the currently open menu and its active panel. Disable all menu colliders on close and during blocked transitions. Validate menu/panel eligibility again at pointer dispatch, including wand clicks.

**Acceptance:** Every visible pause/win button resolves to its own control before and after replay; closed menus produce no ray hits.

### 2. P1 — Combat timers continue while the game is paused

**Evidence:** `Util.gd:3–4`, `fighter/fighter.gd:106–126`, `script/hurtbox.gd:20`.

The shared timer helper creates timers that process during pause. Fighter animations and physics stop, but attack duration, cooldown, and invulnerability waits keep advancing.

**Reproduction:** Start an attack and immediately pause. After 0.4 seconds, hitbox monitoring is false while the attack animation is still at position 0. Start cooldown and pause for 2.2 seconds; the ready indicator returns to opacity 1 while paused. Both were observed at runtime.

**Fix:** Make gameplay waits pause-aware, with explicit cancellation or state checks when death or scene disposal invalidates an operation. Preserve always-processing menu animations separately.

**Acceptance:** Pausing at attack startup, mid-attack, cooldown, and invulnerability preserves the remaining gameplay duration and animation state until resume.

### 3. P2 — Overlapping close animations can dismiss a newly opened pause menu

**Evidence:** `pause_menu.gd:62–63,79–96`.

Closing leaves `_open` true until a tween finishes and does not prevent a second close operation. Every pending completion unconditionally hides the menu and unpauses the tree.

**Reproduction:** Close pause, close again 0.3 seconds later, reopen after the first completion, and let the second completion run. Runtime output reports `open=false paused=false visible=false` for the newly reopened menu.

**Fix:** Use explicit opening/open/closing/closed states; make close idempotent; cancel or invalidate superseded tweens and completion callbacks.

**Acceptance:** Repeated Escape/Resume input never creates competing close operations or unexpectedly resumes gameplay after reopening.

### 4. P2 — Disconnecting one of two Tilt Five rigs leaves its movement action held

**Evidence:** `t5/t5_runtime.gd:110–125`.

The removed wand reference is cleared immediately, but movement actions are released only when the last rig is removed. The absent wand no longer reaches the normal stick-release path.

**Reproduction:** With two mock rigs registered and P1 right held, remove P1's rig. `Input.is_action_pressed("p1_right")` remains true. This tests the real lifecycle handler with mock nodes; physical hot-unplug remains unverified.

**Fix:** Release the departing player's owned directions and attack latch on every removal, independently of remaining rigs. Preserve the other player's state.

**Acceptance:** Removing either rig while moving/attacking stops only that player's injected input; reconnect restores a usable assignment.

### 5. P2 — Wand button movement bypasses input cleanup tracking

**Evidence:** `t5/t5_runtime.gd:246–253,266–292,301–317`.

Button 1/2 press actions without setting the ownership flags consulted by `_release_wand_actions()`. Cleanup therefore cannot clear button-only movement when the corresponding release is lost, including on disconnect. Stick and button paths also share actions without independently combining their held states.

**Reproduction:** Invoke the real P1 button-1 handler during gameplay, then `_release_wand_actions()`. P1 left remains pressed; observed at runtime without hardware.

**Fix:** Track button and stick contributions per player and compute their combined action strength. Clear every owned contribution on disconnect/menu entry; do not clear unrelated physical-input ownership.

**Acceptance:** Hold/release buttons and sticks in different orders; enter/exit pause and disconnect. No stuck directions or premature releases occur.

### 6. P2 — Keyboard/controller users cannot navigate the menus

**Evidence:** `ui/menu_3d_base.gd:71–85` and the shared pointer interface.

Menu dispatch supports mouse interaction and wand pointing, but has no keyboard/gamepad focus, navigation, accept, or slider adjustment. Keyboard gameplay is documented and controller gameplay is configured, yet those users need a mouse or wand to start, replay, and change settings. Main-menu subpanels also lack Escape-to-Back handling.

**Fix:** Add a shared focus model for visible controls, directional navigation, accept/cancel, and slider adjustment with visible focus feedback. Preserve pointer interaction.

**Acceptance:** Complete start → instructions → back → settings → arena → pause → resume → win → replay using keyboard alone and controller alone.

### 7. P2 — Missing attack animation leaves the hitbox enabled

**Evidence:** `fighter/fighter.gd:106–119`.

`combat_attack()` enables the hitbox before checking for the attack animation. Its early-return branch never calls `end_attack()`. Current active fighters contain the animation, so this is a confirmed code-path defect rather than a reproduced normal-match failure.

**Fix:** Validate required animation/dependencies before enabling the hitbox; ensure all exit paths disable it. Death should cancel attack/cooldown work rather than allowing a pending continuation to restore readiness.

**Acceptance:** A test fighter without the attack animation stays harmless and reports a useful setup error; death during attack/cooldown leaves no active attack or ready indicator.

### 8. P3 — Instructions omit controller controls and core game feedback

**Evidence:** `ui/how_to_play_panel.tscn:32–46`, `project.godot` input map, `README.md`.

The visible panel only explains keyboard movement/attack, plus an optional wand line. It omits controller mappings, pause, the objective, and the meaning of the sword cooldown indicator. The README describes D-pad/ABXY attacks while the active input map uses trigger axes.

**Fix:** Document the actual shared-controller sticks/triggers, Escape/pause, health-based victory, and ready/cooldown indicator. Keep README and in-game text consistent with the active bindings.

**Acceptance:** A first-time player can identify both players' controls, pause, understand readiness, and explain how to win without external instruction.

## Verification results and remaining risks

- **Passed:** Scene initialization and HUD binding at health 100/100; independent matches for P1 and P2 each reached victory after ten attacks doing 10 damage each; the correct winner screen opened; replay restored health 100 and unpaused state; return to the configured main menu succeeded in both runs.
- **Passed:** Simultaneous lethal damage produced `Draw!` with gameplay paused.
- **Visual checks:** Main menu, instructions, settings, arena, and pause rendered with legible text at the sampled desktop sizes. Visual appearance alone did not reveal the hidden-collider defect. Win-screen state was checked programmatically, not visually.
- **Startup diagnostics:** After importing assets, runtime still emits unsupported macOS Tilt Five extension errors and repeated `affine_invert: det == 0` errors while instantiating the arena. Bone-length warnings also occur. Desktop fallback nevertheless runs. Investigate the skeleton/rest transforms and platform-specific extension packaging; do not suppress these errors without identifying their sources. No user-visible skeleton failure was established by these checks.
- **Settings inspection:** Volume is clamped and HUD health fractions are bounded. Settings writes and scene-change return codes are ignored; persistence failure cannot currently be reported to the player. Corrupt/unwritable settings, fullscreen transitions, and volume persistence were not fault-injection tested.
- **Lifecycle risks requiring follow-up:** `_attach_rig()` immediately defers itself again when no wand exists, with no frame delay or retry bound. A persistent null wand may spin in deferred processing. Attack input is held for two render frames rather than a physics tick, which needs testing under unusual render/physics rates. These were not exercised with real hardware and are not counted as reproduced findings.
- **Not verified:** Windows builds; real Tilt Five stereo rendering, tracking, reconnect, two-wand arbitration and driver initialization; physical controller hotplug; browser exports/fullscreen/quit behavior; audio quality; long-session memory/performance; ultrawide/portrait/HiDPI/accessibility scaling. Both Web and Windows presets exist, but neither export was built or certified in this audit.

## Fix order and regression checklist

1. Fix menu collider ownership and pause-aware gameplay timing first.
2. Make menu transitions idempotent and wand input ownership explicit.
3. Add non-pointer menu navigation, safe attack exits, and complete instructions.
4. Resolve engine diagnostics, then validate Windows/Tilt Five and Web exports separately.

Regression coverage should include every visible button with other menus hidden, rapid pause/resume, pausing at every combat phase, both players winning, draws, replay loops, dead fighters during pending cooldowns, missing animations, and per-player disconnect with mixed stick/button input. Keep hardware-only results explicitly separate from simulated lifecycle checks.

Temporary evidence from this session: `/tmp/wayang_audit.gd`, `/tmp/wayang_combat_audit.gd`, `/tmp/wayang_visual_audit.gd`, their `wayang-*-output.log` files, and `/tmp/wayang-{main,instructions,settings,settings-720,arena,pause}.png`. Initial runs before asset import were excluded from game-defect conclusions. Shutdown leak diagnostics from harness teardown were not treated as a proven gameplay leak.
