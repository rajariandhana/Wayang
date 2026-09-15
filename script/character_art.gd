class_name CharacterArt
extends RefCounted

## Looks up per-character select-screen art with a single, predictable
## convention: res://asset/characters/<id>/portrait.png and select.png.
##
## Real art for the seven fighters is still being made. Until a character's
## files exist, the select screen falls back to the existing rig art: a live
## puppet for the big side render and a head crop of the rig's body sprite for
## the grid tile. Dropping the two PNGs into a character's folder is the whole
## integration step - no script or scene edits required.

const ART_DIR := "res://asset/characters/"

## Which fighter rig stands in for a character before its own art exists.
## Purely a display choice for the select screen - it does not affect which
## rig a player actually fights with in the arena (see arena/arena_2d.tscn,
## which is always Fighter1 = fighter_1.tscn, Fighter2 = fighter_2.tscn).
const PLACEHOLDER_RIG := {
	&"anoman": "res://fighter/fighter_1.tscn",
	&"arjuna": "res://fighter/fighter_1.tscn",
	&"sura": "res://fighter/fighter_1.tscn",
	&"dasamuka": "res://fighter/fighter_2.tscn",
	&"bima": "res://fighter/fighter_2.tscn",
	&"gatotkaca": "res://fighter/fighter_2.tscn",
	&"baya": "res://fighter/fighter_2.tscn",
}
const DEFAULT_RIG := "res://fighter/fighter_1.tscn"

## Head-and-shoulders crop of each rig's body sprite, in texture pixels.
const PLACEHOLDER_PORTRAIT := {
	"res://fighter/fighter_1.tscn": ["res://asset/WayangPlayer/body.png", Rect2(250, 50, 380, 380)],
	"res://fighter/fighter_2.tscn": ["res://asset/WayangDasamuka/body.png", Rect2(50, 130, 370, 370)],
}

static func portrait(id: StringName) -> Texture2D:
	return _load_texture(_path(id, "portrait.png"))

static func select_render(id: StringName) -> Texture2D:
	return _load_texture(_path(id, "select.png"))

static func has_portrait(id: StringName) -> bool:
	return ResourceLoader.exists(_path(id, "portrait.png"))

static func has_select_render(id: StringName) -> bool:
	return ResourceLoader.exists(_path(id, "select.png"))

static func placeholder_rig(id: StringName) -> PackedScene:
	var path: String = PLACEHOLDER_RIG.get(id, DEFAULT_RIG)
	return load(path)

static func placeholder_portrait(id: StringName) -> Texture2D:
	var rig: String = PLACEHOLDER_RIG.get(id, DEFAULT_RIG)
	var entry: Array = PLACEHOLDER_PORTRAIT[rig]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(entry[0])
	atlas.region = entry[1]
	return atlas

static func _path(id: StringName, file_name: String) -> String:
	return "%s%s/%s" % [ART_DIR, id, file_name]

static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
