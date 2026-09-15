class_name SelectCursor
extends Control

## One player's selection frame on the grid, with a small "1P"/"2P" tab in a
## corner. P1's tab sits top-left and P2's bottom-right, so both stay readable
## when the players hover the same tile.

var player_color := Color.WHITE
var badge_text := "1P"
var tab_top := true
var inset := 0.0:
	set(value):
		inset = value
		queue_redraw()
var unit := 1.0:
	set(value):
		unit = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var line := maxf(3.0, 4.0 * unit)
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	draw_rect(rect.grow(-line * 0.5), player_color, false, line)
	var font := ThemeDB.fallback_font
	var font_size := int(15.0 * unit)
	var tab_size := Vector2(font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 10.0 * unit, 20.0 * unit)
	var tab_pos := rect.position if tab_top else rect.end - tab_size
	draw_rect(Rect2(tab_pos, tab_size), player_color)
	draw_string(font, tab_pos + Vector2(5.0 * unit, tab_size.y * 0.76), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, SelectPalette.INK)
