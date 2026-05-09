extends Wayang

func on_ready():
	character_name = "Anoman"
	health_bar.set_health(current_health, max_health)

func _physics_process(delta):
	super(delta)
	if Input.is_action_just_pressed("base_attack"):
		#print("pressed base_attack")
		attack()
	
	# Jump
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		print("jump")
		velocity.y = JUMP_FORCE

	# Movement
	var direction = Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
	
	if Input.is_action_just_pressed("ui_left"):
		# print("left")
		turn(false)
	elif Input.is_action_just_pressed("ui_right"):
		# print("right")
		turn(true)
	move_and_slide()

func _input(event):
	super(event)
	pass
	#if Input.is_action_just_pressed("base_attack"):
		#print("pressed base_attack")
		#attack()

func attack():
	animation_player.play("BASE_ATTACK")

func die():
	print("Player died!")

func take_damage(amount: int):
	super(amount)  # runs Wayan 
	health_bar.set_health(current_health, max_health)
	
