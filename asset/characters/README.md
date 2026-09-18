# Character select art

Drop final art here and it shows up on the select screen automatically - no
code or scene changes needed. Lookup is done by `script/character_art.gd`.

## Convention

```
asset/characters/<id>/portrait.png
asset/characters/<id>/select.png
```

`<id>` is one of the roster ids from `script/character_roster.gd`:
`anoman`, `dasamuka`, `bima`, `arjuna`, `gatotkaca`, `sura`, `baya`.

- **`portrait.png`** - grid tile art. Recommended 512x512, transparent PNG,
  head-and-shoulders or bust framing, subject roughly centered.
- **`select.png`** - the big side render shown when that character is
  hovered/locked. Recommended 1024x1600, transparent PNG, full body, feet at
  the bottom of the canvas (the display anchors the puppet by its feet, not
  its center).

## Facing

**Draw everything facing right.** That goes for these two files and for the
puppet art in `asset/Wayang<Name>/` as well - there is one facing in the
project and it is right. Nothing is ever authored facing left.

Player 1 uses the art as drawn. Player 2 is mirrored to face left for you,
both on the select screen and in the arena, so a character works on either
side without a second set of files. The grid tiles are shared between the two
players, so those stay right-facing.

Both files are optional and independent: a character can have a portrait
without a select render, or vice versa. Whatever is missing falls back to a
live placeholder puppet (the existing WayangPlayer/Dasamuka rig, tinted per
character) so nothing is ever blocked on art.

## Example

```
asset/characters/bima/portrait.png
asset/characters/bima/select.png
```

That's the whole integration step. Remove the files to go back to the
placeholder puppet.
