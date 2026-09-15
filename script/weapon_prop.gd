class_name WeaponProp
extends Node2D

## A deliberately simple procedural bow. It keeps Arjuna readable while the
## art team only needs to provide a finished prop later; replacing this node
## with a sprite does not affect combat or projectile code.
var arrow_visible := false
var tint := Color("d1a347")

func set_arrow_ready(ready: bool) -> void:
	arrow_visible = ready
	queue_redraw()

func _draw() -> void:
	var bow := PackedVector2Array([Vector2(0, -84), Vector2(30, -42), Vector2(35, 0), Vector2(30, 42), Vector2(0, 84)])
	draw_polyline(bow, tint.darkened(0.35), 9.0, true)
	draw_line(Vector2(0, -84), Vector2(0, 84), tint.lightened(0.4), 3.0)
	if arrow_visible:
		draw_line(Vector2(-8, 0), Vector2(86, 0), Color("f7e8be"), 5.0)
		draw_colored_polygon(PackedVector2Array([Vector2(104, 0), Vector2(82, -10), Vector2(82, 10)]), Color("f7e8be"))
