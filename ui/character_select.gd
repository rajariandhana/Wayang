class_name CharacterSelect
extends CanvasLayer

signal selections_ready(p1: StringName, p2: StringName)

var _ids: Array[StringName] = CharacterRoster.IDS.duplicate()
var _choice := [0, 1]
var _ready := [false, false]
var _cooldown := [0.0, 0.0]
var _title: Label
var _players: Array[Label] = []
var _cards: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := ColorRect.new()
	panel.color = Color(0.06, 0.025, 0.018, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-660, -420)
	box.size = Vector2(1320, 840)
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 54)
	_title.text = "CHOOSE YOUR WAYANG"
	box.add_child(_title)
	var players := HBoxContainer.new()
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override("separation", 80)
	box.add_child(players)
	for player in 2:
		var label := Label.new()
		label.custom_minimum_size = Vector2(560, 210)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 30)
		players.add_child(label)
		_players.append(label)
	_cards = Label.new()
	_cards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cards.add_theme_font_size_override("font_size", 24)
	box.add_child(_cards)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "P1: WASD + C     P2: IJKL + N\nLeft / right selects • Attack locks in • Attack again unlocks"
	hint.add_theme_font_size_override("font_size", 25)
	box.add_child(hint)
	_refresh()

func reset_choices() -> void:
	_choice = [0, 1]
	_ready = [false, false]
	_refresh()

func _process(delta: float) -> void:
	for p in 2:
		_cooldown[p] = maxf(0.0, _cooldown[p] - delta)
		if _cooldown[p] > 0.0:
			continue
		var left := &"p1_left" if p == 0 else &"p2_left"
		var right := &"p1_right" if p == 0 else &"p2_right"
		var attack := &"p1_attack" if p == 0 else &"p2_attack"
		if Input.is_action_just_pressed(left) and not _ready[p]:
			_choice[p] = posmod(_choice[p] - 1, _ids.size()); _cooldown[p] = 0.18; _refresh()
		elif Input.is_action_just_pressed(right) and not _ready[p]:
			_choice[p] = posmod(_choice[p] + 1, _ids.size()); _cooldown[p] = 0.18; _refresh()
		elif Input.is_action_just_pressed(attack):
			_ready[p] = not _ready[p]; _cooldown[p] = 0.18; _refresh()
			if _ready[0] and _ready[1]:
				selections_ready.emit(_ids[_choice[0]], _ids[_choice[1]])

func _refresh() -> void:
	if not is_instance_valid(_title): return
	for p in 2:
		var data := CharacterRoster.definition(_ids[_choice[p]])
		_players[p].text = "PLAYER %d%s\n%s\n%s" % [p + 1, "  READY" if _ready[p] else "", data.name, data.style]
		_players[p].modulate = data.tint
	var cards := []
	for i in _ids.size():
		var data := CharacterRoster.definition(_ids[i])
		cards.append(("[ %s ]" if i in _choice else data.name) % data.name)
	_cards.text = "     ".join(cards)
