class_name MoveGlyphs
extends Control

## One special move shown as its input, not its name: a chain of direction
## arrows (matching the stick glyph in control_hints.gd) ending in the attack
## pip, plus a small leading mark for melee vs. ranged. This is the same
## icon-only language as the control hints row, just spelling out a specific
## command instead of "any direction".

const DIRS := {
	"F": Vector2(1, 0), "B": Vector2(-1, 0), "D": Vector2(0, 1),
	"DF": Vector2(1, 1), "DB": Vector2(-1, 1),
}

var motion: Array = []
var ranged := false
var accent := Color.WHITE
var mirrored := false
var unit := 1.0:
	set(v):
		unit = v
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if motion.is_empty():
		return
	var step := size.y
	var gap := step * 0.32
	var mark_w := step * 0.7
	var x := mark_w
	var cy := size.y * 0.5
	_draw_kind_mark(Vector2(mark_w * 0.5, cy), step * 0.3)
	x += step * 0.5
	for i in motion.size():
		_draw_direction(Vector2(x, cy), step * 0.42, motion[i])
		x += step + gap
		if i < motion.size() - 1:
			_draw_chevron(Vector2(x - gap * 0.5, cy), step * 0.14)
	_draw_chevron(Vector2(x - gap * 0.5, cy), step * 0.14)
	_draw_attack_pip(Vector2(x, cy), step * 0.42)

## Filled arrowhead (melee, close range) vs. a hollow ring around a bolt
## (ranged) - the same silhouette language as the direction/attack glyphs,
## just marking what kind of special this is before its input plays out.
func _draw_kind_mark(c: Vector2, r: float) -> void:
	if ranged:
		draw_arc(c, r, 0.0, TAU, 24, SelectPalette.TEXT, maxf(1.5, 2.0 * unit), true)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.15, -r * 0.55), c + Vector2(r * 0.35, -r * 0.1),
			c + Vector2(r * 0.05, 0), c + Vector2(r * 0.15, r * 0.55),
			c + Vector2(-r * 0.35, r * 0.1), c + Vector2(-r * 0.05, 0),
		]), SelectPalette.TEXT)
	else:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.7, -r), c + Vector2(r, 0), c + Vector2(-r * 0.7, r), c + Vector2(-r * 0.25, 0),
		]), SelectPalette.TEXT)

func _draw_direction(c: Vector2, r: float, code: String) -> void:
	var dir: Vector2 = DIRS.get(code, Vector2.ZERO)
	if mirrored:
		dir.x = -dir.x
	dir = dir.normalized() if dir.length() > 0.0 else dir
	draw_circle(c, r, SelectPalette.KEY_FACE)
	draw_arc(c, r, 0.0, TAU, 24, SelectPalette.KEY_EDGE, maxf(1.0, 1.5 * unit), true)
	var tip: Vector2 = c + dir * r * 0.72
	var back: Vector2 = c - dir * r * 0.5
	var side: Vector2 = Vector2(-dir.y, dir.x) * r * 0.4
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), accent)

func _draw_chevron(c: Vector2, r: float) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, 0), c + Vector2(-r, r)]), SelectPalette.TEXT_MUTED, maxf(1.0, 1.5 * unit), true)

func _draw_attack_pip(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), accent)
	draw_circle(c, r * 0.32, SelectPalette.INK)
