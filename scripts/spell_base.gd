@tool
extends RigidBody3D
# @tool so the editor shows each spell at its start_radius; the gameplay code below only
# runs in the game (see the Engine.is_editor_hint() checks).

const ShapeCatalog = preload("res://scripts/shapes/shape_catalog.gd")

## FIZZLED: the spell failed and is dissolving (see `fizzle`).
enum Phase { CASTING, RELEASED, FIZZLED }

## A launched, shaped spell turns its point toward its direction of travel at this rate
## (per second), unless it moves slower than ALIGN_MIN_SPEED (m/s).
const ALIGN_RATE := 12.0
const ALIGN_MIN_SPEED := 0.5

const PhysicsLayers = preload("res://scripts/physics_layers.gd")

## A spell lives on the "magic" layer only, and collides with nothing but other magic things
## (spells): not the floor, not the characters' bodies. It hurts a character through the
## character's hurtboxes (see `hit_character`). A held spell has no collision at all.

## Longest a released spell is nudged forward, in metres, to get clear of its caster's hurtboxes.
const MAX_CLEARANCE_PUSH := 1.0
## Size of each of those nudges, in metres.
const CLEARANCE_STEP := 0.02

## Least starting mana a spell needs in order to exist.
const MIN_FORM_MANA := 0.0005
## A spell's mass is its mana (1 mana = 1 mass); this is the least it can have (physics needs
## a mass above 0).
const MIN_MASS := 0.001
## Smallest shortfall (mana) that counts as the reserve not being able to pay.
const MANA_EPSILON := 1e-9

## Radius, in metres, that 1 mana makes a spell at density 1 (the conversion rate between
## mana and size). Density then scales the radius down from there.
@export var radius_per_mana: float = 0.5
## Radius a spell starts with (at density 1). A summoned spell pays the matching mana.
@export var start_radius: float = 0.075:
	set(value):
		start_radius = value
		if Engine.is_editor_hint() and is_node_ready():
			_preview_start_radius()
## How strongly gravity pulls on every spell (1 = the world's gravity).
@export var spell_gravity_scale: float = 0.5
## Seconds the sphere takes to morph into a new shape (smooth start and end).
@export var shape_morph_time: float = 0.3
## Mana at which new mana stops making the spell bigger and starts making it denser instead.
## Around it the change is gradual (see `size_limit_softness`), never abrupt. The total size
## gained is always `size_limit_mana` worth of mana, so the largest radius a summoned spell
## reaches is `size_limit_mana * radius_per_mana` (0.5 mana * 0.5 = 0.25 m at defaults).
@export var size_limit_mana: float = 0.5
## Half the width of the crossing, in mana: below `size_limit_mana - softness` all new mana goes
## to size, above `size_limit_mana + softness` all of it goes to density, and in between the
## share shifts smoothly from one to the other.
@export var size_limit_softness: float = 0.375
## Mana summoned per second while holding the mana rune (before any ether shortage).
@export var mana_per_second: float = 1.0
## Density gained per second while holding the density rune (far from the cap).
@export var density_gain_per_second: float = 3.2
## Smallest radius density can compress to (approached softly).
@export var min_radius: float = 0.01
## Density distance below the cap (natural radius / min_radius) where the gain starts easing out.
@export var density_soft_range: float = 1.0
## Speed gained per second while holding the acceleration rune. With mana_per_acceleration
## this is also how much mana per second it costs the player's reserve (0.8 speed per second =
## 0.8 mana per second).
@export var acceleration_growth_per_second: float = 0.8
## Speed the acceleration rune starts at when first pressed (its minimum).
@export var acceleration_start_speed: float = 0.1
## Mana from the player's reserve that each 1 of acceleration speed costs.
@export var mana_per_acceleration: float = 1.0
## Seconds a failed spell takes to dissolve (see `fizzle`).
@export var fizzle_time: float = 0.35
## A spell that gets farther than this from the centre of the world (0, 0, 0), in any direction,
## disappears.
@export var max_distance_from_center: float = 1000.0
## Damage added per unit of acceleration speed (1 = every point of speed is one point of damage).
@export var damage_per_acceleration: float = 1.0
## Seconds a spell stays after it hurt something, before it disappears.
@export var despawn_delay_after_hit: float = 0.5

var phase: Phase = Phase.CASTING
## Actual collision / visual radius.
var radius: float = 0.075
## Mana amount (1 mana = `radius_per_mana` metres of radius at density 1).
var mana_radius: float = 0.15
## Current element ("" = pure mana). At most one element at a time.
var element: String = ""
## Acceleration rune: speed the spell is thrown at, along its aim, the instant it is released.
## Every 1 of speed is paid with `mana_per_acceleration` mana taken from the mana source
## (the player's reserve), not from the spell.
var acceleration_speed: float = 0.0

## Where this spell's mana comes from: any node with `draw_mana(requested) -> float` (the
## player's reserve). With no source (props placed in a scene, tests) mana is unlimited.
var mana_source: Node

## While casting, the node (the caster's fingertips) the spell is held in front of. The spell
## is not a child of it: it follows it, and is pushed out of the world by collisions, so it
## never drags the caster along.
var anchor: Node3D
## Optional node (the player) with `get_cast_position() -> Vector3` (the live fingertips) and
## `get_aim_direction() -> Vector3`. While casting, the spell is held at that position and
## points along that direction: at what the caster's crosshair is on. Without it the spell
## is held at the anchor and points along the anchor's forward direction.
var aimer: Node

## True once this spell has hurt something: it deals damage only once.
var _has_hit: bool = false
## Direction the spell was pointing (the aim) at the moment of release.
var _launch_direction: Vector3 = Vector3.FORWARD
## The character holding this spell.
var _caster: Node
var _shader_material: ShaderMaterial
## Shape being shown ("sphere" until a shape rune sets one) and the morph towards it:
## progress runs 0..1 over `shape_morph_time`, `_shape_t` is its smoothed version.
## `_shape_target` is the shape the spell was last set to: when it differs from `_shape_id`
## the shown shape eases back to the sphere and the target forms from there.
var _shape_id: String = "sphere"
var _shape_target: String = "sphere"
var _morph_progress: float = 1.0
var _shape_t: float = 0.0
var _sphere_shape: SphereShape3D
var _convex_shape: ConvexPolygonShape3D

@onready var _mesh_instance: MeshInstance3D = $Mesh
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_start_radius()
		return

	freeze = true
	# Kinematic freeze: the held spell is moved by code (and has no collision while held).
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	gravity_scale = spell_gravity_scale
	# Ignore the world/project default damping so speed isn't lost after the acceleration ramp.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	continuous_cd = true
	_mesh_instance.mesh = _mesh_instance.mesh.duplicate()
	_collision_shape.shape = _collision_shape.shape.duplicate()
	_sphere_shape = _collision_shape.shape as SphereShape3D
	if _mesh_instance.mesh is SphereMesh and (_mesh_instance.mesh as SphereMesh).material is ShaderMaterial:
		_shader_material = (_mesh_instance.mesh as SphereMesh).material.duplicate() as ShaderMaterial
		(_mesh_instance.mesh as SphereMesh).material = _shader_material

	radius = start_radius
	mana_radius = start_radius / maxf(radius_per_mana, 0.0001)
	_update_mass()
	# Spells placed in a scene keep their position: only a spell given an anchor is moved.
	_apply_radius()


## Editor only: shows the spell at its start_radius (the mesh and shape are local to the
## scene, so every spell instance has its own).
func _preview_start_radius() -> void:
	var sphere_mesh := _mesh_instance.mesh as SphereMesh
	if sphere_mesh != null:
		sphere_mesh.radius = start_radius
		sphere_mesh.height = start_radius * 2.0
	var sphere_shape := _collision_shape.shape as SphereShape3D
	if sphere_shape != null:
		sphere_shape.radius = start_radius


## Starts holding this spell in front of `new_anchor` (the caster's fingertips). While held it
## has no collision at all: it collides (see `release`) only once it is thrown.
func begin_casting(new_anchor: Node3D, new_aimer: Node = null) -> void:
	anchor = new_anchor
	aimer = new_aimer
	collision_layer = 0
	collision_mask = 0
	_caster = new_aimer
	_follow_anchor()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_shape_morph(delta)
	# Runs after the caster's animation has posed the fingertips (it comes later in the tree).
	if phase != Phase.CASTING:
		return
	_follow_anchor()


## Sets the spell's shape to `new_shape` (an id from ShapeCatalog), replacing the one it has.
## The result is the same however many times in a row it is set. The change is a short smooth
## morph (a spell that already has a shape eases back to the sphere first). Only while casting.
func set_shape(new_shape: String) -> void:
	if phase != Phase.CASTING or new_shape == "sphere" or new_shape == _shape_target:
		return
	if _shader_material == null or ShapeCatalog.morph_mesh(new_shape) == null:
		return
	_shape_target = new_shape
	if _shape_id == "sphere":
		_start_shape(new_shape)


## Shows `new_shape` on the morph mesh, starting from the sphere.
func _start_shape(new_shape: String) -> void:
	_shape_id = new_shape
	_morph_progress = 0.0
	_shape_t = 0.0
	_mesh_instance.mesh = ShapeCatalog.morph_mesh(new_shape)
	_mesh_instance.set_surface_override_material(0, _shader_material)
	_shader_material.set_shader_parameter("morph_enabled", true)
	_shader_material.set_shader_parameter("shape_morph", 0.0)
	_apply_radius()


## The shape the spell has been set to ("sphere" until a shape rune sets one).
func get_shape() -> String:
	return _shape_target


## Distance from the spell's centre back to its rearmost point: the radius for a sphere,
## less for a shape whose back is flat; follows the morph while it plays.
func get_back_extent() -> float:
	return radius * lerpf(1.0, ShapeCatalog.back_extent(_shape_id), _shape_t)


func _update_shape_morph(delta: float) -> void:
	if _shape_id == "sphere":
		return
	var step := delta / maxf(shape_morph_time, 0.001)
	if _shape_target != _shape_id:
		# The shape is being replaced: the one shown eases back to the sphere (its collision
		# is the sphere again from the first moment), then the new one forms.
		var was_complete := _morph_progress >= 1.0
		_morph_progress = maxf(_morph_progress - step, 0.0)
		_apply_morph()
		if was_complete:
			_apply_radius()
		if _morph_progress <= 0.0:
			_start_shape(_shape_target)
		return
	if _morph_progress >= 1.0:
		return
	_morph_progress = minf(_morph_progress + step, 1.0)
	_apply_morph()
	if _morph_progress >= 1.0:
		# Morph done: swap the collision from the sphere to the shape itself.
		_apply_radius()


func _apply_morph() -> void:
	_shape_t = smoothstep(0.0, 1.0, _morph_progress)
	_shader_material.set_shader_parameter("shape_morph", _shape_t)


## Moves the spell to its held position (back edge on the anchor, growing forward from it).
func _follow_anchor() -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var held_basis := anchor.global_transform.basis.orthonormalized()
	var hold_point := anchor.global_position
	if aimer != null and is_instance_valid(aimer):
		# The aimer knows the live hand position (exact on every frame) and the aim direction,
		# which does not depend on the hands: the point stays on the aim whatever the arm does
		# and wherever collisions push the spell.
		hold_point = aimer.get_cast_position()
		var aim: Vector3 = aimer.get_aim_direction()
		if aim.length_squared() > 0.5:
			# Local -Z is forward; keep it level with the world (no roll).
			var up := Vector3.UP if absf(aim.y) < 0.999 else Vector3.FORWARD
			held_basis = Basis.looking_at(aim, up)
	# The spell's back edge is on the hold point, so its centre is ahead of it (-Z) by the
	# distance from the centre to the back of the shape.
	global_transform = Transform3D(held_basis, hold_point - held_basis.z * get_back_extent())

## After launch, every spell keeps its front toward where it is going, like a dart, and does
## not tumble. It is left alone when it is almost still (resting, or just hit something).
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Engine.is_editor_hint() or phase != Phase.RELEASED:
		return
	var velocity := state.linear_velocity
	if velocity.length() < ALIGN_MIN_SPEED:
		return
	var current := state.transform.basis.orthonormalized()
	var direction := velocity.normalized()
	var up := current.y
	if absf(direction.dot(up)) > 0.99:
		up = current.x
	var target := Basis.looking_at(direction, up)
	state.transform.basis = current.slerp(target, 1.0 - exp(-ALIGN_RATE * state.step))
	state.angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Guard: nothing may fly off forever.
	if global_position.length() > max_distance_from_center:
		queue_free()


## Damage dealt to whatever a released spell touches: its mana, plus its acceleration speed
## times damage_per_acceleration. Other modifiers (density, shape, element) do not count yet.
func get_damage() -> float:
	return mana_radius + acceleration_speed * damage_per_acceleration


## Called by a hurtbox (a part of a character's body) the spell has entered. A released spell
## hurts that character (anything with a `take_damage` method), once, and disappears
## despawn_delay_after_hit seconds later. A spell that is still held hurts nobody.
func hit_character(target: Node) -> void:
	if phase != Phase.RELEASED:
		return
	if _has_hit or not target.has_method("take_damage"):
		return
	_has_hit = true
	target.take_damage(get_damage())
	get_tree().create_timer(despawn_delay_after_hit).timeout.connect(_disappear)


func _disappear() -> void:
	if is_inside_tree():
		queue_free()


func is_casting() -> bool:
	return phase == Phase.CASTING


func get_forward() -> Vector3:
	# Godot local forward is -Z.
	return -global_transform.basis.z.normalized()


const ELEMENT_COLORS := {
	"": {"mana": Color(0.42, 0.78, 1.0, 0.5), "glow": Color(0.55, 0.88, 1.0, 1.0)},
	"fire": {"mana": Color(1.0, 0.38, 0.08, 0.5), "glow": Color(1.0, 0.6, 0.2, 1.0)},
}


## Sets or replaces the spell's element (does not affect the Casting phase).
func set_element(new_element: String) -> void:
	if phase != Phase.CASTING:
		return
	if not ELEMENT_COLORS.has(new_element):
		return
	element = new_element
	if _shader_material != null:
		var colors: Dictionary = ELEMENT_COLORS[element]
		_shader_material.set_shader_parameter("mana_color", colors["mana"])
		_shader_material.set_shader_parameter("glow_color", colors["glow"])


## The spell's mass is its mana, 1 to 1 (density and size do not change it).
func _update_mass() -> void:
	mass = maxf(mana_radius, MIN_MASS)


## Radius the spell would have at density 1 for its current mana.
func get_natural_radius() -> float:
	return mana_radius * radius_per_mana


func get_density() -> float:
	return get_natural_radius() / maxf(radius, 0.0001)


## Fraction (0..1) of newly added mana that makes the spell bigger when it holds `mana`:
## 1 well below the size limit, 0 well above it, a smooth (smoothstep) crossing in between.
func get_size_share(mana: float) -> float:
	var half_width := maxf(size_limit_softness, 0.0001)
	return 1.0 - smoothstep(size_limit_mana - half_width, size_limit_mana + half_width, mana)


## Takes `requested` mana from the mana source and returns how much it gave (less when the
## source runs low, zero when it is empty). With no source it gives everything.
func _take_mana(requested: float) -> float:
	if mana_source == null or not is_instance_valid(mana_source):
		return requested
	return mana_source.draw_mana(requested)


## A newly summoned spell pays for its starting mana from its mana source (the player's
## reserve). Returns false, taking nothing, when the source holds less than that, so the spell
## cannot form at all. (Props placed in a scene never call this and just keep their start_radius.)
func draw_initial_mana() -> bool:
	if mana_source == null or not is_instance_valid(mana_source):
		return true

	var start_mana := start_radius / maxf(radius_per_mana, 0.0001)
	if "mana" in mana_source and mana_source.mana < start_mana:
		return false
	var granted: float = _take_mana(start_mana)
	if granted < MIN_FORM_MANA:
		return false

	mana_radius = granted
	radius = maxf(granted * radius_per_mana, 0.001)
	_update_mass()
	_apply_radius()
	return true


## Summons mana for `delta` seconds from the mana source (the player's reserve). Returns false
## when the source cannot pay all of it: the spell has failed (see `fizzle`) and the caller
## must fail it. Without a source the mana is unlimited.
func grow_mana(delta: float) -> bool:
	if phase != Phase.CASTING:
		return true
	var requested := mana_per_second * delta
	var granted := _take_mana(requested)
	if granted < requested - MANA_EPSILON:
		return false

	# New mana goes partly to size and partly to density: the size share is 1 for small spells
	# and fades smoothly to 0 around `size_limit_mana`. The radius only grows by its share,
	# while the natural radius (the mana) grows fully, so the rest shows up as density.
	var size_share := get_size_share(mana_radius + granted * 0.5)
	mana_radius += granted
	radius += granted * radius_per_mana * size_share
	_update_mass()
	_apply_radius()
	return true

func densify(delta: float) -> void:
	if phase != Phase.CASTING:
		return
	# Density is the quantity being changed; size follows (radius = natural radius / density,
	# where the natural radius is mana * radius_per_mana). The mana amount and mass are untouched.
	# The size floor min_radius corresponds to a density cap of natural radius / min_radius,
	# approached softly: the gain eases out with tanh, so there is no knee at the limit.
	var natural := get_natural_radius()
	if natural <= min_radius:
		# Already smaller than the size floor: nothing to compress.
		return
	var max_density := natural / min_radius
	var density := get_density()
	var headroom := maxf(max_density - density, 0.0)
	var gain := density_gain_per_second * tanh(headroom / density_soft_range) * delta
	density = minf(density + gain, max_density)
	radius = maxf(natural / density, min_radius)
	_apply_radius()


## Pays for `speed_gain` of acceleration speed with mana from the mana source (the player's
## reserve); the spell's own mana, size, density and mass are not touched. Returns false when
## the source cannot pay all of it (it gives what it has left): the spell has failed.
func _pay_acceleration(speed_gain: float) -> bool:
	var cost := speed_gain * mana_per_acceleration
	if cost <= 0.0:
		return true
	return _take_mana(cost) >= cost - MANA_EPSILON


## The acceleration rune was pressed. The first time it starts at `acceleration_start_speed`
## (and pays for it); later presses continue from the locked value for free. Returns false when
## the reserve cannot pay the minimum start: the spell has failed.
func begin_acceleration() -> bool:
	if phase != Phase.CASTING:
		return true
	if acceleration_speed > 0.0:
		return true
	if not _pay_acceleration(acceleration_start_speed):
		return false
	acceleration_speed = acceleration_start_speed
	return true


## Raises the acceleration speed while the rune is held, paying with the player's reserve.
## Returns false when the reserve cannot pay: the spell has failed.
func charge_acceleration(delta: float) -> bool:
	if phase != Phase.CASTING:
		return true
	if acceleration_speed <= 0.0 and not begin_acceleration():
		return false
	var gain := acceleration_growth_per_second * delta
	if not _pay_acceleration(gain):
		return false
	acceleration_speed += gain
	return true

## The spell failed (the reserve could not pay a rune): it dissolves and all the
## mana invested in it is lost. It deals no damage and is gone after `fizzle_time` seconds.
func fizzle() -> void:
	if phase != Phase.CASTING:
		return
	phase = Phase.FIZZLED
	anchor = null
	aimer = null
	_caster = null
	collision_layer = 0
	collision_mask = 0
	var dissolve := create_tween()
	dissolve.tween_property(_mesh_instance, "scale", Vector3.ZERO, fizzle_time)
	dissolve.tween_callback(queue_free)


func release() -> void:
	if phase != Phase.CASTING:
		return
	# Last update of the held pose, so the launch direction is the aim at this very moment.
	_follow_anchor()
	# While held, the front points along the line from the caster's body pivot (steady while the
	# hand moves). Once launched it must reach what the crosshair points at, so it turns to aim
	# from where it actually is: the hand is not on the pivot's line.
	if aimer != null and is_instance_valid(aimer) and aimer.has_method("get_aim_direction_from"):
		var aim: Vector3 = aimer.get_aim_direction_from(global_position)
		if aim.length_squared() > 0.5:
			var up := Vector3.UP if absf(aim.y) < 0.999 else Vector3.FORWARD
			global_transform.basis = Basis.looking_at(aim, up)
	_launch_direction = get_forward()
	phase = Phase.RELEASED
	anchor = null
	aimer = null
	# The hand holding the spell is inside the caster's hurtboxes: move the spell forward just
	# enough to be clear of them, and only then give it its collision.
	_move_clear_of_caster()
	_caster = null
	collision_layer = PhysicsLayers.MAGIC
	collision_mask = PhysicsLayers.MAGIC
	freeze = false
	# A frozen body that code was moving (the spell follows the hand) takes the speed of that
	# movement along when it unfreezes: start from rest, then the acceleration rune throws the
	# spell at its speed the same instant (gravity and collisions decide the rest).
	linear_velocity = _launch_direction * acceleration_speed
	angular_velocity = Vector3.ZERO


## Moves the spell along its launch direction, in small steps, until it no longer overlaps any
## hurtbox of its caster (so it does not hit its own caster the moment it is thrown).
func _move_clear_of_caster() -> void:
	if _caster == null or not is_instance_valid(_caster) or _collision_shape.shape == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _collision_shape.shape
	query.collision_mask = PhysicsLayers.MAGIC
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var space := get_world_3d().direct_space_state
	for step in int(MAX_CLEARANCE_PUSH / CLEARANCE_STEP):
		query.transform = global_transform * _collision_shape.transform
		var overlapping := false
		for hit in space.intersect_shape(query, 32):
			if hit["collider"].get("character") == _caster:
				overlapping = true
				break
		if not overlapping:
			return
		global_position += _launch_direction * CLEARANCE_STEP


func _apply_radius() -> void:
	if _shape_id == "sphere":
		var sphere_mesh := _mesh_instance.mesh as SphereMesh
		if sphere_mesh:
			sphere_mesh.radius = radius
			sphere_mesh.height = radius * 2.0
	elif _shader_material != null:
		# The morph mesh has unit size: the shader scales it by the radius. Its bounds
		# are in unit size too, so tell the renderer the real ones.
		_shader_material.set_shader_parameter("shape_scale", radius)
		var reach := radius * 1.25
		_mesh_instance.custom_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)

	# Collision: a sphere, except once the morph into a shape is complete.
	if _shape_id != "sphere" and _morph_progress >= 1.0:
		if _convex_shape == null:
			_convex_shape = ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for corner in ShapeCatalog.corners(_shape_id):
			points.append(corner * radius)
		_convex_shape.points = points
		if _collision_shape.shape != _convex_shape:
			_collision_shape.shape = _convex_shape
	elif _sphere_shape != null:
		_sphere_shape.radius = radius
		if _collision_shape.shape != _sphere_shape:
			_collision_shape.shape = _sphere_shape

	if _shader_material != null:
		_shader_material.set_shader_parameter("density_factor", get_density())
