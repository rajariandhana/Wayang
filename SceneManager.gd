extends Node

const main_menu: String = "res://main_menu/main_menu.tscn"
const game_scene: String = "res://arena.tscn"

func change_scene(scene: String) -> void:
	get_tree().change_scene_to_file(scene)

func quit_game() -> void:
	get_tree().quit()
