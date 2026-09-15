extends CanvasLayer

## Temporary development overlay for diagnosing motion commands. It reports
## opponent-relative directions so the logs match the command diagrams.
var _lines := [[], []]
var _labels: Array[Label] = []

func _ready() -> void:
	layer = 20
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.72)
	panel.position = Vector2(20, 20)
	panel.size = Vector2(760, 300)
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(18, 14)
	box.size = Vector2(724, 270)
	panel.add_child(box)
	for player in 2:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(724, 125)
		box.add_child(label)
		_labels.append(label)
	_refresh()

func bind(fighter1: Fighter, fighter2: Fighter) -> void:
	fighter1.debug_trace.connect(_record.bind(0))
	fighter2.debug_trace.connect(_record.bind(1))
	_lines = [[], []]
	_record("Selected: %s" % fighter1.character_name, 0)
	_record("Selected: %s" % fighter2.character_name, 1)

func _record(message: String, player: int) -> void:
	_lines[player].append(message)
	if _lines[player].size() > 5:
		_lines[player].pop_front()
	_refresh()

func _refresh() -> void:
	if _labels.size() != 2:
		return
	for player in 2:
		_labels[player].text = "P%d INPUT DEBUG\n%s" % [player + 1, "\n".join(_lines[player])]
