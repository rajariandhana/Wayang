class_name SettingsPanel
extends Node3D
## Shared Settings sub-panel, instanced into both main_menu.tscn and
## pause_menu.tscn. Volume is a real draggable slider (MenuSlider3D) - click
## anywhere on the track to jump there, or drag it.

signal back_pressed

@onready var back_button: MenuButton3D = $BackButton
@onready var fullscreen_button: MenuButton3D = $FullscreenButton
@onready var volume_slider: MenuSlider3D = $VolumeSlider
@onready var volume_label: Label3D = $VolumeLabel

func _ready() -> void:
	volume_slider.set_value(Settings.master_volume_percent / 100.0)
	volume_slider.value_changed.connect(_on_volume_changed)
	_refresh()

func _handle_menu_button(btn: Node3D) -> void:
	if btn == back_button:
		back_pressed.emit()
	elif btn == fullscreen_button:
		Settings.toggle_fullscreen()
		_refresh()

func _on_volume_changed(v: float) -> void:
	Settings.set_volume(roundi(v * 100.0))
	_refresh()

func _refresh() -> void:
	volume_label.text = "Volume: %d%%" % Settings.master_volume_percent
	fullscreen_button.text = "Fullscreen: %s" % ("On" if Settings.fullscreen else "Off")
