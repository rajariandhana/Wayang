class_name Fighter
extends Node2D

signal died
## Emitted when this fighter's stance made an incoming attack whiff.
## Hook VFX / sound here later.
signal dodged(attacker: Fighter, attack_height: int)

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
const ATTACK_COOLDOWN_TIME := 2.0

## Step 1 move table. Deliberately a plain Dictionary: once the timings feel
## right this lifts straight into Move / MoveSet resources (see
## COMBAT_MOVESET_DESIGN.md) so a character becomes a .tres file.
##   damage_scale : multiplies the exported `damage`, so per-character tuning still works
##   startup      : puppet moves into stance, hitbox NOT live yet
##   reach_scale  : multiplies the hitbox collision shape
##   lunge / drop : offset applied to the puppet for the duration of the swing
##   projectile   : also launch a travelling hitbox when the swing goes live
const MOVES := {
	"sabetan": {
		"name": "Sabetan",
		"anim": "attack",
		"anim_speed": 1.0,
		"height": Combat.Height.MID,
		"damage_scale": 1.0,
		"startup": 0.0,
		"active": 0.2,
		"recovery": 1.2,
		"reach_scale": 1.0,
		"lunge": 0.0,
		"drop": 0.0,
		"projectile": false,
	},
	# Ranged. The swing throws a low wave across the floor, so a player camping
	# in a far corner can still be reached. Damage is lower than a melee sweep
	# would be and the recovery stays long: it is a zoning tool, not a burst.
	"sabet_bawah": {
		"name": "Sabet Bawah",
		"anim": "attack",
		"anim_speed": 0.55,
		"height": Combat.Height.LOW,
		"damage_scale": 1.2,
		"startup": 0.28,
		"active": 0.30,
		"recovery": 2.0,
		"reach_scale": 1.15,
		"lunge": 60.0,
		"drop": 150.0,
		"projectile": true,
	},
}

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

func reset() -> void:
	health = max_health
	life_state = LifeState.ALIVE
	combat_state = CombatState.READY
	_attack_offset = Vector2.ZERO
	hitbox.set_damage(damage)
	set_attack_indicator(true)
	if health_bar:
		health_bar.set_health(health)

func _ready():
	reset()
	dodged.connect(_on_dodged)

func _physics_process(delta):
	if life_state == LifeState.DEAD:
		return

	_debug_inputs()

	if combat_state == CombatState.READY and Input.is_action_just_pressed(input_attack):
		# Not awaited: _perform_attack runs synchronously up to its first await,
		# which is past the point where combat_state becomes ATTACK, so re-entry
		# is already blocked and the lean below keeps updating every frame.
		_perform_attack(_select_move())

	_update_lean(delta)

## Samples the stick at the instant of the press. This is the whole move-select
## vocabulary: one stick plus one trigger is all each player has.
func _select_move() -> Dictionary:
	var vertical := Input.get_axis(input_up, input_down)
	if vertical > Combat.STICK_DIR_THRESHOLD:
		return MOVES["sabet_bawah"]
	return MOVES["sabetan"]

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

func _perform_attack(move: Dictionary) -> void:
	await combat_attack(move)
	await combat_cooldown(move)
	combat_state = CombatState.READY

func combat_attack(move: Dictionary) -> void:
	combat_state = CombatState.ATTACK
	set_attack_indicator(false)

	if debug_combat:
		print(character_name, " -> ", move["name"])

	# Startup: the puppet drops and commits forward while the hitbox is still
	# cold. This is what makes a heavy move readable and therefore dodgeable.
	var committed := Vector2(float(move["lunge"]) * facing, float(move["drop"]))
	_tween_attack_offset(committed, maxf(float(move["startup"]), 0.05))
	if float(move["startup"]) > 0.0:
		await Util.wait(float(move["startup"]))

	var move_damage := int(round(damage * float(move["damage_scale"])))
	hitbox.start_attack(move_damage, int(move["height"]), float(move["reach_scale"]))
	Sfx.play(&"swing")
	if bool(move["projectile"]):
		_spawn_projectile(move_damage, int(move["height"]))

	var anim_name: String = move["anim"]
	var active_time := float(move["active"])
	if skeleton_animation_player and skeleton_animation_player.has_animation(anim_name):
		var speed := maxf(float(move["anim_speed"]), 0.01)
		skeleton_animation_player.speed_scale = speed
		skeleton_animation_player.play(anim_name)
		active_time = skeleton_animation_player.get_animation(anim_name).length / speed

	# Always awaited and always followed by end_attack(). The old code returned
	# early when the animation was missing, which left the hitbox live forever.
	await Util.wait(active_time)
	hitbox.end_attack()

func _spawn_projectile(move_damage: int, attack_height: int) -> void:
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
	projectile.launch(self, move_damage, attack_height, facing)

func combat_cooldown(move: Dictionary) -> void:
	combat_state = CombatState.COOLDOWN
	var recovery := float(move["recovery"])
	_tween_attack_offset(Vector2.ZERO, minf(0.3, recovery))
	await Util.wait(recovery / 2.0)
	if skeleton_animation_player:
		skeleton_animation_player.speed_scale = 1.0
		skeleton_animation_player.play("RESET")
	await Util.wait(recovery / 2.0)
	set_attack_indicator(true)

func got_hit(opponent: Fighter, incoming_damage: int):
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

	if health <= 0:
		die()

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
