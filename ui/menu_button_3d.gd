class_name MenuButton3D
extends MenuControl3D
## Shared interactive 3D menu button: just the label - no background panel
## or border. Hover/press feedback comes from scaling and brightening the
## text itself. The collision box is sized from hit_size (roughly the
## text's own footprint, set per-instance) so there is no "cursor is on the
## button but the click misses" gap between what you see and what you can
## click.

const HOVER_SCALE := 1.06
const HOVER_TIME := 0.15
const PRESS_SCALE := 0.92
const PRESS_DOWN_TIME := 0.06
const PRESS_UP_TIME := 0.16

const LABEL_COLOR := Color(1, 1, 1, 1)
const LABEL_COLOR_HOVER := Color(1.0, 0.86, 0.55, 1.0)

## Label3D has no usable `label_settings` in this Godot build - it must be
## driven through its own flat font/font_size/outline properties instead, so
## the shared button look lives here rather than in a LabelSettings resource.
const BUTTON_FONT_SIZE := 160
const BUTTON_OUTLINE_SIZE := 14
const BUTTON_OUTLINE_COLOR := Color(0.12, 0.05, 0, 1)
const BUTTON_FONT := preload("res://ui/font_button_bold.tres")

@export var text: String = "":
	set(value):
		text = value
		if is_inside_tree():
			_apply_text()
@export var icon: Texture2D = null:
	set(value):
		icon = value
		if is_inside_tree():
			_apply_icon()
@export var hit_size: Vector3 = Vector3(2.0, 0.36, 0.15):
	set(value):
		hit_size = value
		if is_inside_tree():
			_apply_size()
## Not wired to any asset yet - the project has no UI-appropriate sound today.
## Drop a stream here later and play_press() will use it with no code changes.
@export var click_sound: AudioStream

@onready var label: Label3D = $Label
@onready var sprite: Sprite3D = $Sprite3D
@onready var area: Area3D = $Area3D
@onready var collision: CollisionShape3D = $Area3D/CollisionShape3D

func _ready() -> void:
	label.no_depth_test = true
	label.render_priority = 10
	label.modulate = LABEL_COLOR
	label.font = BUTTON_FONT
	label.font_size = BUTTON_FONT_SIZE
	label.outline_size = BUTTON_OUTLINE_SIZE
	label.outline_modulate = BUTTON_OUTLINE_COLOR
	_apply_text()
	_apply_icon()
	_apply_size()
	area.collision_layer = 1

func _apply_text() -> void:
	label.text = text
	label.visible = text != ""

func _apply_icon() -> void:
	sprite.texture = icon
	sprite.visible = icon != null

func _apply_size() -> void:
	var shape := BoxShape3D.new()
	shape.size = hit_size
	collision.shape = shape

func play_hover_in() -> void:
	label.modulate = LABEL_COLOR_HOVER
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector3.ONE * HOVER_SCALE, HOVER_TIME)

func play_hover_out() -> void:
	label.modulate = LABEL_COLOR
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector3.ONE, HOVER_TIME)

func play_press() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * PRESS_SCALE, PRESS_DOWN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", Vector3.ONE * HOVER_SCALE, PRESS_UP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if click_sound:
		var player := AudioStreamPlayer.new()
		player.stream = click_sound
		player.finished.connect(player.queue_free)
		add_child(player)
		player.play()
