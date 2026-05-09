# player.gd
class_name Player
extends Wayang

const GRAVITY = 0.0
const JUMP_FORCE = -2000.0
var is_flipping = false
var facing_right = true



func on_ready():
	character_name = "Anoman"

func _physics_process(delta):
	# gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# jump
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_FORCE

	# horizontal movement
	# var direction = 0.0
	# if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
	# 	direction = -1.0
	# if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
	# 	direction = 1.0

	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * move_speed if direction else move_toward(velocity.x, 0, move_speed)

	if direction:
		velocity.x = direction * move_speed
		# flip when direction changes
		if direction > 0 and not facing_right:
			facing_right = true
			flip_character(true)
		elif direction < 0 and facing_right:
			facing_right = false
			flip_character(false)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

	move_and_slide()

func flip_character(to_right: bool):
	$VisualRoot_Right.scale.x = 1.0 if to_right else -1.0

func _input(event):
	if Input.is_action_just_pressed("base_attack"):
			attack();

func attack():
	animation_player.play("BASE_ATTACK")

func die():
	print("Player died!")
