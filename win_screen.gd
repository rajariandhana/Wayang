extends Menu3DBase

## How far above the Play Again button (in MenuContainer world units) the name
## entry's bottom edge sits. Kept in world units rather than pixels so the
## overlay tracks the 3D button at any window size or aspect ratio.
const NAME_ENTRY_GAP := 0.18

const TEXT_COLOR := Color(0.98, 0.95, 0.9)
## Matches MenuButton3D.LABEL_COLOR_HOVER so the 2D overlay highlights the same
## warm colour the 3D menu buttons do.
const TEXT_COLOR_HOVER := Color(1.0, 0.86, 0.55)
const PANEL_BG := Color(0.05, 0.03, 0.02, 1.0)
const FIELD_BG := Color(0.09, 0.06, 0.04, 0.8)
const EDGE_COLOR := Color(1.0, 0.86, 0.55, 0.5)
const EDGE_COLOR_FOCUS := Color(1.0, 0.86, 0.55, 0.95)

@onready var menu_container: Node3D = $MenuContainer
@onready var title_label: Label3D = $MenuContainer/TitleLabel
@onready var play_again_button: MenuButton3D = $MenuContainer/PlayAgainButton
@onready var change_characters_button: MenuButton3D = $MenuContainer/ChangeCharactersButton
@onready var leaderboard_button: MenuButton3D = $MenuContainer/LeaderboardButton
@onready var main_menu_button: MenuButton3D = $MenuContainer/MainMenuButton
@onready var quit_button: MenuButton3D = $MenuContainer/QuitButton
@onready var dark_overlay: MeshInstance3D = $DarkOverlay

# --- leaderboard overlay refs ---
@onready var name_entry_ui: CanvasLayer = $NameEntryUI
@onready var name_entry_box: VBoxContainer = $NameEntryUI/Anchor/Box
@onready var name_line_edit: LineEdit = $NameEntryUI/Anchor/Box/NameInput
@onready var submit_score_button: Button = $NameEntryUI/Anchor/Box/SubmitButton
@onready var leaderboard_ui: CanvasLayer = $LeaderboardUI
@onready var leaderboard_panel: PanelContainer = $LeaderboardUI/Anchor/Panel
@onready var leaderboard_label: RichTextLabel = $LeaderboardUI/Anchor/Panel/Box/List
@onready var close_leaderboard_button: Button = $LeaderboardUI/Anchor/Panel/Box/CloseButton

var _menu_rest_position := Vector3.ZERO
var _open := false

func _ready() -> void:
	super._ready()
	_init_panels(menu_container, [])
	_menu_rest_position = menu_container.position
	submit_score_button.pressed.connect(_on_submit_score_pressed)
	name_line_edit.text_submitted.connect(func(_t): _on_submit_score_pressed())
	close_leaderboard_button.pressed.connect(_close_leaderboard)
	LeaderboardApi.leaderboard_fetched.connect(_on_leaderboard_fetched)
	name_entry_ui.visible = false
	leaderboard_ui.visible = false
	_style_overlays()

## The 3D menu must not ray-pick while a 2D overlay is up: Node._input runs
## before Control GUI handling, so an ungated raycast would swallow the click
## meant for the overlay's own buttons (and fire the 3D button behind it).
func _accepts_input() -> bool:
	return _open and not name_entry_ui.visible and not leaderboard_ui.visible

func _process(_delta: float) -> void:
	if name_entry_ui.visible:
		_layout_name_entry()

func _unhandled_input(event: InputEvent) -> void:
	if leaderboard_ui.visible and event.is_action_pressed("ui_cancel"):
		_close_leaderboard()
		get_viewport().set_input_as_handled()

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
	# Prompt for a name once the win menu has settled in. A draw has no winner
	# to record, so it goes straight to the buttons.
	if winner_name != "Draw":
		name_line_edit.text = ""
		name_entry_ui.visible = true
		_layout_name_entry()
		name_line_edit.grab_focus()

func _on_button_activated(btn: Node3D) -> void:
	if btn == play_again_button:
		SceneManager.restart_match()
	elif btn == change_characters_button:
		SceneManager.change_characters()
	elif btn == leaderboard_button:
		_open_leaderboard()
	elif btn == main_menu_button:
		SceneManager.return_to_menu()
	elif btn == quit_button:
		SceneManager.quit_game()

func _main_buttons() -> Array[Node3D]:
	return [play_again_button, change_characters_button, leaderboard_button, main_menu_button, quit_button]

func hide_results() -> void:
	set_menu_active(false)
	visible = false
	_open = false
	dark_overlay.transparency = 0.0
	menu_container.position = _menu_rest_position
	menu_container.scale = Vector3.ONE
	reset_menu()
	# Reset overlay state too, so it doesn't linger into the next match.
	name_line_edit.release_focus()
	name_entry_ui.visible = false
	leaderboard_ui.visible = false

func _on_submit_score_pressed() -> void:
	LeaderboardApi.submit_win(name_line_edit.text)
	name_line_edit.release_focus()
	name_entry_ui.visible = false
	_open_leaderboard()

func _open_leaderboard() -> void:
	leaderboard_label.text = "[center]Loading...[/center]"
	leaderboard_ui.visible = true
	_layout_leaderboard()
	close_leaderboard_button.grab_focus()
	LeaderboardApi.fetch_leaderboard()

func _close_leaderboard() -> void:
	close_leaderboard_button.release_focus()
	leaderboard_ui.visible = false

func _on_leaderboard_fetched(entries: Array) -> void:
	if entries.is_empty():
		leaderboard_label.text = "[center]No scores yet[/center]"
		_layout_leaderboard()
		return
	var text := ""
	for i in entries.size():
		var e = entries[i]
		text += "[center]%d. %s — %d[/center]\n" % [i + 1, e["name"], e["wins"]]
	leaderboard_label.text = text
	_layout_leaderboard()

# --- Overlay placement -----------------------------------------------------
# Both overlays are CanvasLayers sized from script rather than anchored in the
# scene, because their intended position is defined against the 3D menu
# (the name entry) or the live viewport centre (the board), neither of which a
# fixed anchor preset can express.

## Centres the name entry horizontally and rests its bottom edge just above the
## Play Again button, by projecting that button's world position to screen.
func _layout_name_entry() -> void:
	var box_size := name_entry_box.get_combined_minimum_size()
	name_entry_box.size = box_size
	var anchor := _screen_point_above(play_again_button, NAME_ENTRY_GAP)
	name_entry_box.position = anchor - Vector2(box_size.x * 0.5, box_size.y)

func _layout_leaderboard() -> void:
	var panel_size := leaderboard_panel.get_combined_minimum_size()
	leaderboard_panel.size = panel_size
	leaderboard_panel.position = (_viewport_size() - panel_size) * 0.5

func _screen_point_above(node: Node3D, gap: float) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		# No 3D camera yet (e.g. headless tests): fall back to a sane spot in
		# the upper half of the screen rather than pinning to the corner.
		var size := _viewport_size()
		return Vector2(size.x * 0.5, size.y * 0.33)
	return camera.unproject_position(node.global_position + Vector3(0.0, gap, 0.0))

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size

# --- Overlay styling -------------------------------------------------------
# The win screen is a darkened theatre, so the default grey Godot chrome would
# read as a debug window sitting on top of it. Buttons become bare warm text
# like MenuButton3D, and the field/panel get a translucent lacquer look.

func _style_overlays() -> void:
	var field := _flat_box(FIELD_BG, 4, EDGE_COLOR, 10, 24)
	var field_focus := _flat_box(FIELD_BG, 4, EDGE_COLOR_FOCUS, 10, 24)
	name_line_edit.add_theme_stylebox_override("normal", field)
	name_line_edit.add_theme_stylebox_override("focus", field_focus)
	name_line_edit.add_theme_color_override("font_color", TEXT_COLOR)
	name_line_edit.add_theme_color_override("font_placeholder_color", Color(TEXT_COLOR, 0.45))
	name_line_edit.add_theme_color_override("caret_color", TEXT_COLOR_HOVER)

	leaderboard_panel.add_theme_stylebox_override("panel", _flat_box(PANEL_BG, 4, EDGE_COLOR, 16, 56))
	leaderboard_label.add_theme_color_override("default_color", TEXT_COLOR)

	_style_text_button(submit_score_button)
	_style_text_button(close_leaderboard_button)

func _flat_box(bg: Color, border: int, border_color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border)
	box.border_color = border_color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box

func _style_text_button(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR_HOVER)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR_HOVER)
	button.add_theme_color_override("font_focus_color", TEXT_COLOR)
