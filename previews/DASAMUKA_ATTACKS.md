# Dasamuka attack pass

Open `dasamuka_attacks.tscn` in Godot and press **F6**. Replay all five moves
at normal speed or 25% speed. Enable **Show projectiles** to include the
existing flame effect; effects are hidden initially for inspecting poses.

## Motion identity

| Move | Dasamuka motion | Difference from Anoman |
| --- | --- | --- |
| Royal Backhand | Raised, bent-arm preparation; broad downward backhand | Broad descending arc instead of a compact straight jab |
| Overhead Crush | Arms lift overhead; leading arm chops toward the opponent | Starts high and travels down instead of rising from below |
| Low Hook | Hand drags from low behind the body and hooks forward; other hand stays at the hip | Bent low hook instead of a sweep with the supporting arm raised |
| Royal Cleave | Two arms overhead, forward body pitch, deep two-arm finishing pose | Heavy paired cleave instead of a rush with the supporting arm trailing |
| Alengka Flame | One arm invokes overhead, then casts down and out while the other braces at the hip | Asymmetric flame cast instead of a two-arm palm push |

Dasamuka holds his wind-up from 44% to 76% of startup, releases sharply, and
holds the finishing pose into the first 22% of recovery. His return to guard
finishes at 92% of recovery. Anoman's pose data and timing curves are unchanged.

`script/dasamuka_animation.gd` owns the new pose data and timeline. It reuses
the existing rig binding/restoration from `script/anoman_animation.gd`, with
a separate instance-local `dasamuka` animation library. Character selection
routes moves to the appropriate library on either player rig.

## Combat changes

- Damage remains **7 / 10 / 12 / 17 / 12** in the order above.
- Startup is **0.18 / 0.24 / 0.24 / 0.30 / 0.32 seconds** (previously
  0.125 / 0.15 / 0.175 / 0.1875 / 0.25).
- Active windows, recovery durations, attack heights, motion commands, lunge,
  crouch/drop, and projectile behavior are unchanged.
- Dasamuka now uses 550px maximum horizontal lean on either rig. The second
  rig's previous 780px value compensated for its shorter old animation.
- The normal move names now describe their actual motions.

No body, arm, or projectile artwork was changed. The preview uses Dasamuka's
existing second-player puppet scene; this pass does not change how match
scenes choose character artwork.

## Verification

Run `tests/dasamuka_animation_test.tscn` and `tests/anoman_animation_test.tscn`
headlessly. Both use the shared test harness to verify unchanged damage,
startup/active/recovery phases, joint restoration, interruption/reset cleanup,
and legacy-character isolation on both player rigs. Reach is sampled against
the opposite rig's standing hurtbox at the arena's 1060px separation, across
50–100% forward lean, including rotation around the puppet stick.

Dasamuka's wind-up, contact, and recovery were also rendered and inspected.
These checks do not replace interactive dodge/balance testing or Tilt Five
hardware testing. The project's existing missing macOS Tilt Five extension
and bone-rest warnings still appear during local runs.
