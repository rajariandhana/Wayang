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
const WAND_ANALOG_STICK := &"stick"

const WandPointer := preload("res://t5/wand_pointer.gd")

## content_scale maps the physical 0.7 m board to this many world units across.
## The gameplay quad is ~6 units wide, so 12 leaves a comfortable margin.
## Tune on hardware (10-15).
const BOARD_CONTENT_SCALE := 12.0
## Gameboard centre placed at the diorama's ground centre so the puppet stage
## stands upright on the board, facing the seated viewer (scene +Y = up).
const BOARD_ORIGIN := Vector3(0.0, -3.0, -0.5)

const STICK_DEADZONE := 0.15
## Frames to hold an injected p1_attack so is_action_just_pressed() latches once.
const ATTACK_HOLD_FRAMES := 2

signal t5_state_changed(active: bool)

var t5_active := false

var _manager: Node = null
var _gameboard: Node = null
var _rigs: Array = []
var _pointers := {}              # rig -> WandPointer
var _primary_wand: Node = null
var _primary_pointer: Node = null

var _wand_left := false
var _wand_right := false
var _attack_frames := 0

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
	# Gameboard: defines where and how large the diorama sits on the table.
	if ClassDB.class_exists(&"T5Gameboard"):
		_gameboard = ClassDB.instantiate(&"T5Gameboard")
		_gameboard.set(&"content_scale", BOARD_CONTENT_SCALE)
		_gameboard.set(&"transform", Transform3D(Basis.IDENTITY, BOARD_ORIGIN))
		add_child(_gameboard)

	# Instance the plugin manager via load() (never preload — keeps macOS clean).
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

	# Deferred so it runs after every autoload's _ready(), regardless of whether
	# T5Interface is ordered before or after this autoload.
	_ensure_interface_initialised.call_deferred()

## The T5Interface autoload may have run _ready() before the manager was
## registered (leaving the interface uninitialised); make sure it is running.
func _ensure_interface_initialised() -> void:
	var iface := get_node_or_null(^"/root/T5Interface")
	if iface == null:
		push_warning("[T5Runtime] T5Interface autoload missing - enable the Tilt Five plugin (Project Settings > Plugins) on this platform.")
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
	if _rigs.is_empty() and t5_active:
		t5_active = false
		t5_state_changed.emit(false)
		_release_wand_actions()

func _attach_rig(rig) -> void:
	if not is_instance_valid(rig) or not _rigs.has(rig):
		return
	var wand = rig.call(&"get_wand")
	if wand == null:
		# Wand node not ready yet; retry next frame.
		_attach_rig.call_deferred(rig)
		return

	var pointer := WandPointer.new()
	pointer.name = "WandPointer"
	pointer.process_mode = Node.PROCESS_MODE_ALWAYS
	wand.add_child(pointer)
	_pointers[rig] = pointer

	if not wand.is_connected(&"button_pressed", _on_wand_button_pressed):
		wand.connect(&"button_pressed", _on_wand_button_pressed)
		wand.connect(&"button_released", _on_wand_button_released)

	# First wand becomes the P1 controller / menu pointer.
	if _primary_wand == null:
		_primary_wand = wand
		_primary_pointer = pointer

# --- Wand input --------------------------------------------------------------

func _process(_delta: float) -> void:
	if _attack_frames > 0:
		_attack_frames -= 1
		if _attack_frames == 0:
			Input.action_release(&"p1_attack")

	if not t5_active or _primary_wand == null or not is_instance_valid(_primary_wand):
		return

	# In menus the stick must not drive the fighter.
	if _menu_open():
		_release_wand_actions()
		return

	var x: float = (_primary_wand.call(&"get_vector2", WAND_ANALOG_STICK) as Vector2).x
	if x > STICK_DEADZONE:
		Input.action_press(&"p1_right", x)
		_wand_right = true
	elif _wand_right:
		Input.action_release(&"p1_right")
		_wand_right = false
	if x < -STICK_DEADZONE:
		Input.action_press(&"p1_left", -x)
		_wand_left = true
	elif _wand_left:
		Input.action_release(&"p1_left")
		_wand_left = false

func _on_wand_button_pressed(button_name: StringName) -> void:
	match button_name:
		WAND_BUTTON_TRIGGER:
			if _menu_open():
				if _primary_pointer and is_instance_valid(_primary_pointer):
					_primary_pointer.call(&"click")
			else:
				Input.action_press(&"p1_attack")
				_attack_frames = ATTACK_HOLD_FRAMES
		WAND_BUTTON_T5, WAND_BUTTON_A:
			_inject_ui_cancel()

func _on_wand_button_released(_name: StringName) -> void:
	pass

func _menu_open() -> bool:
	for m in get_tree().get_nodes_in_group(&"t5_pointer_menu"):
		if is_instance_valid(m) and m.has_method(&"wants_pointer") and m.call(&"wants_pointer"):
			return true
	return false

func _release_wand_actions() -> void:
	if _wand_left:
		Input.action_release(&"p1_left")
		_wand_left = false
	if _wand_right:
		Input.action_release(&"p1_right")
		_wand_right = false

func _inject_ui_cancel() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = &"ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)
