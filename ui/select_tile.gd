class_name SelectTile
extends Control

## One slot in the character grid: the character's portrait, cropped to fill.
## The last slot (is_random) has no character and shows a "?" mark instead.

const DISPLAY_FONT := preload("res://asset/Mageelang.otf")

@export var character_id: StringName = &""
@export var is_random := false

var _mark: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if is_random:
		_mark = Label.new()
		_mark.text = "?"
		_mark.add_theme_font_override("font", DISPLAY_FONT)
		_mark.add_theme_color_override("font_color", SelectPalette.TEXT_MUTED)
		_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_mark)
	else:
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var art := CharacterArt.portrait(character_id)
		if art:
			image.texture = art
		else:
			# Placeholder rigs share art, so the roster tint is what tells them apart.
			image.texture = CharacterArt.placeholder_portrait(character_id)
			image.modulate = Color.WHITE.lerp(CharacterRoster.definition(character_id).tint, 0.55)
		add_child(image)
	var frame := ReferenceRect.new()
	frame.editor_only = false
	frame.border_color = SelectPalette.LINE
	frame.border_width = 1.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	resized.connect(_on_resized)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SelectPalette.TILE)

func _on_resized() -> void:
	if _mark:
		_mark.add_theme_font_size_override("font_size", int(size.y * 0.6))
