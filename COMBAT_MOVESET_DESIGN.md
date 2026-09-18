# Multi-Attack System Design (for Character Select)

Goal: give each puppet a distinct *feel*, not just a distinct silhouette, so a
character select screen has something real to select between.

---

## 1. What we have right now

From `fighter/fighter.gd`, `script/hitbox.gd`, `script/hurtbox.gd`, `project.godot`:

| Thing | Current state |
| - | - |
| Input per player | One analog stick (`pN_left/right/up/down`) + one analog trigger (`pN_attack`, joypad axis 4/5) |
| Movement | Not physics. `_update_lean()` writes `puppet_visual.position/rotation` directly. Max lean 550px horizontal (Fighter2: 780), 220px vertical |
| Attack | Exactly one: `combat_attack()` plays the 0.2s `"attack"` anim, hitbox monitors for the anim length, then a flat 2.0s `ATTACK_COOLDOWN_TIME` |
| Hitbox | One `Area2D` parented to the swinging hand bone. Fighter1 uses `LHand`, Fighter2 uses `RHand` |
| Hurtbox | One 159 x 488 rectangle at y = +68, child of `Node2D`, so it leans with the puppet |
| I-frames | After being hit, `can_be_hit = false` for `ATTACK_COOLDOWN_TIME` (2s) |
| Free assets | The *other* arm has a full bone chain + `RemoteTransform2D` and **no hitbox**. `asset/fire/` has a 5-frame fire sheet, unused |

### The constraint that shapes everything

Each player has **one stick and one analog trigger**. That is the whole
vocabulary. So the move grammar has to come from three axes we already own:

1. **Stick direction sampled at the instant the trigger is pressed** (5-way is plenty: neutral / up / down / forward / back)
2. **Trigger depth**, because `pN_attack` is bound to a real analog axis, so `Input.get_action_strength()` gives a 0..1 value for free
3. **Timing** (hold to charge, cancel during startup)

No new bindings, no new hardware, works identically on keyboard where the
trigger is a key (depth just reads as 1.0).

### The dodge problem, and why stance beats geometry

Dimas's example: "a low attack dodged by going up on the joystick."

Pure collision geometry will not deliver that cleanly. The hurtbox is 488 tall
(half-height 244) and vertical lean only moves it 220px. Lifting the puppet all
the way up still leaves ~10% of the hurtbox overlapping where it was. Retuning
collision shapes to fix that mid-jam risks breaking every existing hit.

Cheaper and more readable: **stance bands**. Derive a stance from the defender's
vertical lean, tag every move with a height band, and reject the hit in
`Hurtbox._on_area_entered` when the band is dodged.

```gdscript
# script/combat.gd  (class_name Combat)
enum Height { LOW, MID, HIGH }
enum Stance { CROUCHED, NEUTRAL, RAISED }
```

These live in their own `Combat` class, not on `Fighter`. `Fighter` already holds
exported references to `Hitbox` and `Hurtbox`, and both of those need to read the
height enum back, which is the cyclic-dependency parse error GDScript trips on.
`Combat` depends on nothing, so everyone can depend on it.

| Attack height | CROUCHED | NEUTRAL | RAISED |
| - | - | - | - |
| LOW  | HIT | HIT | **WHIFF** |
| MID  | HIT | HIT | HIT |
| HIGH | **WHIFF** | HIT | HIT |

MID attacks cannot be stance-dodged at all. You dodge those by leaning out of
range horizontally. That keeps horizontal spacing meaningful instead of turning
every fight into a vertical guessing game.

A whiffed-by-stance attack should still consume the attacker's full recovery,
and should play a distinct "swish" so both players read what happened. That is
what makes dodging a *reward*, not just a nothing-happened.

---

## 2. Tier 1: the five directional moves (ship these first)

Direction is relative to the **opponent**, not the screen, so both puppets read
the same. Fighter2 needs a `facing` sign of -1 (there is already a
"P2 flipped horizontal movements" fix in history, so use one source of truth).

### 1. Sabetan (neutral) — Quick Slash
The move we have today, but faster and weaker.
Startup 0.08s, active 0.20s, recovery 0.8s, damage 8, MID, reach normal.
The safe poke. Low commitment, low reward. Your default.

### 2. Sabet Bawah (down) — Low Wave (ranged)
Startup 0.28s, active 0.30s, recovery 2.0s, damage 12, **LOW**.
The swing throws a wave of fire along the floor at 2000px/sec with 2800px of
range, which covers a corner-to-corner shot (the arena is at most ~2400px wide
with both fighters leaned into opposite corners). The melee swing still connects
point blank, so it is one move, not two.

This is the anti-camping tool: hiding in a corner no longer puts you out of
reach. Beaten only by the opponent holding UP, and a dodged wave keeps
travelling rather than being consumed, so lifting reads as ducking under it.

Deliberately low damage for how far it reaches. It is a zoning tool that forces
the opponent to move, not a burst. Travel time is what balances it: about 1.1s
across the full arena, which is reactable at range, but only about 0.25s at
close range, which is not. Safe to throw from far away, dangerous to throw in
someone's face.

### 3. Gada Atas (up) — Overhead Crush
Startup 0.18s, active 0.20s, recovery 1.4s, damage 14, **HIGH**, reach -20%.
Comes down from above, faster than the sweep but shorter. Beaten by the opponent
holding DOWN. Pairs with the sweep for a genuine vertical mixup: both hurt, both
lose to the opposite lean, so the defender has to guess which one is coming.

### 4. Tusukan (forward) — Lunge Thrust
Startup 0.20s, active 0.20s, recovery 1.8s, damage 12, MID, longest reach.
Temporarily raises `max_lean_distance` by ~40% for the duration, so the puppet
visibly commits into the opponent's space and *stays there* through recovery.
Cannot be stance-dodged. Dodged by backing out of range, and if you do back out,
the attacker is standing in your face with 1.8s of recovery. Enormous risk.

### 5. Tangkis Mundur (back) — Retreating Cut
Startup 0.10s, active 0.15s, recovery 0.5s, damage 5, MID, reach -30%.
Swings while pulling the puppet backward out of range.
The whiff-punish and the answer to Tusukan. Chip damage only, but the fastest
recovery in the set, so it is what you throw when you read a commitment.

### The resulting loop

```
Low Sweep  beaten by  hold UP        (then punish the 1.6s recovery)
Overhead   beaten by  hold DOWN      (then punish the 1.4s recovery)
Thrust     beaten by  Retreating Cut (back out, poke the 1.8s recovery)
Retreat    beaten by  Low Sweep      (long reach catches the backstep)
Quick Slash beats     anyone who guessed and committed to a slow move
```

Every option loses to something. That is the whole game.

---

## 3. Tier 2: cheap additions that multiply the set

These need no new inputs and no new art.

**6. Trigger depth (light / heavy).**
`Input.get_action_strength(input_attack) > 0.7` picks the heavy variant of
whichever directional move you chose. Instantly doubles a 5-move table to 10
without adding a single binding. On keyboard, everything reads heavy, so gate
this behind a per-character flag if it makes keyboard testing awkward.

**7. Charge hold.**
Hold the trigger past ~0.4s and the puppet visibly rears back (opacity pulse on
the attack indicator, arm winds further). Release for +50% damage and +25% reach.
You are wide open the whole time you charge. Great "big scary character" trait.

**8. Clash.**
If two hitboxes overlap while both are active, nobody takes damage, both puppets
get knocked back, sparks + a stick-clack sound. Roughly ten lines (hitbox already
has `monitoring` and a `fighter` reference). Massively satisfying in a two-player
local game and thematically perfect for puppet sticks knocking together.

**9. Feint cancel.**
Reverse the stick during a move's startup window and the move cancels into a
0.3s recovery instead of firing. Costs almost nothing to implement and adds a
real mind-game layer: bait the dodge, cancel, punish.

**10. Dash step.**
Double-tap a direction for a short burst past `max_lean_distance` with ~0.15s of
i-frames (`hurtbox.can_be_hit = false`). Movement option, no button needed.

**11. Shove (forward at point-blank).**
If Tusukan starts while already inside minimum range it becomes a shove: no
damage, but it pushes the opponent's lean offset back ~300px and freezes their
input briefly. The anti-turtle tool, so hiding at max range and mashing is not
free.

---

## 4. Tier 3: character-defining stretch goals

**12. Fire breath (Dasamuka).** The `Projectile` class from step 1 already does
this. A HIGH-band variant fired from head height, crouch-dodgeable, is a new
`.tscn` plus a move entry. Give Dasamuka both the low wave and the high breath
and Anoman neither, and the zoning matchup writes itself.

**13. Off-hand attack.** The idle arm has a complete bone chain and no hitbox.
Drop a `hitbox.tscn` under `RHand` (or `LHand` for Fighter2) and neutral becomes
a two-hit string: first hand, then the other, with the second hit cancellable.
Costs one node plus one animation.

**14. Counter stance.** Hold back *and* hold the trigger without releasing:
the puppet raises its arm as a guard. The next hit within 0.8s does no damage and
triggers an automatic riposte. Loses to the shove (12). Turtle-proof by design.

---

## 5. How this makes character select mean something

Do **not** hardcode the moves in `fighter.gd`. Two small resources:

```gdscript
# script/move.gd
class_name Move
extends Resource

@export var id: StringName
@export var anim_name: StringName = &"attack"
@export var height: Combat.Height = Combat.Height.MID
@export var damage: int = 10
@export var startup: float = 0.1
@export var active: float = 0.2
@export var recovery: float = 0.9
@export var reach_scale: float = 1.0      # multiplies hitbox CollisionShape scale
@export var lunge: float = 0.0            # px added to lean during active
@export var hitbox_path: NodePath         # which hand swings
@export var heavy_variant: Move = null    # picked when trigger depth > 0.7
```

```gdscript
# script/move_set.gd
class_name MoveSet
extends Resource

@export var neutral: Move
@export var up: Move
@export var down: Move
@export var forward: Move
@export var back: Move
@export var lean_response_rate := 8.0
@export var max_lean_distance := 550.0
@export var max_lean_vertical_distance := 220.0
```

Then `Fighter` gets `@export var move_set: MoveSet`, and a character is just a
`.tres` file. Character select becomes "pick a MoveSet + a sprite set," which is
a two-line change instead of a new subclass per fighter.

### Sample stat identities

**Anoman (white monkey): fast, mobile, low damage.**
`lean_response_rate` 11, lean distance 620, vertical 260. All recoveries about
20% shorter, all damage about 25% lower. Has the dash step (10). Wins by moving
more than the opponent can react to. Rewards a player who dodges.

**Dasamuka (ten-faced king): slow, huge reach, punishing.**
`lean_response_rate` 6, lean distance 780 (already set on Fighter2), vertical 180.
Recoveries about 30% longer, damage about 40% higher. Has the charge hold (7) and
the fire breath (12). Wins by landing two hits a round. Rewards a player who reads.

Same five inputs, completely different game.

---

## 6. Implementation order

1. ~~`Height` enum, `stance` derived from lean y, band check in `Hurtbox._on_area_entered`.~~ **DONE (2026-09-09).** Ships with one LOW test move, Sabet Bawah, on down + attack. Needs playtesting before anything else is built on it: see "How to test step 1" below.
2. Replace `ATTACK_COOLDOWN_TIME` with per-move `startup / active / recovery`. Sample stick direction at press time and pick a `Move`.
3. Author the four new animations. Each is two `rotation` tracks on `LForearm` and `LArm`, same as the existing `"attack"`. Alternatively prototype them as code-driven bone tweens so no editor round-trip is needed, then bake to `.tscn` animations once the timings feel right.
4. Wire `Move` / `MoveSet` resources, move the stats out of the script.
5. Tune reach and lunge per move.
6. Tier 2 additions in order of appeal: clash, trigger depth, feint.

### Traps to watch for

- `ATTACK_COOLDOWN_TIME` is currently doing double duty as both attack recovery **and** the defender's i-frame window in `hurtbox.gd`. Split these. I-frames should be a separate `hitstun` constant, or a fast move will hand the opponent 2s of invulnerability.
- `_physics_process` does `await combat_attack()` then `await combat_cooldown()`. With per-move timing and cancels this needs a real state machine (`READY / STARTUP / ACTIVE / RECOVERY`) driven by a timer, not chained awaits, otherwise a cancel cannot interrupt an in-flight await.

---

## 7. Approved roster and motion-special plan

The initial roster is seven selectable fighters. Mirror matches are allowed.
Every fighter has neutral, up, and down normal attacks, plus two exact motion
specials. One special is always ranged.

| Fighter | Close special | Ranged special | Projectile treatment |
| - | - | - | - |
| Anoman | Monkey Rush — F, D, DF + attack | Wind Palm — D, DF, F + attack | Fast HIGH wind effect |
| Dasamuka | Royal Cleave — F, DF, D, DB, B + attack | Alengka Flame — D, DB, B + attack | Slow LOW flame wave |
| Bima | Pancanaka — D, DF, F + attack | Earth Breaker — B, DB, D, DF, F + attack | LOW ground effect |
| Arjuna | Retreating Strike — D, DB, B + attack | Arrow Shot — D, DF, F + attack | Fast HIGH arrow |
| Gatotkaca | Sky Fist — F, D, DF + attack | Thunder Palm — B, DB, D, DF, F + attack | LOW energy effect |
| Sura | Tidal Lunge — F, D, DF + attack | Sea Spray — D, DF, F + attack | Fast HIGH water spray |
| Baya | River Clamp — D, DB, B + attack | Sungai Surge — B, DB, D, DF, F + attack | Slow, wide LOW river wave |

Motion directions are relative to the opponent. Commands have a 0.75-second
ordered input buffer and a 0.28-second attack window after the final direction.
Extra directions are tolerated, and beginning a diagonal while forward/back is
held records the newly added down input. A normal that connects opens a short
cancel window for one special. The defender is held in hitstun for the
follow-up, but the attack must still physically reach them. Special-to-special
chains are not allowed.

## 8. Low-animation production approach

Use **pose + prop + effect**. This makes attacks readable without requiring
frame-by-frame animation or a bespoke animation for every move.

### Minimum art per fighter

- One puppet body visual.
- One idle pose.
- One three-key attack motion: wind-up, release/impact, recovery.
- A separate weapon or prop only where needed.
- One ranged-effect treatment and optional impact sprite.

The existing Anoman and Dasamuka scenes already have working arm rigs and an
`AnimationPlayer` timeline named `attack`. Their current rotations live in
`fighter/fighter_1.tscn` and `fighter/fighter_2.tscn`; combat plays that timeline
instead of hardcoding arm angles in code. New attack animations should remain
short three-key timelines on the same forearm and arm rotation tracks. Godot
interpolates between the poses.

### Props and effects

- **Arjuna:** attach a static bow to the hand and show a held arrow during the
  wind-up. At release, hide the held arrow and spawn the moving arrow projectile.
- **Baya, Sungai Surge:** use a single heavy forward pose, then spawn a wide
  procedural water wave that travels along the floor. The effect, rather than a
  complex crocodile animation, sells the move.
- **Other ranged attacks:** reuse the shared projectile node with profile data
  for fire, wind, earth, thunder, sea spray, or water. Profiles change the
  effect tint, speed, scale, hit height, trail, and impact without new fighter
  logic.

Screen shake, hit flashes, trails, and impact bursts should supply most of the
perceived force. Finished puppet art can replace the prototype visuals later
without changing character data or combat code.
- Forward/back must resolve through a single `facing` value. There is already a "P2 flipped horizontal movements" fix in git history, so do not add a second place that flips signs.
- `reach_scale` changing the hitbox `CollisionShape2D.scale` at runtime is fine, but reset it in `end_attack()` or reach will drift across moves.
- Hitbox layer/mask is 2/4, hurtbox is presumably 4. If a projectile (12) is added, give it its own layer so it does not clash-cancel against melee hitboxes unintentionally.


---

## 7. How to test step 1

Step 1 is in. `script/combat.gd` is new; `fighter/fighter.gd`, `script/hitbox.gd`,
`script/hurtbox.gd` and `arena/arena_2d.gd` changed. Nothing is committed, so
`git diff` shows the whole change.

Two moves exist right now, both reusing the existing `"attack"` animation:

| Input | Move | Height | Damage | Range | Recovery |
| - | - | - | - | - | - |
| attack, stick neutral | Sabetan | MID | 10 | melee | 1.2s |
| attack, stick **down** | Sabet Bawah | **LOW** | 12 | **full arena** | 2.0s |

The flame sprite is rotated a quarter turn *away* from the direction of travel,
so the wide base leads and the tapering tip trails behind like a comet. Pointing
the tip forward read as a candle sliding sideways.

Sabet Bawah is built as a code-driven tween rather than a new animation: 0.28s of
startup while the puppet drops 150px and steps in, the existing swing played at
0.55x speed, and a travelling wave launched the moment the swing goes live.
Nothing needed keying in the editor.

The wave is `scenes/projectile.tscn` + `script/projectile.gd`, which **extends
Hitbox**. That is the whole trick: `Hurtbox` already accepts anything that
`is Hitbox`, already runs the stance check against `height`, and already ignores
hitboxes belonging to the same fighter, so the receiving side needed no changes
at all. It uses the existing `asset/fire/` frames.

**What to check, in order:**

1. Turn on `debug_combat` on both fighters in the inspector. The console prints the selected move, hits, and dodges.
2. Neutral attack still behaves like the old one. Nothing should feel different.
3. Hold **down** + attack. The puppet should visibly crouch and lunge forward before the swing goes live.
4. Put P2 in the far corner. P1 throws Sabet Bawah. The wave should cross the whole arena and connect. Reaching a corner camper is the point of the move.
5. Have P2 hold **up** as the wave arrives. Console prints `Player 2 DODGED Player 1's attack`, no damage lands, and the wave **keeps travelling** past them rather than vanishing. **This is the whole point of step 1.** If this does not work, nothing else in this document should be built.
6. Have P2 hold **up** while P1 throws the neutral Sabetan point blank. It should still hit. MID is not stance-dodgeable.
7. Tune `speed` (2000) and `max_range` (2800) on the projectile if the wave feels too fast to react to or dies before reaching the corner. Together with `STANCE_THRESHOLD` (0.55), these are the knobs most likely to need work.

**Known balance hole, on purpose:** right now holding UP is a free answer to the
wave, because no HIGH attack exists to punish a raised stance. That is exactly
what move 3, Gada Atas, is for. Do not tune the wave around this until the
overhead exists, or you will overtune it.

**What changed beyond the new feature:**

- I-frames after being hit are now `Combat.HITSTUN_TIME` (0.6s), not the 2.0s attack cooldown. They were sharing one constant, which meant every hit granted 2s of immunity. If hits now feel too frequent, raise `HITSTUN_TIME`, do not re-link it to recovery.
- `combat_attack()` used to `return` early when an animation was missing, leaving the hitbox monitoring forever. It now always reaches `end_attack()`.
- Hitbox reach is per-move and reset in `end_attack()`, so it cannot drift between moves.
- `facing` is assigned once in `Arena2d._assign_facing()` from the fighters' actual positions, so lunges commit toward the opponent. Do not add a second place that flips horizontal signs, there is already a "P2 flipped horizontal movements" fix in git history.
- The per-frame input debug spam is now behind the `debug_combat` flag instead of always on.


---

## 8. Audio and hit feedback

Added 2026-09-09. Two autoloads, registered in `project.godot` after `Settings`.

### `Sfx` (`script/sfx.gd`)

The sound library. Gameplay code says `Sfx.play(&"wave_impact")` and never names
a file, so swapping placeholder audio for real recordings means editing one
table and nothing else.

**To add or replace a sound, edit `LIBRARY` at the top of `script/sfx.gd`.** Each
entry has `files` (candidates, one picked at random per play so repeats vary),
`volume` in dB, and `pitch` as a random range. Random pitch is the cheapest
defence against repetition fatigue and it is on by default for everything.

It runs a pool of 12 `AudioStreamPlayer`s on their own `SFX` bus. The bus is
created at runtime rather than in a `default_bus_layout.tres`, because the
project does not have one and adding a file the open editor also writes is
asking for a conflict. `Settings` still drives `Master`, so the existing volume
slider governs everything; an SFX-only slider can be added later by pointing it
at this bus.

The pool replaced `Fighter`'s single `AudioStreamPlayer`, which cut its own
sound off whenever a second hit landed inside the first one's tail. That is
precisely when a fight is at its loudest, so it was audible.

Current events: `hit_body`, `accent`, `swing`, `dodge`, `wave_launch`,
`wave_impact`.

### `Juice` (`script/juice.gd`)

- `hitstop(duration, scale)` sets `Engine.time_scale` briefly, capped at `MAX_HITSTOP` (0.25s). The timer that ends it passes `ignore_time_scale = true`, or it would be slowed by the very freeze it is meant to end. Overlapping hits are resolved with a token, not a clock reading, so a later hitstop takes ownership and the earlier one silently stands down.
- `shake(target, strength, duration)` decays a random offset on a node's position. Calling it again on a node already shaking refreshes the existing entry rather than adding a second, which would capture the displaced position as the origin and let the node walk away from where it belongs.
- `flash(item, color, duration)` briefly multiplies `modulate`. The original colour is stored on the node, so a second hit landing mid-flash restores to the real colour and not to the flash colour.

Both autoloads use `PROCESS_MODE_ALWAYS` so the pause menu cannot strand a shake
mid-offset.

### Nothing bleeds out of a match

`Engine.time_scale` and the `Sfx` voice pool both live in autoloads that outlive
the scene, so combat feedback has to be explicitly torn down or it follows the
player into the menus:

- `SceneManager.change_scene()` and `quit_game()` call `Juice.reset()` and `Sfx.stop_all()` before transitioning. Everything already routes through SceneManager, so this covers every exit.
- `Juice` has a watchdog in `_process` that forces `time_scale` back to 1.0 whenever the tree is paused or a freeze has outlived `MAX_HITSTOP`. This is the backstop for any path that skips SceneManager.
- Pausing snaps any active shake back to its origin, and `hitstop` / `shake` / `flash` all refuse to start while paused.
- The flash tween uses `TWEEN_PAUSE_PROCESS` so it finishes through a pause instead of leaving a puppet stuck white.

**Fixed 2026-09-09, and worth understanding before touching `hitstop` again.**
The first version stored a deadline in milliseconds and restored speed only if
`Time.get_ticks_msec()` had passed it. A `SceneTreeTimer` counts summed frame
deltas, which can satisfy its own duration a millisecond before the integer
clock agrees. When that happened the restore was skipped and the whole game
stayed at 0.05x until the next hit happened to land on the right side of the
rounding. It looked like the hitstop was tuned far too long, but the durations
were always well under 0.1s: it was simply never ending. It followed the player
into the menus because `time_scale` also drives Tweens, so the pause menu's 0.5s
button animation took ten seconds. Compare tokens, not clocks.

### Why no addon

[Juicee](https://github.com/Kelpekk/Juicee) is the best of the Godot 4 juice
addons and it is MIT licensed, but it requires the Forward+ or Mobile renderer
and this project runs on `gl_compatibility`. Its screen-space shader effects,
which are most of its value, will not work here.

There is a second problem any addon hits: the 2D arena renders into a SubViewport
displayed on a 3D quad (`$ArenaBackdrop/SubViewport/Arena2d`), so there is no
`Camera2D` for a camera shake to grab. Shaking `Arena2d` inside the viewport is
what works, and it has a bonus: the fighters and floor shake while the painted
backdrop holds still.

### Placeholder audio

`asset/sound/generated/placeholder_*.wav` are synthesised stand-ins so the game
is audible today. They are not final art. Replace them:

- [Sonniss GDC Game Audio Bundle](https://gdc.sonniss.com/) — free, royalty-free, no attribution. Best source for impact and whoosh layers.
- [Kenney](https://kenney.nl/assets?q=audio) — CC0, has an Impact Sounds pack.
- [Freesound](https://freesound.org) — check each file's licence, some are CC-BY and need credit. This is where to find **gamelan**: a kempul or gong on a connect and a kendang slap on the sweep is what makes the game sound like wayang instead of like a generic fighter.

The `accent` event exists specifically so the gamelan layer can be tuned
separately from the body-impact layer instead of being baked into one sample.
It is currently a synthesised gong with inharmonic partials, which is the right
shape but not the right sound.

### Watch out for

- `Util.wait` uses `create_timer`, which respects `time_scale`, so a hitstop briefly stretches attack recovery too. That is usually desirable (the whole game leans into the hit) but it is a real coupling, not an accident.
- `Juice.flash` multiplies `modulate`, and there is no HDR under GL Compatibility for values above 1 to bloom into, so the 5x default clamps to white. Lower it if the puppets read as blown out rather than struck.
- The projectile frees itself only after its particles have finished living, since it owns them. Freeing on contact would delete the impact burst mid-flight.
