class_name Fighter
extends Node2D

@export var character_name: String = ""
@export var health := 100
@export var hit_cooldown := 2
@export var health_bar: HealthBar

var facing = 1

var is_tilting = false
var is_attacking = false
var can_attack = true

@export var input_left := "left"
@export var input_right := "right"
@export var input_attack := "attack"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@export var skeleton_animation_player: AnimationPlayer

@export var hit_sounds: Array[AudioStream]
@onready var audio: AudioStreamPlayer = AudioStreamPlayer.new()

@export var hitbox: Hitbox = null

var is_dead = false

func _ready():
	add_child(audio)

func _physics_process(delta):
	if is_dead:
		return

	var axis = Input.get_axis(input_left, input_right)

	# ATTACK
	if Input.is_action_just_pressed(input_attack):

		if can_attack and !is_attacking:
			play_attack()


	# TILT
	if !is_tilting:

		if axis > 0:
			play_tilt("right")

		elif axis < 0:
			play_tilt("left")



func play_tilt(anim_name: String) -> void:
	if is_dead:
		return

	is_tilting = true

	var anim_length = animation_player.get_animation(anim_name).length

	# FORWARD
	animation_player.play(anim_name)

	await get_tree().create_timer(anim_length).timeout

	# HOLD
	await get_tree().create_timer(0.5).timeout

	# BACKWARD
	animation_player.play_backwards(anim_name)

	await get_tree().create_timer(anim_length).timeout

	is_tilting = false



func play_attack() -> void:
	if is_dead:
		return

	is_attacking = true
	can_attack = false
	hitbox.start_attack()

	var anim_name = "attack"
	var anim_length = skeleton_animation_player.get_animation(anim_name).length

	if !skeleton_animation_player.has_animation("attack"):
		is_attacking = false
		can_attack = true
		return
	
	skeleton_animation_player.play(anim_name)
	await get_tree().create_timer(anim_length).timeout

	hitbox.end_attack()
	is_attacking = false

	# COOLDOWN
	await get_tree().create_timer(0.5).timeout
	skeleton_animation_player.play("RESET")
	await get_tree().create_timer(hit_cooldown - 0.5).timeout
	can_attack = true


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
	animation_player.play("death")
	print(character_name, " died!")
	is_dead = true
