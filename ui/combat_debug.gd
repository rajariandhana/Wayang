extends CanvasLayer
## Optional match-only learning aid. Reads the motion buffer without consuming
## it; the fighter remains the sole owner of command recognition.
const COLORS := [Color("efba60"), Color("78c9ee")]
const MUTED := Color("b6b9bd")
var _fighters: Array[Fighter] = []
var _history := [[], []]
var _messages := ["Try a command below", "Try a command below"]
var _message_colors := [Color.WHITE, Color.WHITE]
var _panels: Array[PanelContainer] = []
var _titles: Array[Label] = []
var _states: Array[Label] = []
var _inputs: Array[Label] = []
var _feedback: Array[Label] = []
var _commands: Array = [[], []]
var _root: Control
var _match_active := false
var _refresh_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for p in 2:
		_build_panel(p)
	get_viewport().size_changed.connect(_layout)
	Settings.combo_guide_changed.connect(_refresh_visibility)
	SceneManager.flow_state_changed.connect(func(_state): _refresh_visibility())
	_layout()
	_refresh_visibility()

func _build_panel(p: int) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.07, 0.93)
	style.border_color = COLORS[p].darkened(0.35)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	panel.minimum_size_changed.connect(func(): _layout.call_deferred())
	_panels.append(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_titles.append(_label(box, "COMBO GUIDE", 20, COLORS[p]))
	_states.append(_label(box, "READY", 14, MUTED))
	_inputs.append(_label(box, "Inputs: —", 24, Color.WHITE))
	for key in ["melee_special", "ranged_special"]:
		var command := RichTextLabel.new()
		command.bbcode_enabled = true
		command.fit_content = true
		command.scroll_active = false
		command.mouse_filter = Control.MOUSE_FILTER_IGNORE
		command.add_theme_font_size_override("normal_font_size", 18)
		box.add_child(command)
		_commands[p].append(command)
	_feedback.append(_label(box, "Try a command below", 16, MUTED))
	_label(box, ("C / left trigger" if p == 0 else "N / right trigger") + " = Attack • arrows match your screen side", 13, MUTED)

func _label(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := clampf(size.y / 1080.0, 0.65, 2.0)
	_root.scale = Vector2.ONE * factor
	var logical := size / factor
	var width := minf(530.0, (logical.x - 72.0) * 0.5)
	for p in 2:
		var height := maxf(294.0, _panels[p].get_combined_minimum_size().y)
		_panels[p].size = Vector2(width, height)
		_panels[p].position = Vector2(24 if p == 0 else logical.x - width - 24, logical.y - height - 24)

func set_match_active(active: bool) -> void:
	_match_active = active
	if not active:
		_unbind()
	_refresh_visibility()

func _refresh_visibility() -> void:
	visible = _match_active and Settings.combo_guide_enabled and SceneManager.state == SceneManager.FlowState.PLAYING

func _unbind() -> void:
	for p in _fighters.size():
		if is_instance_valid(_fighters[p]) and _fighters[p].debug_trace.is_connected(_record.bind(p)):
			_fighters[p].debug_trace.disconnect(_record.bind(p))
	_fighters.clear()

func bind(fighter1: Fighter, fighter2: Fighter) -> void:
	_unbind()
	_fighters.assign([fighter1, fighter2])
	_history = [[], []]
	_messages = ["Try a command below", "Try a command below"]
	_message_colors = [MUTED, MUTED]
	for p in 2:
		_fighters[p].debug_trace.connect(_record.bind(p))
		_titles[p].text = "P%d  %s  /  COMBO GUIDE" % [p + 1, _fighters[p].character_name.to_upper()]
	_refresh()

func _record(message: String, p: int) -> void:
	if not Settings.combo_guide_enabled: return
	if message.begins_with("INPUT "):
		_history[p].append(_arrow(message.trim_prefix("INPUT ").get_slice(" ", 0), _fighters[p].facing))
	elif message.begins_with("TRIGGER → ") or message.begins_with("CANCEL → "):
		_history[p].append("●")
		var move_name := message.get_slice(" → ", 1)
		var special := false
		for key in ["melee_special", "ranged_special"]:
			if _fighters[p].character_definition["moves"][key]["name"] == move_name: special = true
		_messages[p] = ("SPECIAL: " if special else "NORMAL: ") + move_name
		_message_colors[p] = Color("8cdda3") if special else COLORS[p]
	elif message.begins_with("TRIGGER ignored"):
		_history[p].append("●")
		_messages[p] = "Not ready — wait for recovery or a hit-confirm."
		_message_colors[p] = Color("eeb975")
	elif message.begins_with("HIT CONFIRM"):
		_messages[p] = "Hit confirmed — a special can follow."
		_message_colors[p] = Color("8cdda3")
	while _history[p].size() > 9: _history[p].pop_front()
	_refresh()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.05
		_refresh()

func _refresh() -> void:
	if _fighters.size() != 2 or _panels.size() != 2: return
	for p in 2:
		var fighter := _fighters[p]
		if not is_instance_valid(fighter): continue
		var state := "READY"
		if fighter._in_hitstun(): state = "HITSTUN"
		elif fighter.combat_state == Fighter.CombatState.ATTACK: state = "ATTACKING"
		elif fighter.combat_state == Fighter.CombatState.COOLDOWN: state = "RECOVERING"
		if fighter._can_cancel(): state = "HIT CONFIRMED • SPECIAL CANCEL OPEN"
		_states[p].text = state
		_inputs[p].text = "Inputs: " + ("  ".join(_history[p]) if not _history[p].is_empty() else "—")
		_feedback[p].text = _messages[p]
		_feedback[p].add_theme_color_override("font_color", _message_colors[p])
		for i in 2:
			var move: Dictionary = fighter.character_definition["moves"][["melee_special", "ranged_special"][i]]
			var progress := _command_progress(fighter, move["motion"])
			var steps: Array[String] = []
			for j in move["motion"].size():
				var color := "8cdda3" if j < progress else "f1e9db"
				steps.append("[color=#%s]%s[/color]" % [color, _arrow(move["motion"][j], fighter.facing)])
			_commands[p][i].text = "[color=#aeb4bc]%s[/color]\n%s  +  Attack" % [move["name"], "  ".join(steps)]

func _command_progress(fighter: Fighter, motion: Array) -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var count := 0
	var last_time := 0.0
	for entry in fighter._motion_history:
		if now - float(entry["time"]) > Fighter.MOTION_WINDOW: continue
		last_time = float(entry["time"])
		if count < motion.size() and entry["dir"] == motion[count]: count += 1
	if count == motion.size() and now - last_time > Fighter.ATTACK_AFTER_MOTION_WINDOW:
		return 0
	return count

func _arrow(direction: String, facing: float) -> String:
	var right := {"F": "→", "B": "←", "U": "↑", "D": "↓", "UF": "↗", "UB": "↖", "DF": "↘", "DB": "↙", "N": "·"}
	var left := {"F": "←", "B": "→", "U": "↑", "D": "↓", "UF": "↖", "UB": "↗", "DF": "↙", "DB": "↘", "N": "·"}
	return String((right if facing >= 0.0 else left).get(direction, direction))
