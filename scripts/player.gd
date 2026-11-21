extends CharacterBody3D

@export var move_speed: float = 5.5
@export var turn_speed: float = 4.0
@export var mouse_sensitivity: float = 0.08
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 40.0

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D
@onready var cast_point: Node3D = $CastPoint


func _ready() -> void:
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_inventory_open() -> bool:
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	return inv != null and inv.has_method("is_open") and inv.is_open()


func _unhandled_input(event: InputEvent) -> void:
	if _is_inventory_open():
		return

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		# When already captured, leave the click unhandled so Main can release spells.
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		# Body yaw follows the view. Sensitivity is degrees per mouse pixel.
		rotate_y(-deg_to_rad(event.relative.x * mouse_sensitivity))
		# Pitch the shoulder arm only (non-inverted).
		_spring_arm.rotation.x -= deg_to_rad(event.relative.y * mouse_sensitivity)
		_spring_arm.rotation.x = clampf(
			_spring_arm.rotation.x,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _is_inventory_open():
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		if not is_on_floor():
			velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Move relative to view/body yaw (they stay aligned).
	var forward := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	var right := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z)
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()

	var direction := right * input_dir.x + forward * -input_dir.y
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0

	move_and_slide()
