class_name ControlHints
extends Control

## One row of control hints drawn as icons: a key cluster for movement, stick
## and trigger glyphs for the controller, single keycaps. Directions read as a
## key shape rather than being spelled out as letters.
##
## items: [{kind = "cluster", keys = ["W", "A", "S", "D"]}, {kind = "or"},
##         {kind = "stick", text = "L"}, {kind = "label", text = "Move"},
##         {kind = "space"}, {kind = "key", text = "C"}, {kind = "trigger", text = "L"}]

enum Align { LEFT, CENTER, RIGHT }

var align: Align = Align.LEFT
var accent := Color.WHITE
var items: Array = []:
	set(value):
		items = value
		queue_redraw()
var unit := 1.0:
	set(value):
		unit = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var widths: Array[float] = []
	var total := 0.0
	for item in items:
		var width := _width(item, font)
		widths.append(width)
		total += width
	var x := 0.0
	if align == Align.CENTER:
		x = (size.x - total) * 0.5
	elif align == Align.RIGHT:
		x = size.x - total
	for i in items.size():
		_draw_item(items[i], x, font)
		x += widths[i]

func _pad() -> float:
	return 8.0 * unit

func _cluster_key() -> float:
	return (size.y - 3.0 * unit) * 0.5

func _single_key() -> float:
	return size.y * 0.7

func _label_size() -> int:
	return int(size.y * 0.42)

func _width(item: Dictionary, font: Font) -> float:
	match item.kind:
		"cluster":
			return _cluster_key() * 3.0 + 6.0 * unit + _pad()
		"key":
			var k := _single_key()
			var text_w := font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(k * 0.46)).x
			return maxf(k, text_w + k * 0.6) + _pad()
		"stick":
			return size.y * 0.8 + _pad()
		"trigger":
			return size.y * 0.62 + _pad()
		"or":
			return 16.0 * unit
		"label":
			return font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size()).x + 2.0 * unit
		"space":
			return 40.0 * unit
	return 0.0

func _draw_item(item: Dictionary, x: float, font: Font) -> void:
	var h := size.y
	var cy := h * 0.5
	var edge := maxf(1.0, 1.5 * unit)
	match item.kind:
		"cluster":
			var k := _cluster_key()
			var g := 3.0 * unit
			var keys: Array = item.keys
			_keycap(Rect2(x + k + g, cy - k - g * 0.5, k, k), keys[0], font)
			for i in 3:
				_keycap(Rect2(x + i * (k + g), cy + g * 0.5, k, k), keys[i + 1], font)
		"key":
			var k := _single_key()
			_keycap(Rect2(x, cy - k * 0.5, _width(item, font) - _pad(), k), item.text, font)
		"stick":
			var r := h * 0.4
			var c := Vector2(x + r, cy)
			draw_circle(c, r, SelectPalette.KEY_FACE)
			draw_arc(c, r, 0.0, TAU, 32, SelectPalette.KEY_EDGE, edge, true)
			for dir in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var tip: Vector2 = c + dir * r * 0.84
				var base: Vector2 = c + dir * r * 0.62
				var side: Vector2 = Vector2(-dir.y, dir.x) * r * 0.17
				draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), accent)
			draw_circle(c, r * 0.42, SelectPalette.KEY_EDGE)
			_centered_text(font, item.text, Rect2(c - Vector2(r, r) * 0.42, Vector2(r, r) * 0.84), SelectPalette.TEXT)
		"trigger":
			var w := h * 0.62
			var top := cy - h * 0.42
			var bottom := cy + h * 0.4
			var shape := PackedVector2Array([
				Vector2(x, bottom), Vector2(x + w, bottom), Vector2(x + w, top + h * 0.3),
				Vector2(x + w * 0.78, top + h * 0.06), Vector2(x + w * 0.4, top), Vector2(x, top + h * 0.14),
			])
			draw_colored_polygon(shape, SelectPalette.KEY_FACE)
			var outline := shape.duplicate()
			outline.append(shape[0])
			draw_polyline(outline, SelectPalette.KEY_EDGE, edge, true)
			_centered_text(font, item.text + "T", Rect2(x, top + h * 0.2, w, bottom - top - h * 0.2), accent)
		"or":
			draw_line(Vector2(x + 5.0 * unit, cy + h * 0.2), Vector2(x + 11.0 * unit, cy - h * 0.2), SelectPalette.TEXT_MUTED, edge, true)
		"label":
			draw_string(font, Vector2(x, cy + _label_size() * 0.36), item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size(), SelectPalette.TEXT_MUTED)

func _keycap(rect: Rect2, text: String, font: Font) -> void:
	var lip := maxf(2.0, 3.0 * unit)
	draw_rect(Rect2(rect.position + Vector2(0, lip), rect.size), SelectPalette.KEY_EDGE)
	draw_rect(rect, SelectPalette.KEY_FACE)
	draw_rect(rect, SelectPalette.KEY_EDGE, false, maxf(1.0, 1.5 * unit))
	_centered_text(font, text, rect, accent)

func _centered_text(font: Font, text: String, rect: Rect2, color: Color) -> void:
	var font_size := int(rect.size.y * 0.5)
	var baseline := rect.position.y + rect.size.y * 0.5 + font_size * 0.36
	draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)
