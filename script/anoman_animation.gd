extends RefCounted
## Instance-local timelines: existing textures and joints, no imported art.
## Both rigs' arm links point down in local space. Mirror authored joint angles
## for the opposite arm, but start and recover at that rig's own rest pose.
const REST := [-0.3848068, 0.7099897, 0.7237567, -0.713456, 0.0]
const POSES := {
	"neutral": [
		[-0.15, 1.25, -0.25, -1.0, -0.025],
		[-1.35, -0.15, -0.3, -1.0, 0.025],
		[-1.45, 0.0, -0.2, -0.9, 0.035]],
	"up": [
		[0.2, 0.2, -0.5, -1.0, 0.035],
		[-1.65, 0.7, 0.15, -0.8, -0.035],
		[-2.25, 0.55, 0.45, -0.7, -0.06]],
	"down": [
		[-1.55, 1.5, -0.5, -1.4, -0.035],
		[-0.7, 0.05, -1.4, -0.7, 0.045],
		[-1.1, 0.3, -1.65, -0.5, 0.065]],
	"melee_special": [
		[0.15, 1.65, 0.8, -1.6, -0.10],
		[-1.6, 0.55, 1.25, -0.5, 0.11],
		[-1.75, 0.7, 1.55, -0.35, 0.15]],
	"ranged_special": [
		[-0.45, 1.9, -0.35, -1.8, -0.065],
		[-1.5, 0.35, -1.45, 0.3, 0.035],
		[-1.55, 0.4, -1.5, 0.35, 0.025]],
}

var joints: Array[Node2D] = []
var rest: Array[float] = []
var player: AnimationPlayer
var library := AnimationLibrary.new()
var direction := 1.0

func _init(animation_player: AnimationPlayer, hand: Node2D) -> void:
	player = animation_player
	var lower := hand.get_parent() as Node2D
	var upper := lower.get_parent() as Node2D
	var hip := upper.get_parent() as Node2D
	var other_name := "RForearm" if upper.name == &"LForearm" else "LForearm"
	var other := hip.get_node(other_name) as Node2D
	joints.assign([upper, lower, other, other.get_child(0), hip])
	direction = 1.0 if upper.position.x > 0.0 else -1.0
	for joint in joints:
		rest.append(joint.rotation)
	player.add_animation_library(_library_name(), library)

func _library_name() -> StringName:
	return &"anoman"

func restore() -> void:
	player.stop()
	player.speed_scale = 1.0
	for i in joints.size():
		joints[i].rotation = rest[i]

func play(move: Dictionary) -> void:
	var key := StringName(move["presentation"])
	if not library.has_animation(key):
		library.add_animation(key, _build(move))
	player.speed_scale = 1.0
	player.play(StringName(String(_library_name()) + "/" + String(key)))
	player.advance(0.0)

func _build(move: Dictionary) -> Animation:
	var poses: Array = POSES[move["presentation"]]
	var startup := float(move["startup"])
	var active := float(move["active"])
	var recovery := float(move["recovery"])
	var animation := Animation.new()
	animation.length = startup + active + recovery
	var times := [0.0, startup * 0.65, startup, startup + active * 0.65,
		startup + active, startup + active + recovery * 0.75, animation.length]
	var root := player.get_node(player.root_node)
	for i in joints.size():
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(String(root.get_path_to(joints[i])) + ":rotation"))
		var values := [REST[i], poses[0][i], poses[1][i], poses[2][i], poses[2][i], REST[i], REST[i]]
		for k in times.size():
			var angle := rest[i] if k in [0, 5, 6] else float(values[k]) * direction
			animation.track_insert_key(track, times[k], angle)
	return animation
