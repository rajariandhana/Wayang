extends Menu3DBase

const ROW_SPACING := 0.1 # vertical gap between rows; tune to your scene scale

@onready var menu_container: Node3D = $MenuContainer
@onready var title_label: Label3D = $MenuContainer/TitleLabel
@onready var entries_container: Node3D = $MenuContainer/EntriesContainer
@onready var back_button: MenuButton3D = $MenuContainer/BackButton
@onready var dark_overlay: MeshInstance3D = $DarkOverlay

var _menu_rest_position := Vector3.ZERO
var _open := false
var _row_nodes: Array[Label3D] = []

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [])
	_menu_rest_position = menu_container.position
	LeaderboardApi.leaderboard_fetched.connect(_on_leaderboard_fetched)

func _accepts_input() -> bool:
	return _open

func show_board(duration := 0.35) -> void:
	title_label.text = "Leaderboard"
	_open = true
	reset_menu()
	set_menu_active(false)
	visible = true
	dark_overlay.transparency = 1.0
	menu_container.position = _menu_rest_position + Vector3(2.6, 0.0, 0.0)
	menu_container.scale = Vector3.ONE * 0.9
	_clear_rows()
	_set_row_text(["Loading..."])
	LeaderboardApi.fetch_leaderboard()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(dark_overlay, "transparency", 0.0, duration)
	tween.tween_property(menu_container, "position", _menu_rest_position, duration + 0.1)
	tween.tween_property(menu_container, "scale", Vector3.ONE, duration + 0.1)
	await tween.finished
	set_menu_active(true)

func hide_board() -> void:
	set_menu_active(false)
	visible = false
	_open = false
	dark_overlay.transparency = 0.0
	menu_container.position = _menu_rest_position
	menu_container.scale = Vector3.ONE
	reset_menu()
	_clear_rows()

func _on_button_activated(btn: Node3D) -> void:
	if btn == back_button:
		SceneManager.hide_leaderboard()

func _main_buttons() -> Array[Node3D]:
	return [back_button]

func _on_leaderboard_fetched(entries: Array) -> void:
	push_error("LEADERBOARD SCREEN FETCHED: " + str(entries))
	var text := "[center][b]Leaderboard[/b][/center]\n"
	if entries.is_empty():
		_set_row_text(["No scores yet"])
		return
	var lines: Array[String] = []
	for i in entries.size():
		var e = entries[i]
		lines.append("%d. %s — %d" % [i + 1, e["name"], e["wins"]])
	_set_row_text(lines)

func _clear_rows() -> void:
	for row in _row_nodes:
		row.queue_free()
	_row_nodes.clear()

func _set_row_text(lines: Array) -> void:
	_clear_rows()
	for i in lines.size():
		var label := Label3D.new()
		label.text = str(lines[i])
		label.font = load("res://asset/Mageelang.otf")
		label.font_size = 20
		label.outline_size = 6
		label.outline_modulate = Color(0.12, 0.05, 0, 1)
		label.modulate = Color(1, 1, 1, 1)
		label.no_depth_test = true
		label.render_priority = 10
		label.position = Vector3(0, -i * ROW_SPACING, 0)
		entries_container.add_child(label)
		_row_nodes.append(label)
