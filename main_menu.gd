extends Control

# This grabs our "Stick" containers
@onready var start_stick = $DatStick
@onready var quit_stick = $DatStick2

func _ready():
	# This connects the mouse hovering over the Button to our wobble animation
	$DatStick/Button.mouse_entered.connect(_wobble_stick.bind(start_stick))
	$DatStick2/Button.mouse_entered.connect(_wobble_stick.bind(quit_stick))

func _wobble_stick(node_to_wobble):
	var tween = create_tween()
	
	# This makes the movement smooth and organic, like a real hand
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Reduced from 5 degrees to a very subtle 1.5 and 1 degrees.
	# Also slightly slowed down the speed from 0.1 to 0.15 seconds.
	tween.tween_property(node_to_wobble, "rotation", deg_to_rad(1.5), 0.1)
	tween.chain().tween_property(node_to_wobble, "rotation", deg_to_rad(-1.0), 0.1)
	tween.chain().tween_property(node_to_wobble, "rotation", deg_to_rad(0), 0.1)

func _on_start_pressed():
	# We will make this scene later!
	get_tree().change_scene_to_file("res://level_1.tscn")

func _on_quit_pressed():
	get_tree().quit()
