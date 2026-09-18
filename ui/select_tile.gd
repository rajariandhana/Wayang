class_name SelectTile
extends Control

## One slot in the character grid: the character's portrait, cropped to fill.
## The last slot (is_random) has no character and shows a "?" mark instead.

const DISPLAY_FONT := preload("res://asset/Mageelang.otf")

@export var character_id: StringName = &""
@export var is_random := false

var _mark: Label
var _coming_soon: Label
var _portrait: TextureRect
var unavailable := false

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
		_portrait = image
		unavailable = not CharacterRoster.is_playable(character_id)
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
		if unavailable:
			image.modulate = Color.BLACK
			var band := ColorRect.new()
			band.color = Color(SelectPalette.INK, 0.92)
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			band.anchor_top = 0.65
			add_child(band)
			_coming_soon = Label.new()
			_coming_soon.text = String(CharacterRoster.definition(character_id).name).to_upper() + "\nCOMING SOON"
			_coming_soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_coming_soon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_coming_soon.add_theme_color_override("font_color", SelectPalette.TEXT)
			_coming_soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_coming_soon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_coming_soon.anchor_top = 0.65
			add_child(_coming_soon)
	var frame := ReferenceRect.new()
	frame.editor_only = false
	frame.border_color = SelectPalette.LINE
	frame.border_width = 1.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	resized.connect(_on_resized)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("675c50") if unavailable else SelectPalette.TILE)

func _on_resized() -> void:
	if _coming_soon:
		_coming_soon.add_theme_font_size_override("font_size", maxi(10, int(size.y * 0.105)))
	if _mark:
		_mark.add_theme_font_size_override("font_size", int(size.y * 0.6))
