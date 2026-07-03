class_name Fighter
extends Node2D

signal died

@export var character_name: String = ""
@export var max_health:int = 100
@export var health:int = 100
@export var health_bar: HealthBar
@export var damage:int = 10

@export var input_left := "left"
@export var input_right := "right"
@export var input_attack := "attack"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var skeleton_animation_player: AnimationPlayer

@export var hit_sounds: Array[AudioStream]
@onready var audio: AudioStreamPlayer = AudioStreamPlayer.new()

@export var hitbox: Hitbox = null

@onready var attack_indicator: Sprite2D = $Node2D/AttackIndicator

const ATTACK_READY_OPACITY := 1.0
const ATTACK_COOLDOWN_OPACITY := 0.5
const ATTACK_COOLDOWN_TIME := 2.0

const POSITION_TILT_TIME = 0.5

enum LifeState {ALIVE, DEAD}
var life_state: LifeState = LifeState.ALIVE
enum PositionState {IDLE, LEFT, RIGHT}
var position_state: PositionState = PositionState.IDLE
enum CombatState {READY, ATTACK, COOLDOWN}
var combat_state: CombatState = CombatState.READY

func reset() -> void:
	health = max_health
	life_state = LifeState.ALIVE
	position_state = PositionState.IDLE
	combat_state = CombatState.READY
	hitbox.set_damage(damage)
	set_attack_indicator(true)

func _ready():
	reset()
	add_child(audio)

func _physics_process(delta):
	if life_state == LifeState.DEAD:
		return
	
	if combat_state == CombatState.READY:
		if Input.is_action_just_pressed(input_attack):
			await combat_attack()
			await combat_cooldown()
			combat_state = CombatState.READY

	if position_state == PositionState.IDLE:
		var axis = Input.get_axis(input_left, input_right)
		if axis > 0:
			position_state = PositionState.RIGHT
			await play_tilt("right")
		elif axis < 0:
			position_state = PositionState.LEFT
			await play_tilt("left")
		position_state = PositionState.IDLE

func play_tilt(anim_name: String) -> void:
	var anim_length = animation_player.get_animation(anim_name).length

	# FORWARD
	animation_player.play(anim_name)
	await Util.wait(anim_length)
	# HOLD
	await Util.wait(POSITION_TILT_TIME)
	# BACKWARD
	animation_player.play_backwards(anim_name)

	await Util.wait(anim_length)

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
	print(character_name, " got_hit by ", opponent.character_name, " by ", damage)
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
