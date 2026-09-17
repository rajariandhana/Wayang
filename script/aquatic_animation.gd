extends "res://script/anoman_animation.gd"
## Shared timeline builder for the two aquatic rigs; subclasses provide their
## own poses and rhythm. Poses: anticipation, contact, follow-through, recoil.
func _pose_data() -> Dictionary:
	return {}

func _rhythm() -> Array:
	return [0.6, 0.5, 0.25, 0.8]

func _build(move: Dictionary) -> Animation:
	var poses: Array = _pose_data()[move["presentation"]]
	var rhythm := _rhythm()
	var startup := float(move["startup"])
	var active := float(move["active"])
	var recovery := float(move["recovery"])
	var animation := Animation.new()
	animation.length = startup + active + recovery
	var times := [0.0, startup * rhythm[0], startup,
		startup + active * rhythm[1], startup + active,
		startup + active + recovery * rhythm[2],
		startup + active + recovery * rhythm[3], animation.length]
	var root := player.get_node(player.root_node)
	for i in joints.size():
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(String(root.get_path_to(joints[i])) + ":rotation"))
		var values := [0.0, poses[0][i], poses[1][i], poses[2][i], poses[2][i], poses[3][i], 0.0, 0.0]
		for k in times.size():
			var angle := rest[i] if k in [0, 6, 7] else float(values[k]) * direction
			animation.track_insert_key(track, times[k], angle)
	return animation
