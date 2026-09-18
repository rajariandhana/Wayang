class_name HealthBar3D
extends Node3D

## World-space health bar.
##
## Lives in the 3D scene rather than on a CanvasLayer so the Tilt Five rig can
## see it: T5XRRig is itself a SubViewport (addons/tiltfive/scenes/T5XRRig.tscn)
## rendering the shared world_3d, and a CanvasLayer only ever draws into the
## root viewport -- never into that rig. Screen-space UI is invisible in AR.
##
## Built from two plain Sprite3Ds. No SubViewport or ViewportTexture anywhere:
## that was the pipeline that silently stopped updating in exported builds.
##
## The two sprites are separated by render PASS, not by render_priority. Under
## uses ALPHA_CUT_DISCARD, which puts it in the opaque pass; Progress leaves
## alpha_cut disabled so it lands in the transparent pass, which always runs
## after the opaque one in every renderer -- the flat viewport and the Tilt Five
## stereo path included. render_priority alone was not enough: both sprites were
## coplanar, both in the opaque pass, both with no_depth_test, and that ordering
## is undefined, so the fill drew behind the plate in T5 but not on flat.

@onready var under: Sprite3D = $Under
@onready var progress: Sprite3D = $Progress

var _max_health: int = 100
var _tex_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	if progress.texture:
		_tex_size = progress.texture.get_size()
	progress.region_enabled = true
	_redraw(_max_health)

func setup(maximum: int, current: int) -> void:
	_max_health = maxi(maximum, 1)
	_redraw(current)

func set_health(current: int) -> void:
	_redraw(current)

func _redraw(current: int) -> void:
	if progress == null or _tex_size == Vector2.ZERO:
		return

	var frac := clampf(float(current) / float(_max_health), 0.0, 1.0)
	var width := _tex_size.x * frac

	progress.visible = width > 0.0
	if not progress.visible:
		return

	# Clip rather than stretch, so the bar's border and the dark plate's gold
	# end caps keep their proportions the way TextureProgressBar drew them.
	progress.region_rect = Rect2(0.0, 0.0, width, _tex_size.y)
	# Sprite3D draws centred on its origin, so slide it right as it narrows to
	# keep the fill pinned to the plate's left edge.
	progress.position.x = width * progress.pixel_size * 0.5
