class_name MenuControl3D
extends Node3D
## Base for anything Menu3DBase can hover/click/drag (MenuButton3D,
## MenuSlider3D). Subclasses override the hooks they care about.

func play_hover_in() -> void:
	pass

func play_hover_out() -> void:
	pass

func play_press() -> void:
	pass
