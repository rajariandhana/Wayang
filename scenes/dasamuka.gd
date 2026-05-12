class_name Dasamuka
extends CharacterBody2D

@onready var animation_player: AnimationPlayer = $VisualRoot_Right/AnimationPlayer
@export var move_speed: float = 1500.0

const GRAVITY = 8000.0
const JUMP_FORCE = -2000.0
var is_flipping = false
var facing_left = true

func _physics_process(delta):
	# gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# jump
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_FORCE

	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * move_speed if direction else move_toward(velocity.x, 0, move_speed)

	if direction:
		velocity.x = direction * move_speed
		# flip when direction changes
		if direction > 0 and not facing_left:
			facing_left = true
			flip_character(true)
		elif direction < 0 and facing_left:
			facing_left = false
			flip_character(false)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

	move_and_slide()

func flip_character(to_right: bool):
	$Skeleton2D/Hip.scale.x = 1.0 if to_right else -1.0

func _input(event):
	if Input.is_action_just_pressed("base_attack"):
			attack();

func attack():
	animation_player.play("BASE_ATTACK")
