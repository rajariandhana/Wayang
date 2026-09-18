# Anoman attack pass

Open `anoman_attacks.tscn` in Godot and press **F6**. Use **Replay all five**
and **Slow motion (25%)** to compare the poses. Normal matches select these
animations whenever the configured character is Anoman, on either player rig.

## Motion direction

- Quick Strike: compact preparation, straight jab, restrained recoil.
- Rising Strike: low preparation, rising hand arc, elevated finish.
- Low Sweep: body dip, low forward sweep, opposite arm raised for balance.
- Monkey Rush: compressed preparation, forward pitch, trailing support arm.
- Wind Palm: inward gathering pose, two-arm extension, held release.

The existing body and arm textures are unchanged. `script/anoman_animation.gd`
creates instance-local Godot animation timelines for four arm joints and the
body pivot. Each timeline covers startup, active contact, and recovery. Joint
poses mirror onto the opposite player's existing rig, which still uses that
player scene's artwork; character-specific art selection is outside this pass.

Anoman startup times are now 0.12 / 0.16 / 0.18 / 0.20 / 0.24 seconds in the
order above (previously 0.08 / 0.096 / 0.112 / 0.12 / 0.16). Damage, active
windows, recovery durations, and motion commands are unchanged. Wind Palm no
longer uses the shared 90px ranged crouch. Projectile art is unchanged.

Anoman uses 550px maximum horizontal lean on both sides; the second rig's
780px setting compensated for its old shorter swing and overshoots with the
new extended poses. Selecting another character restores the rig's setting.

Reset/interruption restores all five animated joints and cancels the attack's
position tween so an interrupted lunge cannot continue drifting.

## Verification

Run `tests/anoman_animation_test.tscn` headlessly for damage, phase timing,
recovery, reset/interruption, other-character isolation, and sampled hand-shape
reach on both player rigs. The reach probe uses the arena's 1060px separation,
50–100% forward lean including stick-pivot rotation, and a standing defender.
This does not replace interactive testing of all lean
and dodge combinations or Tilt Five hardware.

The source project currently reports missing macOS Tilt Five libraries and
warnings about the original bone rests. These are separate from this pass.
