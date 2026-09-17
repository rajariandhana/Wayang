extends Menu3DBase

@onready var menu_container: Node3D = $MenuContainer
@onready var title_label: Label3D = $MenuContainer/TitleLabel
@onready var play_again_button: MenuButton3D = $MenuContainer/PlayAgainButton
@onready var change_characters_button: MenuButton3D = $MenuContainer/ChangeCharactersButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton
@onready var dark_overlay: MeshInstance3D = $DarkOverlay

# --- NEW: leaderboard overlay refs ---
@onready var name_entry_ui: CanvasLayer = $NameEntryUI
@onready var name_line_edit: LineEdit = $NameEntryUI/PanelContainer/VBoxContainer/LineEdit
@onready var submit_score_button: Button = $NameEntryUI/PanelContainer/VBoxContainer/Button
@onready var leaderboard_ui: CanvasLayer = $LeaderboardUI
@onready var leaderboard_label: RichTextLabel = $LeaderboardUI/RichTextLabel

var _menu_rest_position := Vector3.ZERO
var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [])
	_menu_rest_position = menu_container.position
	# --- NEW ---
	submit_score_button.pressed.connect(_on_submit_score_pressed)
	name_line_edit.text_submitted.connect(func(_t): _on_submit_score_pressed())
	LeaderboardApi.leaderboard_fetched.connect(_on_leaderboard_fetched)
	name_entry_ui.visible = false
	leaderboard_ui.visible = false
	_make_button_transparent()

func _accepts_input() -> bool:
	return _open

func show_win(winner_name: String, duration := 0.35) -> void:
	title_label.text = "Draw!" if winner_name == "Draw" else "%s Wins" % winner_name
	_open = true
	reset_menu()
	set_menu_active(false)
	visible = true
	dark_overlay.transparency = 1.0
	menu_container.position = _menu_rest_position + Vector3(2.6, 0.0, 0.0)
	menu_container.scale = Vector3.ONE * 0.9
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(dark_overlay, "transparency", 0.0, duration)
	tween.tween_property(menu_container, "position", _menu_rest_position, duration + 0.1)
	tween.tween_property(menu_container, "scale", Vector3.ONE, duration + 0.1)
	await tween.finished
	set_menu_active(true)
	# --- NEW: prompt for name once the win menu has settled in ---
	if winner_name != "Draw":
		name_line_edit.text = ""
		name_entry_ui.visible = true
		_open = false # let keyboard input reach the LineEdit instead of the 3D menu
		name_line_edit.grab_focus()

func _on_button_activated(btn: Node3D) -> void:
	if btn == play_again_button:
		SceneManager.restart_match()
	elif btn == change_characters_button:
		SceneManager.change_characters()
	elif btn == main_menu_button:
		SceneManager.return_to_menu()
	elif btn == quit_button:
		SceneManager.quit_game()

func _main_buttons() -> Array[Node3D]:
	return [play_again_button, change_characters_button, main_menu_button, quit_button]

func hide_results() -> void:
	set_menu_active(false)
	visible = false
	_open = false
	dark_overlay.transparency = 0.0
	menu_container.position = _menu_rest_position
	menu_container.scale = Vector3.ONE
	reset_menu()
	# --- NEW: reset overlay state too, so it doesn't linger into the next match ---
	name_entry_ui.visible = false
	leaderboard_ui.visible = false

# --- NEW ---
func _on_submit_score_pressed() -> void:
	print("SUBMIT BUTTON CLICKED, name = ", name_line_edit.text)
	LeaderboardApi.submit_win(name_line_edit.text)
	name_entry_ui.visible = false
	_open = true # give input back to the 3D menu buttons
	LeaderboardApi.fetch_leaderboard()
	leaderboard_ui.visible = true

func _on_leaderboard_fetched(entries: Array) -> void:
	push_error("WIN SCREEN LEADERBOARD FETCHED: " + str(entries))
	var text := "[center][b]Leaderboard[/b][/center]\n"
	for i in entries.size():
		var e = entries[i]
		text += "%d. %s — %d\n" % [i + 1, e["name"], e["wins"]]
	leaderboard_label.text = text

func _make_button_transparent() -> void:
	var panel := $NameEntryUI/PanelContainer as PanelContainer
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var empty := StyleBoxEmpty.new()
	submit_score_button.add_theme_stylebox_override("normal", empty)
	submit_score_button.add_theme_stylebox_override("hover", empty)
	submit_score_button.add_theme_stylebox_override("pressed", empty)
	submit_score_button.add_theme_stylebox_override("focus", empty)
	
