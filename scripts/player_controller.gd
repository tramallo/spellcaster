extends Node3D
## Controller of the local player: turns the keyboard and mouse into commands for the
## character it is attached to (its parent), and owns what only the local player has: the
## camera, the crosshair aim and the link to the HUD (hotbar, inventory).
##
## The character never reads any input itself, so a character without this node (the
## training dummy, a remote player) is exactly the same character, just not driven.

const RUNE_ACTIONS := [
	"rune_slot_0",
	"rune_slot_1",
	"rune_slot_2",
	"rune_slot_3",
]
## Aiming: how far the crosshair looks, and which physics layers it can hit (the world and
## the characters).
const AIM_RANGE := 500.0
const AIM_COLLISION_MASK := 3
## Closest an aimed-at surface can be to the aim pivot before the camera direction is used instead.
const AIM_MIN_DISTANCE := 0.5

@export var mouse_sensitivity: float = 0.08
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 40.0

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

var _character: CharacterBody3D
var _rune_bar: Control
var _inventory: Control


func _ready() -> void:
	_character = get_parent() as CharacterBody3D
	if _character == null:
		push_error("PlayerController must be a child of a character")
		return
	# Runs before the character's physics step, so it moves on this tick's input.
	process_physics_priority = -10
	_camera.current = true
	# The camera must not collide with the body it is attached to.
	_spring_arm.add_excluded_object(_character.get_rid())
	_character.aim_provider = _get_aim_direction
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Connects the controller to the local player's HUD. Called by the scene that owns it.
func setup(rune_bar: Control, inventory: Control) -> void:
	_rune_bar = rune_bar
	_inventory = inventory
	_inventory.opened.connect(_on_inventory_opened)
	_inventory.closed.connect(_on_inventory_closed)
	_character.cast_status.connect(_on_cast_status)
	_character.cast_ended.connect(_rune_bar.reset_charges)


func _is_inventory_open() -> bool:
	return _inventory != null and _inventory.is_open()


func _physics_process(_delta: float) -> void:
	if _character == null:
		return
	if _is_inventory_open():
		_character.move_input = Vector2.ZERO
		_character.sprint_input = false
		return
	_character.move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_character.sprint_input = Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("jump"):
		_character.request_jump()


func _unhandled_input(event: InputEvent) -> void:
	if _character == null:
		return

	if event.is_action_pressed("ui_cancel") and _inventory != null:
		_inventory.toggle()
		get_viewport().set_input_as_handled()
		return

	if _is_inventory_open():
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# The click that gives the mouse back to the game does nothing else.
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if _rune_bar != null:
		for i in RUNE_ACTIONS.size():
			var action: String = RUNE_ACTIONS[i]
			if event.is_action_pressed(action):
				_on_rune_pressed(i)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_released(action):
				_on_rune_released(i)
				get_viewport().set_input_as_handled()
				return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("release_spell"):
		_character.release_spell()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_character.turn(-deg_to_rad(event.relative.x * mouse_sensitivity))
		_spring_arm.rotation.x -= deg_to_rad(event.relative.y * mouse_sensitivity)
		_spring_arm.rotation.x = clampf(
			_spring_arm.rotation.x,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		get_viewport().set_input_as_handled()


func _on_rune_pressed(slot_index: int) -> void:
	var rune_id: String = _rune_bar.get_slot(slot_index).rune_id
	if rune_id.is_empty():
		return
	_rune_bar.set_slot_pressed(slot_index, true)
	_character.rune_pressed(rune_id)


func _on_rune_released(slot_index: int) -> void:
	var rune_id: String = _rune_bar.get_slot(slot_index).rune_id
	_rune_bar.set_slot_pressed(slot_index, false)
	_character.rune_released(rune_id)


func _on_cast_status(mana_radius: float, acceleration_speed: float, density: float) -> void:
	_rune_bar.update_mana(mana_radius)
	_rune_bar.update_acceleration(acceleration_speed)
	_rune_bar.update_density(density)


func _on_inventory_opened() -> void:
	_character.release_holds()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Aim direction for the character: from `from` (its aim pivot) toward what the crosshair (the
## centre of the view) points at: the first surface along the camera's line of sight, or a far
## point in the sky.
func _get_aim_direction(from: Vector3) -> Vector3:
	var origin := _camera.global_position
	var view_dir := -_camera.global_transform.basis.z
	var far_point := origin + view_dir * AIM_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, far_point, AIM_COLLISION_MASK)
	query.exclude = [_character.get_rid()]
	var hit := _character.get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit["position"] if not hit.is_empty() else far_point
	var to_target := target - from
	# A target right next to the body would give an unstable direction: use the view direction.
	if to_target.length() < AIM_MIN_DISTANCE:
		return view_dir
	return to_target.normalized()
