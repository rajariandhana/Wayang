class_name StatPips
extends Control

## Icon plus a five-segment bar for one stat (speed or power). Mirrored for
## player two so the bar grows away from the screen edge.

enum Icon { SPEED, POWER }

const SEGMENTS := 5

var icon: Icon = Icon.SPEED
var fill_color := Color.WHITE
var mirrored := false
var value := 3:
	set(v):
		value = clampi(v, 0, SEGMENTS)
		queue_redraw()
var unit := 1.0:
	set(v):
		unit = v
		size = Vector2(24.0 + SEGMENTS * 26.0, 16.0) * unit
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit = unit

func _draw() -> void:
	var cy := size.y * 0.5
	var icon_x := size.x - 8.0 * unit if mirrored else 8.0 * unit
	_draw_icon(Vector2(icon_x, cy))
	for i in SEGMENTS:
		var x := 24.0 * unit + i * 26.0 * unit
		if mirrored:
			x = size.x - 24.0 * unit - (i + 1) * 26.0 * unit + 4.0 * unit
		var rect := Rect2(x, cy - 3.0 * unit, 22.0 * unit, 6.0 * unit)
		draw_rect(rect, fill_color if i < value else SelectPalette.LINE)

func _draw_icon(c: Vector2) -> void:
	var r := 7.0 * unit
	if icon == Icon.SPEED:
		var dir := -1.0 if mirrored else 1.0
		for offset in [-0.45, 0.45]:
			var ox: float = offset * r * dir
			draw_polyline(PackedVector2Array([
				c + Vector2(ox - r * 0.4 * dir, -r), c + Vector2(ox + r * 0.4 * dir, 0), c + Vector2(ox - r * 0.4 * dir, r),
			]), fill_color, maxf(1.5, 2.0 * unit), true)
	else:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
		]), fill_color)
