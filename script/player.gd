class_name Player
extends Wayang

func on_ready():
	character_name = "Anoman"  

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * move_speed if direction else move_toward(velocity.x, 0, move_speed)
	move_and_slide()

func attack():
	print("attack")
	# idk do something
	# later: spawn projectile, play animation, etc.

func die():
	print("Player died!")
	# later: game over screen
