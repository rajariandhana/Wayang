class_name Fighter
extends Node2D

signal died
## Emitted when this fighter's stance made an incoming attack whiff.
## Hook VFX / sound here later.
signal dodged(attacker: Fighter, attack_height: int)
signal attack_connected(target: Fighter, move: Dictionary)
signal debug_trace(message: String)

@export var character_name: String = ""
@export var max_health:int = 100
@export var health:int = 100
@export var health_bar: HealthBar3D
@export var damage:int = 10

@export var input_left: String
@export var input_right: String
@export var input_up: String
@export var input_down: String
@export var input_attack: String

## +1 if the opponent is to the right of this fighter, -1 if to the left.
## Set once by Arena2d so lunges commit toward the enemy. Single source of truth:
## do not add a second place that flips horizontal signs.
@export var facing := 1.0

@export var max_lean_angle_deg := 15.0
## Tuned so a lone leaning attacker's reach (this distance + arm swing) lands
## centered on a stationary opponent's hurtbox. If the opponent also leans in,
## their hurtbox shifts past the attack's fixed landing point and it overshoots -
## this is what makes mutual aggression whiff while one-sided aggression connects.
## Fighter2 overrides this (see fighter_2.tscn) since its arm swing has shorter
## reach on its own and needs more lean to compensate.
@export var max_lean_distance := 550.0
@export var max_lean_vertical_distance := 220.0
@export var lean_response_rate := 8.0

## Left null, this falls back to the default wave scene. Exported so a character
## can swap in its own projectile art and stats later without touching code.
@export var projectile_scene: PackedScene = null
## Where the wave leaves the puppet, relative to the fighter's home position.
## X follows the lean so it visually leaves the puppet's hand side; Y is
## deliberately taken from the fighter's base line, NOT the lean, so the wave
## always overlaps the opponent's hurtbox in every stance and the stance check
## stays the thing that decides a dodge.
@export var projectile_spawn_offset := Vector2(240.0, 68.0)

@export var debug_combat := false

## Display-only instance (character select preview, etc). No physics input,
## no combat areas active - just the rig, its tint and its idle pose. Set this
## before add_child so _ready sees it.
@export var preview_mode := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var skeleton_animation_player: AnimationPlayer

@onready var puppet_visual: Node2D = $Node2D
## Flashed on hit. Deliberately the Sprites node and not puppet_visual, so the
## attack indicator (which encodes cooldown) does not flash along with the body.
@onready var sprites: Node2D = $Node2D/Sprites
@onready var lean_pivot: Vector2 = $Node2D/Sprites/Stick.position

## What the screen shake moves. Defaults to this fighter's parent, which is
## Arena2d inside the SubViewport: shaking that moves the fighters and the floor
## while the painted backdrop holds still.
@export var shake_target: Node2D = null

@export var hit_sounds: Array[AudioStream]

@export var hitbox: Hitbox = null

@onready var attack_indicator: Sprite2D = $Node2D/AttackIndicator

const ATTACK_READY_OPACITY := 1.0
const ATTACK_COOLDOWN_OPACITY := 0.5
## Commands remain ordered, but the buffer is deliberately generous because
## one stick also physically moves the puppet. Players should not need to hit
## a frame-perfect neutral between a lean and a diagonal.
const MOTION_WINDOW := 0.75
const ATTACK_AFTER_MOTION_WINDOW := 0.28
const SPECIAL_CANCEL_WINDOW := 0.18

enum LifeState {ALIVE, DEAD}
var life_state: LifeState = LifeState.ALIVE
enum CombatState {READY, ATTACK, COOLDOWN}
var combat_state: CombatState = CombatState.READY

var _lean_rotation := 0.0
var _lean_offset := Vector2.ZERO
## Extra displacement owned by the current move (crouch + lunge). Kept apart from
## _lean_offset so a fighter's own attack crouch never counts as a dodge stance.
var _attack_offset := Vector2.ZERO
var _attack_offset_tween: Tween = null

## Loaded lazily rather than preloaded. fighter.gd -> projectile.tscn ->
## projectile.gd -> hitbox.gd -> fighter.gd is a cycle, and preload would make
## it a load-time one, which is the flavour GDScript refuses to resolve.
const PROJECTILE_SCENE_PATH := "res://scenes/projectile.tscn"
var _projectile_scene_cache: PackedScene = null
var character_definition: Dictionary = CharacterRoster.definition(&"anoman")
var _current_move: Dictionary = {}
var _attack_serial := 0
var _cancel_until := 0.0
var _hitstun_until := 0.0
var _motion_history: Array[Dictionary] = []
var _last_direction := "N"
var _weapon_prop: WeaponProp
const ANOMAN_ANIMATION = preload("res://script/anoman_animation.gd")
const DASAMUKA_ANIMATION = preload("res://script/dasamuka_animation.gd")
const SURA_ANIMATION = preload("res://script/sura_animation.gd")
const BAYA_ANIMATION = preload("res://script/baya_animation.gd")
var _anoman_animation: RefCounted
var _dasamuka_animation: RefCounted
var _sura_animation: RefCounted
var _baya_animation: RefCounted
var character_id: StringName = &"anoman"
var _skin: CharacterSkin
@onready var _rig_lean_distance := max_lean_distance

func _move_animator(move: Dictionary) -> RefCounted:
	if not move.has("presentation"):
		return null
	match move.get("animation_style", "anoman"):
		"dasamuka": return _dasamuka_animation
		"sura": return _sura_animation
		"baya": return _baya_animation
	return _anoman_animation

func _restore_attack_pose() -> void:
	if _attack_offset_tween and _attack_offset_tween.is_valid():
		_attack_offset_tween.kill()
	if _anoman_animation:
		_anoman_animation.restore()
	# RESET holds the original rig's joint angles; a skinned rig's rest pose is
	# restored by the animator above instead.
	if skeleton_animation_player and not (_skin and _skin.active):
		skeleton_animation_player.speed_scale = 1.0
		skeleton_animation_player.play("RESET")
		skeleton_animation_player.advance(0.0)

func configure_character(id: StringName) -> void:
	character_id = id
	character_definition = CharacterRoster.definition(id)
	character_name = character_definition["name"]
	damage = int(round(10.0 * float(character_definition["power"])))
	lean_response_rate = 8.0 * float(character_definition["speed"])
	if is_node_ready():
		# The new poses extend fully. The second rig's old 780px lean
		# compensated for its shorter swing and overshoots with these timelines.
		max_lean_distance = 550.0 if character_definition["name"] in ["Anoman", "Dasamuka"] else _rig_lean_distance
		_restore_attack_pose()
		_apply_skin()
		_configure_weapon_prop()
		reset()

## Real puppet art for characters that have it (see CharacterSkin), otherwise
## this rig's own art tinted in the roster colour. Pose animators capture the
## joint rest angles, so they are rebuilt whenever the skin changes.
func _apply_skin() -> void:
	if _skin:
		_skin.apply(character_id)
	var skinned := _skin != null and _skin.active
	if skinned:
		max_lean_distance = 550.0
	sprites.modulate = Color.WHITE if skinned else character_definition["tint"]
	if skeleton_animation_player and hitbox:
		_anoman_animation = ANOMAN_ANIMATION.new(skeleton_animation_player, hitbox.get_parent())
		_dasamuka_animation = DASAMUKA_ANIMATION.new(skeleton_animation_player, hitbox.get_parent())
		_sura_animation = SURA_ANIMATION.new(skeleton_animation_player, hitbox.get_parent())
		_baya_animation = BAYA_ANIMATION.new(skeleton_animation_player, hitbox.get_parent())

func reset() -> void:
	_restore_attack_pose()
	if hitbox:
		hitbox.end_attack()
	health = max_health
	life_state = LifeState.ALIVE
	combat_state = CombatState.READY
	_attack_offset = Vector2.ZERO
	_attack_serial += 1
	_current_move = {}
	_cancel_until = 0.0
	_hitstun_until = 0.0
	_motion_history.clear()
	if _weapon_prop:
		_weapon_prop.set_arrow_ready(false)
	hitbox.set_damage(damage)
	set_attack_indicator(true)
	if health_bar:
		health_bar.set_health(health)

func _ready():
	if character_definition["name"] in ["Anoman", "Dasamuka"]:
		max_lean_distance = 550.0
	if hitbox:
		_skin = CharacterSkin.new(self)
	_apply_skin()
	_configure_weapon_prop()
	reset()
	dodged.connect(_on_dodged)
	if preview_mode:
		_enter_preview_mode()

## Strips this instance down to a display-only rig: no physics/input reads,
## no active hit/hurt areas, no attack-cooldown flash. Used by the character
## select screen so placeholder puppets can sit in a SubViewport safely.
func _enter_preview_mode() -> void:
	set_physics_process(false)
	if hitbox:
		hitbox.process_mode = Node.PROCESS_MODE_DISABLED
	var hurtbox := get_node_or_null(^"Node2D/Hurtbox")
	if hurtbox:
		hurtbox.process_mode = Node.PROCESS_MODE_DISABLED
	if attack_indicator:
		attack_indicator.visible = false

func _physics_process(delta):
	if life_state == LifeState.DEAD:
		return

	if _in_hitstun():
		return

	_debug_inputs()
	_record_direction()
	if Input.is_action_just_pressed(input_attack):
		var special := _matching_special()
		if combat_state == CombatState.READY:
			var selected := special if not special.is_empty() else _select_normal()
			debug_trace.emit("TRIGGER → %s" % selected["name"])
			_start_attack(selected)
		elif _can_cancel() and not special.is_empty():
			debug_trace.emit("CANCEL → %s" % special["name"])
			_interrupt_attack()
			_start_attack(special)
		else:
			debug_trace.emit("TRIGGER ignored: state=%s, special=%s" % [CombatState.keys()[combat_state], "yes" if not special.is_empty() else "no"])

	_update_lean(delta)

func _select_normal() -> Dictionary:
	var vertical := Input.get_axis(input_up, input_down)
	var moves: Dictionary = character_definition["moves"]
	if vertical > Combat.STICK_DIR_THRESHOLD: return moves["down"]
	if vertical < -Combat.STICK_DIR_THRESHOLD: return moves["up"]
	return moves["neutral"]

func _record_direction() -> void:
	var next := _input_direction()
	if next == _last_direction:
		return
	var previous := _last_direction
	_last_direction = next
	if next == "N":
		return
	var now := Time.get_ticks_msec() / 1000.0
	# Starting a diagonal while forward/back is held is a natural way to enter a
	# motion on a physical wand. Record the newly added vertical component first,
	# so F → DF is recognised as F → D → DF instead of losing its D input.
	if next in ["DF", "DB"] and previous == next.right(1):
		_motion_history.append({"dir": "D", "time": now})
	_motion_history.append({"dir": next, "time": now})
	_prune_motion_history(now)
	debug_trace.emit("INPUT %s | buffer: %s" % [next, _motion_text()])

func _input_direction() -> String:
	var horizontal := Input.get_axis(input_left, input_right) * facing
	var vertical := Input.get_axis(input_up, input_down)
	var h := "F" if horizontal > Combat.STICK_DIR_THRESHOLD else "B" if horizontal < -Combat.STICK_DIR_THRESHOLD else ""
	var v := "D" if vertical > Combat.STICK_DIR_THRESHOLD else "U" if vertical < -Combat.STICK_DIR_THRESHOLD else ""
	if v != "" and h != "": return v + h
	return v if v != "" else h if h != "" else "N"

func _matching_special() -> Dictionary:
	if _motion_history.is_empty(): return {}
	var now := Time.get_ticks_msec() / 1000.0
	_prune_motion_history(now)
	if _motion_history.is_empty(): return {}
	if now - float(_motion_history.back()["time"]) > ATTACK_AFTER_MOTION_WINDOW: return {}
	var matches: Array[Dictionary] = []
	for key in ["melee_special", "ranged_special"]:
		var move: Dictionary = character_definition["moves"][key]
		var motion: Array = move["motion"]
		if _matches_motion(motion): matches.append(move)
	if matches.is_empty(): return {}
	matches.sort_custom(func(a, b): return a["motion"].size() > b["motion"].size())
	_motion_history.clear()
	return matches[0]

func _motion_text() -> String:
	var directions: Array[String] = []
	for entry in _motion_history:
		directions.append(entry["dir"])
	return " → ".join(directions)

func _prune_motion_history(now: float) -> void:
	while not _motion_history.is_empty() and now - float(_motion_history[0]["time"]) > MOTION_WINDOW:
		_motion_history.pop_front()

func _matches_motion(motion: Array) -> bool:
	if motion.size() > _motion_history.size():
		return false
	# Required directions must appear in order. Extra directions are allowed:
	# this keeps a deliberate command distinct while tolerating a player briefly
	# leaning through an adjacent direction on a real analog stick.
	var expected_index := 0
	for entry in _motion_history:
		if entry["dir"] == motion[expected_index]:
			expected_index += 1
			if expected_index == motion.size():
				return true
	return false

func _can_cancel() -> bool:
	return not _current_move.is_empty() and not bool(_current_move.get("special", false)) and Time.get_ticks_msec() / 1000.0 <= _cancel_until

func _in_hitstun() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _hitstun_until

func _configure_weapon_prop() -> void:
	if _weapon_prop:
		_weapon_prop.queue_free()
		_weapon_prop = null
	if character_definition["name"] != "Arjuna" or hitbox == null:
		return
	var hand := hitbox.get_parent() as Node2D
	if hand == null:
		return
	_weapon_prop = WeaponProp.new()
	_weapon_prop.position = Vector2(10, -15)
	_weapon_prop.tint = character_definition["tint"]
	hand.add_child(_weapon_prop)

func _update_lean(delta: float) -> void:
	var input_vec := Vector2(
		Input.get_axis(input_left, input_right),
		Input.get_axis(input_up, input_down)
	).clamp(Vector2(-1, -1), Vector2(1, 1))

	var target_rotation := input_vec.x * deg_to_rad(max_lean_angle_deg)
	var target_offset := Vector2(
		input_vec.x * max_lean_distance,
		input_vec.y * max_lean_vertical_distance
	)

	var t := 1.0 - exp(-lean_response_rate * delta)
	_lean_rotation = lerpf(_lean_rotation, target_rotation, t)
	_lean_offset = _lean_offset.lerp(target_offset, t)

	puppet_visual.rotation = _lean_rotation
	puppet_visual.position = lean_pivot - lean_pivot.rotated(_lean_rotation) + _lean_offset + _attack_offset

## Read from the settled lean rather than the raw stick, so lifting the puppet
## out of a low sweep costs about 100ms of commitment instead of being a
## frame-perfect reaction.
func get_stance() -> Combat.Stance:
	var normalised := _lean_offset.y / maxf(max_lean_vertical_distance, 1.0)
	if normalised <= -Combat.STANCE_THRESHOLD:
		return Combat.Stance.RAISED
	if normalised >= Combat.STANCE_THRESHOLD:
		return Combat.Stance.CROUCHED
	return Combat.Stance.NEUTRAL

## LOW whiffs against a raised puppet, HIGH whiffs against a crouched one,
## MID always connects. See the matrix in COMBAT_MOVESET_DESIGN.md.
func dodges(attack_height: int) -> bool:
	# A hit-confirmed follow-up lands while the defender is in hitstun. The
	# fighter cannot change stance during that short window, so this is a real
	# two-hit combo instead of a guess after the first hit.
	if _in_hitstun():
		return false
	match get_stance():
		Combat.Stance.RAISED:
			return attack_height == Combat.Height.LOW
		Combat.Stance.CROUCHED:
			return attack_height == Combat.Height.HIGH
		_:
			return false

func set_attack_indicator(ready: bool):
	if ready:
		attack_indicator.modulate.a = ATTACK_READY_OPACITY
	else:
		attack_indicator.modulate.a = ATTACK_COOLDOWN_OPACITY

func _tween_attack_offset(target: Vector2, duration: float) -> void:
	if _attack_offset_tween and _attack_offset_tween.is_valid():
		_attack_offset_tween.kill()
	if duration <= 0.0:
		_attack_offset = target
		return
	_attack_offset_tween = create_tween()
	_attack_offset_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_attack_offset_tween.tween_property(self, "_attack_offset", target, duration)

func _start_attack(move: Dictionary) -> void:
	_attack_serial += 1
	_current_move = move
	_cancel_until = 0.0
	_perform_attack(move, _attack_serial)

func _interrupt_attack() -> void:
	_attack_serial += 1
	hitbox.end_attack()
	_attack_offset = Vector2.ZERO
	_restore_attack_pose()

func _perform_attack(move: Dictionary, serial: int) -> void:
	await combat_attack(move, serial)
	if serial != _attack_serial: return
	await combat_cooldown(move, serial)
	if serial == _attack_serial:
		combat_state = CombatState.READY
		_current_move = {}

func combat_attack(move: Dictionary, serial: int) -> void:
	combat_state = CombatState.ATTACK
	set_attack_indicator(false)

	if debug_combat:
		print(character_name, " -> ", move["name"])

	# Startup: the puppet drops and commits forward while the hitbox is still
	# cold. This is what makes a heavy move readable and therefore dodgeable.
	var committed := Vector2(float(move["lunge"]) * facing, float(move["drop"]))
	if _weapon_prop:
		_weapon_prop.set_arrow_ready(String(move.get("projectile_profile", "")) == "arrow")
	_tween_attack_offset(committed, maxf(float(move["startup"]), 0.05))
	var pose_animation := _move_animator(move)
	if pose_animation:
		pose_animation.play(move)
	if float(move["startup"]) > 0.0:
		await Util.wait(float(move["startup"]))
		if serial != _attack_serial: return
	if pose_animation:
		# Contact starts at the release pose, independent of render frame timing.
		skeleton_animation_player.seek(float(move["startup"]), true)

	var move_damage := int(move["damage"])
	hitbox.start_attack(move_damage, int(move["height"]), float(move["reach_scale"]), bool(move.get("special", false)))
	Sfx.play(&"swing")
	if bool(move["projectile"]):
		_spawn_projectile(move_damage, int(move["height"]), bool(move.get("special", false)), String(move.get("projectile_profile", "fire")))
		if _weapon_prop:
			_weapon_prop.set_arrow_ready(false)

	var active_time := float(move["active"])
	var anim_name := StringName(move.get("anim", "attack"))
	if skeleton_animation_player and not pose_animation:
		if not skeleton_animation_player.has_animation(anim_name):
			anim_name = &"attack"
		if skeleton_animation_player.has_animation(anim_name):
			var animation := skeleton_animation_player.get_animation(anim_name)
			skeleton_animation_player.speed_scale = animation.length / maxf(active_time, 0.01)
			skeleton_animation_player.play(anim_name)

	# Always awaited and always followed by end_attack(). The old code returned
	# early when the animation was missing, which left the hitbox live forever.
	await Util.wait(active_time)
	if serial == _attack_serial:
		hitbox.end_attack()

func _spawn_projectile(move_damage: int, attack_height: int, is_special: bool, profile: String) -> void:
	var scene := projectile_scene
	if scene == null:
		if _projectile_scene_cache == null:
			_projectile_scene_cache = load(PROJECTILE_SCENE_PATH) as PackedScene
		scene = _projectile_scene_cache
	if scene == null:
		push_warning("Fighter %s has no projectile scene" % character_name)
		return

	var projectile := scene.instantiate() as Projectile
	if projectile == null:
		push_warning("Projectile scene root is not a Projectile")
		return

	# Parented to the arena, not to this fighter, so it does not inherit the
	# puppet's lean once it is in flight.
	get_parent().add_child(projectile)
	projectile.global_position = Vector2(
		puppet_visual.global_position.x + projectile_spawn_offset.x * facing,
		global_position.y + projectile_spawn_offset.y
	)
	projectile.launch(self, move_damage, attack_height, facing, is_special, profile, character_definition["tint"])

func combat_cooldown(move: Dictionary, serial: int) -> void:
	combat_state = CombatState.COOLDOWN
	var recovery := float(move["recovery"])
	_tween_attack_offset(Vector2.ZERO, minf(0.3, recovery))
	var pose_animation := _move_animator(move)
	if pose_animation:
		skeleton_animation_player.seek(float(move["startup"]) + float(move["active"]), true)
		await Util.wait(recovery)
		if serial != _attack_serial: return
		pose_animation.restore()
		set_attack_indicator(true)
		return
	await Util.wait(recovery / 2.0)
	if serial != _attack_serial: return
	if skeleton_animation_player:
		skeleton_animation_player.speed_scale = 1.0
		skeleton_animation_player.play("RESET")
	await Util.wait(recovery / 2.0)
	if serial == _attack_serial: set_attack_indicator(true)

func got_hit(opponent: Fighter, incoming_damage: int, was_special := false):
	_interrupt_attack()
	combat_state = CombatState.READY
	_hitstun_until = Time.get_ticks_msec() / 1000.0 + (0.25 if was_special else 0.40)
	print(opponent.character_name, " HITS ", character_name, ": health -", incoming_damage)
	health -= incoming_damage
	if health_bar:
		health_bar.set_health(health)

	# Body impact plus a gamelan accent underneath. Two layers rather than one
	# baked sample, so the accent can be retuned without recutting the hit.
	Sfx.play_streams(hit_sounds)
	Sfx.play(&"accent")

	Juice.hitstop(0.06, 0.15)
	Juice.flash(sprites)
	Juice.shake(_shake_target(), 26.0, 0.28)
	opponent._register_hit(self)

	if health <= 0:
		die()

func _register_hit(target: Fighter) -> void:
	if _current_move.is_empty(): return
	attack_connected.emit(target, _current_move)
	if not bool(_current_move.get("special", false)):
		_cancel_until = Time.get_ticks_msec() / 1000.0 + SPECIAL_CANCEL_WINDOW
		debug_trace.emit("HIT CONFIRM → cancel window open")

func _shake_target() -> Node2D:
	if shake_target:
		return shake_target
	return get_parent() as Node2D

func _on_dodged(_attacker: Fighter, _attack_height: int) -> void:
	# A dodge needs to be audible or it reads as the attack simply failing.
	Sfx.play(&"dodge")

func die():
	if life_state == LifeState.DEAD:
		return
	life_state = LifeState.DEAD
	_interrupt_attack()
	set_attack_indicator(false)
	_tween_attack_offset(Vector2.ZERO, 0.1)
	Juice.hitstop(0.16, 0.2)
	Juice.shake(_shake_target(), 40.0, 0.5)
	animation_player.play("death")
	print(character_name, " died!")
	await animation_player.animation_finished
	died.emit()

func _debug_inputs() -> void:
	if !debug_combat:
		return

	var inputs := {
		"input_left": input_left,
		"input_right": input_right,
		"input_up": input_up,
		"input_down": input_down,
		"input_attack": input_attack
	}

	for input_name in inputs:
		var action_name: String = inputs[input_name]

		if action_name != "" and Input.is_action_just_pressed(action_name):
			print(character_name, " pressed ", input_name, " (", action_name, ")")
