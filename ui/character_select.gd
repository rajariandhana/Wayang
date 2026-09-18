class_name CharacterSelect
extends Node3D

## Fullscreen character select. Built in code inside a SubViewport, then shown
## on a single billboarded 3D quad so it renders for the desktop camera *and*
## for Tilt Five: BILLBOARD_ENABLED reorients the quad per render pass, so
## each eye/rig camera gets a quad that faces it. On desktop the fixed,
## unrotated arena camera makes it the same flat, fullscreen quad.
##
## Layout: each player's character stands huge in their half of a split
## screen, the portrait grid sits over them in the lower centre, names and
## stats in the top corners, control hints along the bottom.

signal selections_ready(p1: StringName, p2: StringName)

enum Phase { CLOSED, SELECTING, SPLASH }

const GRID_COLS := 4
const GRID_ROWS := 2
const RANDOM_INDEX := GRID_COLS * GRID_ROWS - 1 ## Last slot = random.
const MOVE_COOLDOWN := 0.18
const COUNTDOWN_SECONDS := 30.0
const QUAD_Z := 0.6
const DISPLAY_FONT := preload("res://asset/Mageelang.otf")
## Keyboard keys and controller side per player, matching project.godot's
## p1_*/p2_* actions (P1: left stick + left trigger, P2: right stick + right trigger).
const CONTROLS := [
	{"move": ["W", "A", "S", "D"], "select": "C", "side": "L"},
	{"move": ["I", "J", "K", "L"], "select": "N", "side": "R"},
]

var _ids: Array[StringName] = []
var _phase := Phase.CLOSED

var _cursor: Array[int] = [0, 1]
var _locked: Array[bool] = [false, false]
var _resolved: Array[StringName] = [&"", &""]
var _cooldown: Array[float] = [0.0, 0.0]
var _time_left := COUNTDOWN_SECONDS

var _viewport: SubViewport
var _ui_root: Control
var _backdrop: Control
var _hud: Control
var _grid_root: Control
var _tiles: Array[SelectTile] = []
var _cursors: Array[SelectCursor] = []
var _stage_display: Array[CharacterDisplay] = []
var _stage_tag: Array[Label] = []
var _stage_name: Array[Label] = []
var _availability_labels: Array[Label] = []
var _stage_speed: Array[StatPips] = []
var _stage_power: Array[StatPips] = []
var _move_melee: Array[MoveGlyphs] = []
var _move_ranged: Array[MoveGlyphs] = []
var _ready_band: Array[ColorRect] = []
var _hints: Array[ControlHints] = []
var _back_hint: ControlHints
var _timer_label: Label
var _vs_layer: Control
var _vs_label: Label
var _vs_flash: ColorRect

var _quad: MeshInstance3D
var _quad_material: StandardMaterial3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ids.assign(CharacterRoster.IDS)
	_build_viewport()
	_build_ui()
	_build_quad()
	visible = false
	get_viewport().size_changed.connect(_on_viewport_size_changed)

# --- Public API ---------------------------------------------------------

func open() -> void:
	_cursor = [0, 1]
	_locked = [false, false]
	_resolved = [&"", &""]
	_cooldown = [0.0, 0.0]
	_time_left = COUNTDOWN_SECONDS
	_timer_label.text = str(int(COUNTDOWN_SECONDS))
	_timer_label.modulate = Color.WHITE
	_phase = Phase.SELECTING
	_vs_layer.visible = false
	_hud.modulate.a = 1.0
	_ui_root.modulate.a = 0.0
	visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fit_quad_to_camera()
	_refresh_all()
	create_tween().tween_property(_ui_root, "modulate:a", 1.0, 0.25)

func close() -> void:
	_phase = Phase.CLOSED
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

# --- 3D presentation -----------------------------------------------------

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "UI"
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(1920, 1080)
	add_child(_viewport)

func _build_quad() -> void:
	_quad = MeshInstance3D.new()
	_quad.name = "DisplayQuad"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.5, 2.1)
	_quad.mesh = mesh
	_quad_material = StandardMaterial3D.new()
	_quad_material.resource_local_to_scene = true
	_quad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_quad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_quad_material.no_depth_test = true
	_quad_material.render_priority = 20
	_quad_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_quad_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_quad_material.billboard_keep_scale = true
	_quad_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_quad_material.albedo_texture = _viewport.get_texture()
	_quad.material_override = _quad_material
	add_child(_quad)

func _fit_quad_to_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var d: float = cam.global_position.z - QUAD_Z
	if d <= 0.01:
		d = 1.0
	var tl := cam.project_position(Vector2.ZERO, d)
	var br := cam.project_position(vp_size, d)
	var w := absf(br.x - tl.x)
	var h := absf(tl.y - br.y)
	if w <= 0.0 or h <= 0.0:
		return
	(_quad.mesh as QuadMesh).size = Vector2(w, h)
	_quad.global_position = Vector3((tl.x + br.x) * 0.5, (tl.y + br.y) * 0.5, QUAD_Z)
	_viewport.size = Vector2i(roundi(vp_size.x), roundi(vp_size.y))
	_layout()

func _on_viewport_size_changed() -> void:
	if _phase != Phase.CLOSED:
		_fit_quad_to_camera()

# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	_ui_root = _full_rect(Control.new())
	_viewport.add_child(_ui_root)

	_backdrop = _full_rect(Control.new())
	_backdrop.draw.connect(_draw_backdrop)
	_ui_root.add_child(_backdrop)

	var stage_layer := _full_rect(Control.new())
	_ui_root.add_child(stage_layer)
	for p in 2:
		var display := CharacterDisplay.new()
		display.mirrored = p == 1
		stage_layer.add_child(display)
		_stage_display.append(display)

	# Darkens the top and bottom so names and hints stay legible over the art.
	var shade := _full_rect(TextureRect.new()) as TextureRect
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.texture = _shade_texture()
	_ui_root.add_child(shade)

	_hud = _full_rect(Control.new())
	_ui_root.add_child(_hud)
	for p in 2:
		_build_player_panel(p)
	_build_grid()
	_build_timer()
	_build_hints()
	_build_vs_layer()

func _build_player_panel(p: int) -> void:
	var color: Color = SelectPalette.PLAYERS[p]
	var tag := _label(ThemeDB.fallback_font, color)
	tag.text = "%dP" % (p + 1)
	_stage_tag.append(tag)

	var name_label := _label(DISPLAY_FONT, SelectPalette.TEXT)
	_stage_name.append(name_label)
	var availability := _label(ThemeDB.fallback_font, SelectPalette.TEXT_MUTED)
	availability.text = "COMING SOON"
	availability.visible = false
	_availability_labels.append(availability)

	for icon in [StatPips.Icon.SPEED, StatPips.Icon.POWER]:
		var pips := StatPips.new()
		pips.icon = icon
		pips.fill_color = color
		pips.mirrored = p == 1
		_hud.add_child(pips)
		(_stage_speed if icon == StatPips.Icon.SPEED else _stage_power).append(pips)

	for ranged in [false, true]:
		var move := MoveGlyphs.new()
		move.accent = color
		move.mirrored = p == 1
		move.ranged = ranged
		_hud.add_child(move)
		(_move_ranged if ranged else _move_melee).append(move)

	var band := ColorRect.new()
	band.color = Color(SelectPalette.INK, 0.82)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.visible = false
	var ready_label := _full_rect(Label.new()) as Label
	ready_label.text = "READY"
	ready_label.add_theme_font_override("font", DISPLAY_FONT)
	ready_label.add_theme_color_override("font_color", color)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(ready_label)
	_hud.add_child(band)
	_ready_band.append(band)

func _build_grid() -> void:
	_grid_root = Control.new()
	_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_grid_root)
	for id in _ids:
		var tile := SelectTile.new()
		tile.character_id = id
		_grid_root.add_child(tile)
		_tiles.append(tile)
	var random_tile := SelectTile.new()
	random_tile.is_random = true
	_grid_root.add_child(random_tile)
	_tiles.append(random_tile)
	for p in 2:
		var cursor := SelectCursor.new()
		cursor.player_color = SelectPalette.PLAYERS[p]
		cursor.badge_text = "%dP" % (p + 1)
		cursor.tab_top = p == 0
		_grid_root.add_child(cursor)
		_cursors.append(cursor)

func _build_timer() -> void:
	_timer_label = _label(DISPLAY_FONT, SelectPalette.TEXT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_hints() -> void:
	for p in 2:
		var controls: Dictionary = CONTROLS[p]
		var hints := ControlHints.new()
		hints.accent = SelectPalette.PLAYERS[p]
		hints.align = ControlHints.Align.LEFT if p == 0 else ControlHints.Align.RIGHT
		hints.items = [
			{kind = "cluster", keys = controls.move}, {kind = "or"}, {kind = "stick", text = controls.side},
			{kind = "label", text = "Move"}, {kind = "space"},
			{kind = "key", text = controls.select}, {kind = "or"}, {kind = "trigger", text = controls.side},
			{kind = "label", text = "Select"},
		]
		_hud.add_child(hints)
		_hints.append(hints)
	_back_hint = ControlHints.new()
	_back_hint.accent = SelectPalette.TEXT
	_back_hint.align = ControlHints.Align.CENTER
	_back_hint.items = [{kind = "key", text = "Esc"}, {kind = "label", text = "Back"}]
	_hud.add_child(_back_hint)

func _build_vs_layer() -> void:
	_vs_layer = _full_rect(Control.new())
	_vs_layer.visible = false
	_ui_root.add_child(_vs_layer)

	var wash := _full_rect(ColorRect.new()) as ColorRect
	wash.color = Color(SelectPalette.INK, 0.6)
	_vs_layer.add_child(wash)

	_vs_label = _full_rect(Label.new()) as Label
	_vs_label.text = "VS"
	_vs_label.add_theme_font_override("font", DISPLAY_FONT)
	_vs_label.add_theme_color_override("font_color", SelectPalette.TEXT)
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs_layer.add_child(_vs_label)

	_vs_flash = _full_rect(ColorRect.new()) as ColorRect
	_vs_flash.color = Color(1, 1, 1, 0.0)
	_vs_layer.add_child(_vs_flash)

func _full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

func _label(font: Font, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(label)
	return label

func _shade_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(SelectPalette.INK, 0.9), Color(SelectPalette.INK, 0.0),
		Color(SelectPalette.INK, 0.0), Color(SelectPalette.INK, 0.95),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256
	return texture

## Two slanted fields split by a thin rule - each player's side of the screen.
func _draw_backdrop() -> void:
	var s := _backdrop.size
	var top_x := s.x * 0.54
	var bottom_x := s.x * 0.46
	_backdrop.draw_rect(Rect2(Vector2.ZERO, s), SelectPalette.INK)
	_backdrop.draw_colored_polygon(PackedVector2Array([
		Vector2.ZERO, Vector2(top_x, 0), Vector2(bottom_x, s.y), Vector2(0, s.y),
	]), SelectPalette.P1_FIELD)
	_backdrop.draw_colored_polygon(PackedVector2Array([
		Vector2(top_x, 0), Vector2(s.x, 0), s, Vector2(bottom_x, s.y),
	]), SelectPalette.P2_FIELD)
	_backdrop.draw_line(Vector2(top_x, 0), Vector2(bottom_x, s.y), SelectPalette.DIVIDER, maxf(2.0, s.y * 0.003), true)

# --- Layout ----------------------------------------------------------------

func _layout() -> void:
	var vp := Vector2(_viewport.size)
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var w := vp.x
	var h := vp.y
	var u := h / 1000.0
	var margin := w * 0.035
	var top := h * 0.045
	_backdrop.queue_redraw()

	for p in 2:
		var left := p == 0
		var stand_x := w * (0.22 if left else 0.78)
		var display := _stage_display[p]
		display.target_height = h * 1.1
		display.position = Vector2(stand_x, h * 1.04)
		display.refit()

		var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		var column := Rect2(margin if left else w * 0.5, 0, w * 0.5 - margin, 0)
		var tag := _stage_tag[p]
		tag.add_theme_font_size_override("font_size", int(22 * u))
		var name_label := _stage_name[p]
		name_label.add_theme_font_size_override("font_size", int(96 * u))
		for label in [tag, name_label]:
			label.horizontal_alignment = align
			label.position = Vector2(column.position.x, 0)
			label.size = Vector2(column.size.x, 0)
		tag.position.y = top
		name_label.position.y = top + 22 * u
		var availability := _availability_labels[p]
		availability.horizontal_alignment = align
		availability.position = Vector2(column.position.x, top + 142 * u)
		availability.size = Vector2(column.size.x, 0)
		availability.add_theme_font_size_override("font_size", int(28 * u))

		var pips_list := [_stage_speed[p], _stage_power[p]]
		for i in 2:
			var pips: StatPips = pips_list[i]
			pips.unit = u
			pips.position = Vector2(margin if left else w - margin - pips.size.x, top + 136 * u + i * 26 * u)

		var band := _ready_band[p]
		band.size = Vector2(w * 0.3, 120 * u)
		band.position = Vector2(stand_x - band.size.x * 0.5, h * 0.36)
		(band.get_child(0) as Label).add_theme_font_size_override("font_size", int(88 * u))

	var tile := roundf(118 * u)
	var gap := roundf(8 * u)
	var grid_width := tile * GRID_COLS + gap * (GRID_COLS - 1)
	var origin := Vector2(roundf((w - grid_width) * 0.5), roundf(h * 0.585))
	for i in _tiles.size():
		@warning_ignore("integer_division")
		var cell := Vector2(i % GRID_COLS, i / GRID_COLS)
		_tiles[i].position = origin + cell * (tile + gap)
		_tiles[i].size = Vector2(tile, tile)
	for cursor in _cursors:
		cursor.unit = u
	_sync_cursors()

	_timer_label.add_theme_font_size_override("font_size", int(76 * u))
	_timer_label.size = Vector2(240 * u, 0)
	_timer_label.position = Vector2(w * 0.5 - 120 * u, h * 0.03)

	var hint_height := 50 * u
	var hint_y := h - hint_height - 24 * u

	var move_row := 34 * u
	var move_gap := 8 * u
	var move_width := w * 0.32
	var move_y := hint_y - move_gap * 2 - move_row * 2
	for p in 2:
		var x := margin if p == 0 else w - margin - move_width
		var melee := _move_melee[p]
		melee.unit = u
		melee.size = Vector2(move_width, move_row)
		melee.position = Vector2(x, move_y)
		var ranged := _move_ranged[p]
		ranged.unit = u
		ranged.size = Vector2(move_width, move_row)
		ranged.position = Vector2(x, move_y + move_row + move_gap)

	for p in 2:
		var hints := _hints[p]
		hints.unit = u
		hints.size = Vector2(w * 0.4, hint_height)
		hints.position = Vector2(margin if p == 0 else w - margin - hints.size.x, hint_y)
	_back_hint.unit = u
	_back_hint.size = Vector2(w * 0.16, hint_height)
	_back_hint.position = Vector2(w * 0.42, hint_y)

	_vs_label.add_theme_font_size_override("font_size", int(260 * u))

func _sync_cursors() -> void:
	var co_located := _cursor[0] == _cursor[1]
	for p in 2:
		var tile := _tiles[_cursor[p]]
		_cursors[p].position = tile.position
		_cursors[p].size = tile.size
		_cursors[p].inset = 7.0 * _cursors[p].unit if (co_located and p == 1) else 0.0
		_cursors[p].queue_redraw()

# --- Input / state machine --------------------------------------------------

func _process(delta: float) -> void:
	if _phase == Phase.SELECTING:
		_process_countdown(delta)
		_process_input(delta)
		_sync_cursors()

func _process_countdown(delta: float) -> void:
	if not SceneManager.is_character_select_input_enabled():
		return
	_time_left = maxf(0.0, _time_left - delta)
	_timer_label.text = str(ceili(_time_left))
	_timer_label.modulate = SelectPalette.P2 if _time_left <= 5.0 else Color.WHITE
	if _time_left <= 0.0:
		for p in 2:
			if not _locked[p]:
				_lock_player(p, true)

func _process_input(delta: float) -> void:
	if not SceneManager.is_character_select_input_enabled():
		return
	for p in 2:
		_cooldown[p] = maxf(0.0, _cooldown[p] - delta)
		if _cooldown[p] > 0.0:
			continue
		var prefix := "p1_" if p == 0 else "p2_"
		if Input.is_action_just_pressed(prefix + "attack"):
			_toggle_lock(p)
		elif _locked[p]:
			continue
		elif Input.is_action_just_pressed(prefix + "left"):
			_move_cursor(p, -1, 0)
		elif Input.is_action_just_pressed(prefix + "right"):
			_move_cursor(p, 1, 0)
		elif Input.is_action_just_pressed(prefix + "up"):
			_move_cursor(p, 0, -1)
		elif Input.is_action_just_pressed(prefix + "down"):
			_move_cursor(p, 0, 1)
		else:
			continue
		_cooldown[p] = MOVE_COOLDOWN

func _move_cursor(p: int, dx: int, dy: int) -> void:
	var idx := _cursor[p]
	var col := idx % GRID_COLS
	@warning_ignore("integer_division")
	var row := idx / GRID_COLS
	col = (col + dx + GRID_COLS) % GRID_COLS
	row = (row + dy + GRID_ROWS) % GRID_ROWS
	_cursor[p] = row * GRID_COLS + col
	_refresh_stage(p)

func _toggle_lock(p: int) -> void:
	if _locked[p]:
		if not _locked[1 - p]:
			_locked[p] = false
			_resolved[p] = &""
			_ready_band[p].visible = false
		return
	_lock_player(p)

func _lock_player(p: int, from_countdown := false) -> void:
	if _locked[p] or _phase != Phase.SELECTING:
		return
	var idx := _cursor[p]
	var id: StringName = &"" if idx == RANDOM_INDEX else _ids[idx]
	if idx != RANDOM_INDEX and not CharacterRoster.is_playable(id) and not from_countdown:
		return
	if idx == RANDOM_INDEX or not CharacterRoster.is_playable(id):
		var playable := CharacterRoster.playable_ids()
		id = playable[randi() % playable.size()]
		if idx != RANDOM_INDEX:
			_cursor[p] = _ids.find(id)
		_show_character(p, id)
	_resolved[p] = id
	_locked[p] = true
	_ready_band[p].visible = true
	_stage_display[p].flash_lock()
	Sfx.play(&"accent")
	if _locked[0] and _locked[1]:
		_begin_splash()

func _refresh_stage(p: int) -> void:
	var idx := _cursor[p]
	if idx == RANDOM_INDEX:
		_availability_labels[p].visible = false
		_stage_display[p].clear()
		_stage_name[p].text = "?"
		_stage_speed[p].value = 0
		_stage_power[p].value = 0
		_move_melee[p].motion = []
		_move_ranged[p].motion = []
		_move_melee[p].queue_redraw()
		_move_ranged[p].queue_redraw()
		return
	_show_character(p, _ids[idx])

func _show_character(p: int, id: StringName) -> void:
	_stage_display[p].set_character(id)
	var playable := CharacterRoster.is_playable(id)
	_availability_labels[p].visible = not playable
	for item in [_stage_speed[p], _stage_power[p], _move_melee[p], _move_ranged[p]]:
		item.visible = playable
	var data := CharacterRoster.definition(id)
	_stage_name[p].text = String(data.name).to_upper()
	_stage_speed[p].value = clampi(roundi(remap(float(data.speed), 0.75, 1.25, 1.0, 5.0)), 1, 5)
	_stage_power[p].value = clampi(roundi(remap(float(data.power), 0.75, 1.25, 1.0, 5.0)), 1, 5)
	var moves: Dictionary = data.moves
	_move_melee[p].motion = moves.melee_special.motion
	_move_ranged[p].motion = moves.ranged_special.motion
	_move_melee[p].queue_redraw()
	_move_ranged[p].queue_redraw()

func _refresh_all() -> void:
	for p in 2:
		_refresh_stage(p)
		_ready_band[p].visible = false

# --- VS splash ---------------------------------------------------------

func _begin_splash() -> void:
	_phase = Phase.SPLASH
	_vs_layer.visible = true
	_vs_layer.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_hud, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(_vs_layer, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.15)
	tween.tween_callback(_vs_flash_hit)
	tween.tween_interval(0.9)
	tween.tween_property(_ui_root, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_finish_splash)

func _vs_flash_hit() -> void:
	Sfx.play(&"accent")
	_vs_flash.color.a = 0.8
	create_tween().tween_property(_vs_flash, "color:a", 0.0, 0.35)

func _finish_splash() -> void:
	selections_ready.emit(_resolved[0], _resolved[1])
