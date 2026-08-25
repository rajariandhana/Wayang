extends Node
## Tilt Five runtime integration for Wayang.
##
## Registered as an autoload. Gates every Tilt Five behaviour behind runtime
## availability so the game keeps running as a normal flat-screen build wherever
## the (Windows-only) TiltFiveGodot4 GDExtension is absent — e.g. the macOS dev
## machines. On macOS is_t5_available() returns false and this node does nothing
## beyond printing a one-line notice.
##
## IMPORTANT: nothing here may statically reference a Tilt Five type (T5Manager,
## T5Gameboard, T5XRRig, T5Controller3D, T5Def, ...). Those only exist when the
## extension is loaded; naming them would make this script fail to compile on
## macOS. We use load(), ClassDB.instantiate() and dynamic call()/get()/set(),
## and inline the wand input names from addons/tiltfive/T5Def.gd.

# --- Wand input names (mirror of addons/tiltfive/T5Def.gd) ---
const WAND_BUTTON_TRIGGER := &"trigger_click"
const WAND_BUTTON_T5 := &"button_t5"
const WAND_BUTTON_A := &"button_a"
const WAND_BUTTON_1 := &"button_1"
const WAND_BUTTON_2 := &"button_2"
const WAND_ANALOG_STICK := &"stick"

const WandPointer := preload("res://t5/wand_pointer.gd")

const BOARD_CONTENT_SCALE := 12.0
const BOARD_ORIGIN := Vector3(0.0, -3.0, -0.5)
const STICK_DEADZONE := 0.15
const ATTACK_HOLD_FRAMES := 2

signal t5_state_changed(active: bool)

var t5_active := false

var _manager: Node = null
var _gameboard: Node = null
var _rigs: Array = []
var _pointers := {}
var _primary_wand: Node = null
var _primary_pointer: Node = null
var _secondary_wand: Node = null
var _secondary_pointer: Node = null

# Stick-hold state
var _wand_left := false
var _wand_right := false
var _wand_up := false
var _wand_down := false
var _wand2_left := false
var _wand2_right := false
var _wand2_up := false
var _wand2_down := false

# Attack frame latching per player
var _attack_frames := 0
var _attack2_frames := 0

func is_t5_available() -> bool:
	return ClassDB.class_exists(&"TiltFiveXRInterface") and XRServer.find_interface(&"TiltFive") != null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not is_t5_available():
		print("[T5Runtime] Tilt Five unavailable - flat-screen fallback mode.")
		return
	print("[T5Runtime] Tilt Five interface detected - initialising AR rig.")
	_setup_manager()

func _setup_manager() -> void:
	if ClassDB.class_exists(&"T5Gameboard"):
		_gameboard = ClassDB.instantiate(&"T5Gameboard")
		_gameboard.set(&"content_scale", BOARD_CONTENT_SCALE)
		_gameboard.set(&"transform", Transform3D(Basis.IDENTITY, BOARD_ORIGIN))
		add_child(_gameboard)

	var manager_script: Script = load("res://addons/tiltfive/T5Manager.gd")
	if manager_script == null:
		push_error("[T5Runtime] Could not load T5Manager.gd")
		return
	_manager = manager_script.new()
	_manager.name = "T5Manager"
	_manager.process_mode = Node.PROCESS_MODE_ALWAYS
	if _gameboard:
		_manager.set(&"start_location", _gameboard)
	_manager.connect(&"xr_rig_was_added", _on_rig_added)
	_manager.connect(&"xr_rig_will_be_removed", _on_rig_removed)
	add_child(_manager)

	_ensure_interface_initialised.call_deferred()

func _ensure_interface_initialised() -> void:
	var iface := get_node_or_null(^"/root/T5Interface")
	if iface == null:
		push_warning("[T5Runtime] T5Interface autoload missing.")
		return
	var xr = iface.call(&"get_tilt_five_xr_interface")
	if xr and not xr.call(&"is_initialized"):
		xr.call(&"initialize")

# --- Rig lifecycle -----------------------------------------------------------

func _on_rig_added(rig) -> void:
	if not _rigs.has(rig):
		_rigs.append(rig)
	_attach_rig.call_deferred(rig)
	if not t5_active:
		t5_active = true
		t5_state_changed.emit(true)

func _on_rig_removed(rig) -> void:
	_rigs.erase(rig)
	var p = _pointers.get(rig)
	if p and is_instance_valid(p):
		p.queue_free()
	_pointers.erase(rig)
	if _primary_wand and rig.call(&"get_wand") == _primary_wand:
		_primary_wand = null
		_primary_pointer = null
	if _secondary_wand and rig.call(&"get_wand") == _secondary_wand:
		_secondary_wand = null
		_secondary_pointer = null
	if _rigs.is_empty() and t5_active:
		t5_active = false
		t5_state_changed.emit(false)
		_release_wand_actions()

func _attach_rig(rig) -> void:
	if not is_instance_valid(rig) or not _rigs.has(rig):
		return
	var wand = rig.call(&"get_wand")
	if wand == null:
		_attach_rig.call_deferred(rig)
		return

	var pointer := WandPointer.new()
	pointer.name = "WandPointer"
	pointer.process_mode = Node.PROCESS_MODE_ALWAYS
	wand.add_child(pointer)
	_pointers[rig] = pointer

	# First wand = P1, second wand = P2
	if _primary_wand == null:
		_primary_wand = wand
		_primary_pointer = pointer
		if not wand.is_connected(&"button_pressed", _on_p1_button_pressed):
			wand.connect(&"button_pressed", _on_p1_button_pressed)
			wand.connect(&"button_released", _on_p1_button_released)
		print("[T5Runtime] Wand 1 (P1) attached.")
	elif _secondary_wand == null:
		_secondary_wand = wand
		_secondary_pointer = pointer
		if not wand.is_connected(&"button_pressed", _on_p2_button_pressed):
			wand.connect(&"button_pressed", _on_p2_button_pressed)
			wand.connect(&"button_released", _on_p2_button_released)
		print("[T5Runtime] Wand 2 (P2) attached.")

# --- Per-frame stick reading -------------------------------------------------

func _process(_delta: float) -> void:
	if _attack_frames > 0:
		_attack_frames -= 1
		if _attack_frames == 0:
			Input.action_release(&"p1_attack")
	if _attack2_frames > 0:
		_attack2_frames -= 1
		if _attack2_frames == 0:
			Input.action_release(&"p2_attack")

	if not t5_active:
		return
	if _menu_open():
		_release_wand_actions()
		return

	# P1 stick (analog fallback alongside buttons)
	if _primary_wand and is_instance_valid(_primary_wand):
		var stick1: Vector2 = _primary_wand.call(&"get_vector2", WAND_ANALOG_STICK)
		if stick1.x > STICK_DEADZONE:
			Input.action_press(&"p1_right", stick1.x)
			_wand_right = true
		elif _wand_right:
			Input.action_release(&"p1_right")
			_wand_right = false
		if stick1.x < -STICK_DEADZONE:
			Input.action_press(&"p1_left", -stick1.x)
			_wand_left = true
		elif _wand_left:
			Input.action_release(&"p1_left")
			_wand_left = false
		# Vertical is not flipped between players — rise/dip isn't a "toward
		# opponent" concept, unlike left/right.
		if stick1.y > STICK_DEADZONE:
			Input.action_press(&"p1_up", stick1.y)
			_wand_up = true
		elif _wand_up:
			Input.action_release(&"p1_up")
			_wand_up = false
		if stick1.y < -STICK_DEADZONE:
			Input.action_press(&"p1_down", -stick1.y)
			_wand_down = true
		elif _wand_down:
			Input.action_release(&"p1_down")
			_wand_down = false

	# P2 stick
	if _secondary_wand and is_instance_valid(_secondary_wand):
		var stick2: Vector2 = _secondary_wand.call(&"get_vector2", WAND_ANALOG_STICK)
		# X stays unflipped, same as Y (see P1 above).
		if stick2.x > STICK_DEADZONE:
			Input.action_press(&"p2_right", stick2.x)
			_wand2_right = true
		elif _wand2_right:
			Input.action_release(&"p2_right")
			_wand2_right = false
		if stick2.x < -STICK_DEADZONE:
			Input.action_press(&"p2_left", -stick2.x)
			_wand2_left = true
		elif _wand2_left:
			Input.action_release(&"p2_left")
			_wand2_left = false
		# Vertical stays unflipped (see P1 above).
		if stick2.y > STICK_DEADZONE:
			Input.action_press(&"p2_up", stick2.y)
			_wand2_up = true
		elif _wand2_up:
			Input.action_release(&"p2_up")
			_wand2_up = false
		if stick2.y < -STICK_DEADZONE:
			Input.action_press(&"p2_down", -stick2.y)
			_wand2_down = true
		elif _wand2_down:
			Input.action_release(&"p2_down")
			_wand2_down = false

# --- P1 wand buttons ---------------------------------------------------------

func _on_p1_button_pressed(button_name: StringName) -> void:
	match button_name:
		WAND_BUTTON_TRIGGER:
			if _menu_open():
				if _primary_pointer and is_instance_valid(_primary_pointer):
					_primary_pointer.call(&"click")
			else:
				Input.action_press(&"p1_attack")
				_attack_frames = ATTACK_HOLD_FRAMES
		WAND_BUTTON_1:
			# Button 1 = back = LEFT for P1
			if not _menu_open():
				Input.action_press(&"p1_left")
		WAND_BUTTON_2:
			# Button 2 = front = RIGHT for P1
			if not _menu_open():
				Input.action_press(&"p1_right")
		WAND_BUTTON_T5, WAND_BUTTON_A:
			_inject_ui_cancel()

func _on_p1_button_released(button_name: StringName) -> void:
	match button_name:
		WAND_BUTTON_1:
			Input.action_release(&"p1_left")
		WAND_BUTTON_2:
			Input.action_release(&"p1_right")

# --- P2 wand buttons ----------------------------------------------------------

func _on_p2_button_pressed(button_name: StringName) -> void:
	match button_name:
		WAND_BUTTON_TRIGGER:
			if _menu_open():
				if _secondary_pointer and is_instance_valid(_secondary_pointer):
					_secondary_pointer.call(&"click")
			else:
				Input.action_press(&"p2_attack")
				_attack2_frames = ATTACK_HOLD_FRAMES
		WAND_BUTTON_1:
			# Button 1 = back = LEFT for P2 (same mapping as P1).
			if not _menu_open():
				Input.action_press(&"p2_left")
		WAND_BUTTON_2:
			# Button 2 = front = RIGHT for P2 (same mapping as P1).
			if not _menu_open():
				Input.action_press(&"p2_right")
		WAND_BUTTON_T5, WAND_BUTTON_A:
			_inject_ui_cancel()

func _on_p2_button_released(button_name: StringName) -> void:
	match button_name:
		WAND_BUTTON_1:
			Input.action_release(&"p2_left")
		WAND_BUTTON_2:
			Input.action_release(&"p2_right")

# --- Helpers -----------------------------------------------------------------

func _menu_open() -> bool:
	for m in get_tree().get_nodes_in_group(&"t5_pointer_menu"):
		if is_instance_valid(m) and m.has_method(&"wants_pointer") and m.call(&"wants_pointer"):
			return true
	return false

func _release_wand_actions() -> void:
	if _wand_left:
		Input.action_release(&"p1_left"); _wand_left = false
	if _wand_right:
		Input.action_release(&"p1_right"); _wand_right = false
	if _wand_up:
		Input.action_release(&"p1_up"); _wand_up = false
	if _wand_down:
		Input.action_release(&"p1_down"); _wand_down = false
	if _wand2_left:
		Input.action_release(&"p2_left"); _wand2_left = false
	if _wand2_right:
		Input.action_release(&"p2_right"); _wand2_right = false
	if _wand2_up:
		Input.action_release(&"p2_up"); _wand2_up = false
	if _wand2_down:
		Input.action_release(&"p2_down"); _wand2_down = false

func _inject_ui_cancel() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = &"ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)
