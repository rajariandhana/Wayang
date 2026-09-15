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
  its center). Drawn facing right - P2's side mirrors it automatically.

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
