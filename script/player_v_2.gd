extends Wayang

const GRAVITY = 8000.0
const JUMP_FORCE = -2000.0
const DECELERATION = 4000.0

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Jump
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		velocity.y = JUMP_FORCE

	# Movement
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
	
	if Input.is_action_just_pressed("ui_left"):
		print("left")
		$Skeleton2D/Hip.scale.x = -1
	elif Input.is_action_just_pressed("ui_right"):
		print("right")
		$Skeleton2D/Hip.scale.x = 1
	move_and_slide()

func _input(event):
	if event.is_action_pressed("base_attack"):
		attack()

func attack():
	animation_player.play("BASE_ATTACK")

func die():
	print("Player died!")
