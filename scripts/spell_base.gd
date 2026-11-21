extends RigidBody3D

enum Phase { CASTING, RELEASED }

@export var start_radius: float = 0.075
@export var radius_growth_per_second: float = 0.28
@export var acceleration_growth_per_second: float = 12.0
@export var acceleration_start_speed: float = 5.0
## How quickly Release ramps along forward to the selected speed (higher = more abrupt).
@export var release_ramp_per_second: float = 8.0

var phase: Phase = Phase.CASTING
var radius: float = 0.075
## Deferred acceleration rune: speed reached along local forward (-Z) on Release.
var acceleration_speed: float = 0.0

var _ramping_acceleration: bool = false

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	freeze = true
	gravity_scale = 1.0
	continuous_cd = true

	_mesh_instance.mesh = _mesh_instance.mesh.duplicate()
	_collision_shape.shape = _collision_shape.shape.duplicate()

	radius = start_radius
	_apply_radius()


func _physics_process(delta: float) -> void:
	if not _ramping_acceleration:
		return

	var forward := get_forward()
	var along := linear_velocity.dot(forward)
	var step := maxf(acceleration_speed * release_ramp_per_second, 40.0) * delta
	var new_along := move_toward(along, acceleration_speed, step)
	linear_velocity += forward * (new_along - along)

	if is_equal_approx(new_along, acceleration_speed):
		_ramping_acceleration = false


func is_casting() -> bool:
	return phase == Phase.CASTING


func get_forward() -> Vector3:
	# Godot local forward is -Z.
	return -global_transform.basis.z.normalized()


func grow_mana(delta: float) -> void:
	if phase != Phase.CASTING:
		return
	radius += radius_growth_per_second * delta
	_apply_radius()


func begin_acceleration() -> void:
	if phase != Phase.CASTING:
		return
	# First activation starts at the baseline speed; later holds continue from the locked value.
	if acceleration_speed <= 0.0:
		acceleration_speed = acceleration_start_speed


func charge_acceleration(delta: float) -> void:
	if phase != Phase.CASTING:
		return
	if acceleration_speed <= 0.0:
		acceleration_speed = acceleration_start_speed
	acceleration_speed += acceleration_growth_per_second * delta


func release() -> void:
	if phase != Phase.CASTING:
		return
	phase = Phase.RELEASED
	freeze = false
	if acceleration_speed > 0.0:
		_ramping_acceleration = true


func _apply_radius() -> void:
	var sphere_mesh := _mesh_instance.mesh as SphereMesh
	if sphere_mesh:
		sphere_mesh.radius = radius
		sphere_mesh.height = radius * 2.0

	var sphere_shape := _collision_shape.shape as SphereShape3D
	if sphere_shape:
		sphere_shape.radius = radius

	# While casting, raise the center with the radius so the bottom stays at the
	# cast point and the orb does not dig into the floor as it grows.
	if phase == Phase.CASTING:
		position.y = radius
