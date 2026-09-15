extends "res://script/anoman_animation.gd"
## Heavy, angular puppet motion: hold the preparation, cut down decisively,
## then let the weight settle before returning to guard. Only rig plumbing is
## shared with Anoman; these poses and their timing curves are independent.
const HEAVY_POSES := {
	"neutral": [
		[-2.1, -0.65, 0.65, -1.8, -0.06],
		[-1.15, -0.1, 0.25, -1.5, 0.07],
		[-0.8, -0.25, 0.1, -1.2, 0.10]],
	"up": [
		[-2.8, 0.2, -2.1, -0.8, -0.08],
		[-1.7, 0.8, -1.8, -0.4, 0.04],
		[-1.0, -0.6, -0.7, -1.1, 0.10]],
	"down": [
		[0.6, -0.7, 0.3, -1.5, 0.03],
		[-0.7, -0.4, 0.7, -1.65, 0.10],
		[-1.2, 0.8, 0.8, -1.7, 0.14]],
	"melee_special": [
		[-2.7, -0.5, -2.5, -0.3, -0.13],
		[-1.1, 0.1, -1.5, 0.35, 0.13],
		[-0.7, 0.35, -1.0, 0.45, 0.18]],
	"ranged_special": [
		[-2.5, 0.5, 0.5, -1.7, -0.12],
		[-1.35, 0.25, 0.8, -1.8, 0.10],
		[-1.15, 0.05, 1.0, -1.65, 0.14]],
}

func _library_name() -> StringName:
	return &"dasamuka"

func _build(move: Dictionary) -> Animation:
	var poses: Array = HEAVY_POSES[move["presentation"]]
	var startup := float(move["startup"])
	var active := float(move["active"])
	var recovery := float(move["recovery"])
	var animation := Animation.new()
	animation.length = startup + active + recovery
	# A visible held wind-up, fast release, heavy follow-through and delayed
	# recovery. The hitbox still opens and closes on the combat phase boundaries.
	var times := [0.0, startup * 0.44, startup * 0.76, startup,
		startup + active * 0.85, startup + active,
		startup + active + recovery * 0.22,
		startup + active + recovery * 0.92, animation.length]
	var root := player.get_node(player.root_node)
	for i in joints.size():
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(String(root.get_path_to(joints[i])) + ":rotation"))
		var values := [0.0, poses[0][i], poses[0][i], poses[1][i], poses[2][i],
			poses[2][i], poses[2][i], 0.0, 0.0]
		for k in times.size():
			var angle := rest[i] if k in [0, 7, 8] else float(values[k]) * direction
			animation.track_insert_key(track, times[k], angle)
	return animation
