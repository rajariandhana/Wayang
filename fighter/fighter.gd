class_name Fighter
extends Node2D

signal died

@export var character_name: String = ""
@export var max_health:int = 100
@export var health:int = 100
@export var health_bar: HealthBar
@export var damage:int = 10

@export var input_left: String
@export var input_right: String
@export var input_up: String
@export var input_down: String
@export var input_attack: String

@export var max_lean_angle_deg := 15.0
## Tuned so a lone leaning attacker's reach (this distance + arm swing) lands
## centered on a stationary opponent's hurtbox. If the opponent also leans in,
## their hurtbox shifts past the attack's fixed landing point and it overshoots —
## this is what makes mutual aggression whiff while one-sided aggression connects.
## Fighter2 overrides this (see fighter_2.tscn) since its arm swing has shorter
## reach on its own and needs more lean to compensate.
@export var max_lean_distance := 550.0
@export var max_lean_vertical_distance := 220.0
@export var lean_response_rate := 8.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var skeleton_animation_player: AnimationPlayer

@onready var puppet_visual: Node2D = $Node2D
@onready var lean_pivot: Vector2 = $Node2D/Sprites/Stick.position

@export var hit_sounds: Array[AudioStream]
@onready var audio: AudioStreamPlayer = AudioStreamPlayer.new()

@export var hitbox: Hitbox = null

@onready var attack_indicator: Sprite2D = $Node2D/AttackIndicator

const ATTACK_READY_OPACITY := 1.0
const ATTACK_COOLDOWN_OPACITY := 0.5
const ATTACK_COOLDOWN_TIME := 2.0

enum LifeState {ALIVE, DEAD}
var life_state: LifeState = LifeState.ALIVE
enum CombatState {READY, ATTACK, COOLDOWN}
var combat_state: CombatState = CombatState.READY

var _lean_rotation := 0.0
var _lean_offset := Vector2.ZERO

func reset() -> void:
	health = max_health
	life_state = LifeState.ALIVE
	combat_state = CombatState.READY
	hitbox.set_damage(damage)
	set_attack_indicator(true)

func _ready():
	reset()
	add_child(audio)

func _physics_process(delta):
	if life_state == LifeState.DEAD:
		return
	
	_debug_inputs()

	if combat_state == CombatState.READY:
		if Input.is_action_just_pressed(input_attack):
			await combat_attack()
			await combat_cooldown()
			combat_state = CombatState.READY

	_update_lean(delta)

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
	puppet_visual.position = lean_pivot - lean_pivot.rotated(_lean_rotation) + _lean_offset

func set_attack_indicator(ready: bool):
	if ready:
		attack_indicator.modulate.a = ATTACK_READY_OPACITY
	else:
		attack_indicator.modulate.a = ATTACK_COOLDOWN_OPACITY

func combat_attack() -> void:
	combat_state = CombatState.ATTACK
	set_attack_indicator(false)
	hitbox.start_attack()

	var anim_name = "attack"
	if !skeleton_animation_player.has_animation(anim_name):
		return
	var anim_length = skeleton_animation_player.get_animation(anim_name).length
	
	skeleton_animation_player.play(anim_name)
	await Util.wait(anim_length)

	hitbox.end_attack()

func combat_cooldown() -> void:
	combat_state = CombatState.COOLDOWN
	await Util.wait(ATTACK_COOLDOWN_TIME/2)
	skeleton_animation_player.play("RESET")
	await Util.wait(ATTACK_COOLDOWN_TIME/2)
	set_attack_indicator(true)

func got_hit(opponent: Fighter, damage: int):
	# print(character_name, " got_hit by ", opponent.character_name, " by ", damage)
	print(opponent.character_name, " HITS ",character_name,": health -10")
	health -= damage
	health_bar.set_health(health)
	if hit_sounds.size() > 0:
		audio.stream = hit_sounds[randi() % hit_sounds.size()]
		audio.play()
	if health <= 0:
		die()

func die():
	if life_state == LifeState.DEAD:
		return
	life_state = LifeState.DEAD
	set_attack_indicator(false)
	animation_player.play("death")
	print(character_name, " died!")
	await animation_player.animation_finished
	died.emit()

func _debug_inputs() -> void:
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
