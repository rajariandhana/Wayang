# Sura, Baya and the playable roster

Open `sura_attacks.tscn` or `baya_attacks.tscn` and press **F6** to replay all
five moves. Both previews offer 25% slow motion and optional projectile effects.

## Sura

Sura uses carving fin arcs, arms moving in opposite directions, and a quick
recoil. Fin Slice cuts across, Crest Cutter rises sharply, Undertow Sweep
cuts low with the other arm counterbalancing, Tidal Lunge drives both arms
forward before unwinding, and Sea Spray flicks the leading arm outward.
The dedicated `sura` animation library replaces the borrowed Anoman clips.

Startup: 0.12 / 0.15 / 0.17 / 0.19 / 0.23 seconds.
Damage remains 5 / 7 / 9 / 13 / 9.

## Baya

Baya uses widely separated arms closing like jaws, a planted body, and a
lingering recoil. Snapping Strike closes a short clamp, Rising Jaw lifts the
paired arms, Riverbed Rake drags forward low, River Clamp closes from a wide
open pose, and Sungai Surge scoops forward into a low two-arm press.
The dedicated `baya` animation library replaces the borrowed Dasamuka clips.

Startup: 0.20 / 0.24 / 0.26 / 0.30 / 0.34 seconds.
Damage remains 8 / 10 / 13 / 18 / 13.

Active windows, recovery durations, motion commands, damage and existing
projectile behavior are unchanged. Both characters' upper and lower arm
sprites draw above the body, with the attacking arm above the supporting arm.
Switching away restores the original rig's draw order and rest pose.

## Coming soon

Bima, Arjuna and Gatotkaca retain their data for future use but are unavailable
in the character select. Tiles and hovered stage renders are black silhouettes;
tiles and the player panel say **COMING SOON**. Confirmation is rejected,
random choices use only the four playable fighters, and timeout replaces a
hovered unavailable choice with a playable one. Match creation also rejects
unavailable IDs before disposing an existing match.

## Checks

The four `tests/<character>_animation_test.tscn` scenes check the character's own
animation library, damage, active windows, sampled reach, pose restoration,
reset and interruption on both rigs. Aquatic tests also check both arms are
above the body. `tests/character_select_test.tscn` checks locked-tile appearance,
confirmation rejection, playable random/timeout results and the existing
selection flow. Preview renders were visually inspected. Tilt Five hardware
and all interactive spacing/dodge combinations remain untested.
