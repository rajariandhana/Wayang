class_name Enemy
extends Wayang

var target: Wayang  # reference to player node

func on_ready():
	character_name = "Lupa namanya"  # antagonist wayang

func _physics_process(delta):
	print("")
	#idk 

func chase(delta):
	# nanti buat ngejer player 
	move_and_slide()

func attack():
	print("attack")

func die():
	print("Enemy defeated!")
	queue_free() 
