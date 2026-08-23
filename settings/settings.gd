extends Node
## Player preferences (Master volume, fullscreen). Registered as an autoload
## so a preference applies at boot, not only after visiting Settings, and
## persists across launches via user://settings.cfg.

const SAVE_PATH := "user://settings.cfg"
const DEFAULT_VOLUME := 100
const SILENT_DB := -80.0

var master_volume_percent: int = DEFAULT_VOLUME
var fullscreen: bool = false

func _ready() -> void:
	_load()
	apply()

func set_volume(percent: int) -> void:
	master_volume_percent = clampi(percent, 0, 100)
	apply()
	_save()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	_save()

func apply() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		var db := SILENT_DB if master_volume_percent <= 0 else linear_to_db(master_volume_percent / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume_percent = clampi(int(cfg.get_value("audio", "master_volume_percent", DEFAULT_VOLUME)), 0, 100)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume_percent", master_volume_percent)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)
