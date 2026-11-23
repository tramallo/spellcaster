extends CharacterBody3D
## A character of the game: body, animations, mana reserve and spellcasting. The player and
## the training dummy are instances of the same scene (`scenes/character.tscn`).
##
## A character has no input of its own. Whatever drives it (the player's controller, a test,
## later the network) does it through the intent API below, so every character behaves the
## same way no matter who is controlling it:
##   - `move_input`, `sprint_input`, `request_jump()`, `turn(yaw)`: movement
##   - `aim_provider`: where the character is aiming
##   - `rune_pressed(id)`, `rune_released(id)`, `release_spell()`, `release_holds()`: casting
## A character nobody drives just stands there (idle), absorbing ether.

## Emitted whenever the mana reserve changes (and once when it is first filled).
signal mana_changed(current: float, maximum: float)
## Emitted whenever the health changes (and once when it is first filled).
signal health_changed(current: float, maximum: float)
## Emitted once, when the health reaches 0 and the character dies.
signal died
## Emitted when the spell being cast fails (no rune causes it for now):
## it dissolves and the mana invested in it is lost.
signal spell_fizzled
## Emitted on every frame while a spell is being cast, with its charges.
signal cast_status(mana_radius: float, acceleration_speed: float, density: float)
## Emitted when the spell being cast is released: there is nothing to charge any more.
signal cast_ended

const RuneCatalog = preload("res://scripts/runes/rune_catalog.gd")
## The movement capsule reaches this far (metres) above the top of the head bone.
const BODY_TOP_MARGIN := 0.02
## Bones the movement capsule's bottom follows (its lowest point), and the one its top follows.
const BODY_FOOT_BONES: Array[String] = [
	"mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase",
	"mixamorig_RightToeBase", "mixamorig_LeftToe_End", "mixamorig_RightToe_End",
]
const BODY_HEAD_BONE := "mixamorig_HeadTop_End"

## The spell this character casts.
@export var spell_scene: PackedScene
## Health the character starts with, and the most it can have.
@export var max_health: float = 20.0
## Size of the mana reserve. Spells draw mana from it.
@export var max_mana: float = 20.0
## Mana per second the character passively absorbs from the ether around him (1 ether = 1 mana)
## while the reserve is not full. 0 turns it off.
@export var passive_absorb_rate: float = 0.5
## Height above the feet of the point the ether flows into.
@export var absorb_point_height: float = 1.0
@export var walk_speed: float = 5.5
@export var run_speed: float = 9.0
@export var jump_velocity: float = 4.8
@export var turn_speed: float = 4.0
## Seconds used to cross-fade between animations (idle, walk, run, jump).
@export var anim_blend_time: float = 0.2
## Bones whose midpoint is where spells are summoned (the thumb and index tips of the casting
## hand). The cast point follows it every frame, so the spell rides the fingertips.
@export var cast_bone_names: PackedStringArray = ["mixamorig_RightHandIndex4", "mixamorig_RightHandThumb4"]
## Fixed point on the body (character-local, about chest height) that spells are aimed from:
## their direction is from here toward the aimed-at point. It does not move with the
## animations, so the spell's point stays steady while the hand moves.
@export var aim_pivot: Vector3 = Vector3(0.0, 1.4, 0.0)

## Phases of the summoning animation: the mana_casting clip plays forward to its last pose,
## holds there while the rune is held, and plays backwards when it is released.
enum CastPhase { NONE, FORWARD, HOLD, REVERSE }
## Seconds before either end of the clip at which the forward / backward play counts as done.
const CAST_END_MARGIN := 0.03

@onready var _model_root: Node3D = $ModelRoot
@onready var cast_point: Node3D = $CastPoint
@onready var _body_shape: CollisionShape3D = $CollisionShape3D

## Health left. Starts full.
var health: float = 0.0
## True once the health reached 0. A dead character plays the death animation, stays on its last
## pose, and ignores every command (nothing revives it yet).
var is_dead: bool = false
## Mana left in the reserve. Starts full.
var mana: float = 0.0
## True while the character is summoning mana (Mana or Fire rune held on a spell being cast);
## plays the summoning animation.
var summoning: bool = false
## True while a spell is held and not yet released; idles in the spell stance.
var holding_spell: bool = false

## --- Intents: set by whoever controls this character ---
## Movement input like `Input.get_vector`: x is right, y is back (so (0, -1) walks forward).
var move_input: Vector2 = Vector2.ZERO
var sprint_input: bool = false
## Where the character aims: a callable taking the aim pivot (world position) and returning
## the unit direction to aim along. Unset: straight ahead, level with the ground.
var aim_provider: Callable = Callable()

var _jump_requested: bool = false
var _spell: RigidBody3D
var _holding_mana: bool = false
var _holding_fire: bool = false
var _holding_acceleration: bool = false
var _holding_density: bool = false

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
## The movement capsule, resized every physics frame to the pose (see `_fit_body_capsule`).
var _body_capsule: CapsuleShape3D
var _head_bone: int = -1
var _foot_bones: PackedInt32Array = PackedInt32Array()
## Height of the lowest foot bone (character-local) in the rest pose: where the feet are when
## the capsule's bottom is on the floor.
var _rest_feet_y: float = 0.0
var _cast_bones: PackedInt32Array = PackedInt32Array()
var _cast_phase: CastPhase = CastPhase.NONE
var _jumping: bool = false
var _death_started: bool = false
var _ether_field: Node
var _absorb_point: Node3D


# ----------------------------------------------------------------------------------------
# Intent API
# ----------------------------------------------------------------------------------------

## Asks for a jump on the next physics step (ignored when not standing on the floor).
func request_jump() -> void:
	if is_dead:
		return
	_jump_requested = true


## Turns the character around the vertical axis (radians, positive = to the left).
func turn(yaw: float) -> void:
	if is_dead:
		return
	rotate_y(yaw)


## A rune of the given id was pressed: starts what the rune does (summon, charge, shape...).
func rune_pressed(rune_id: String) -> void:
	if is_dead:
		return
	match rune_id:
		"mana":
			_begin_mana()
		"fire":
			_begin_fire()
		"acceleration":
			_begin_acceleration()
		"density":
			_begin_density()
		_:
			# Runes without their own held behaviour act by kind (tap).
			if RuneCatalog.kind(rune_id) == "shape":
				_apply_shape(RuneCatalog.shape_id(rune_id))


## A rune of the given id was let go.
func rune_released(rune_id: String) -> void:
	match rune_id:
		"mana":
			_holding_mana = false
		"fire":
			_holding_fire = false
		"acceleration":
			_holding_acceleration = false
		"density":
			_holding_density = false


## Lets go of every held rune without releasing the spell.
func release_holds() -> void:
	_holding_mana = false
	_holding_fire = false
	_holding_acceleration = false
	_holding_density = false


## Launches the spell being cast (nothing happens without one).
func release_spell() -> void:
	if is_dead or not _has_casting_spell():
		return
	release_holds()
	_spell.release()
	_spell = null
	cast_ended.emit()


# ----------------------------------------------------------------------------------------
# Health
# ----------------------------------------------------------------------------------------

## Takes health away (never below zero). Returns how much was actually lost.
func take_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var lost := minf(amount, health)
	if lost <= 0.0:
		return 0.0
	health -= lost
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
	return lost


## Gives health back, up to the maximum. Returns how much fit.
func heal(amount: float) -> float:
	if is_dead:
		return 0.0
	var gained := minf(amount, max_health - health)
	if gained <= 0.0:
		return 0.0
	health += gained
	health_changed.emit(health, max_health)
	return gained


## Health reached 0: the character dies. Whatever it was doing stops, and a spell it was holding
## vanishes (its mana is lost).
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	release_holds()
	if _has_casting_spell():
		_spell.queue_free()
		_spell = null
		cast_ended.emit()
	died.emit()

# ----------------------------------------------------------------------------------------
# Mana
# ----------------------------------------------------------------------------------------

## Takes up to `requested` mana from the reserve and returns how much was actually taken
## (less when the reserve runs low, zero when it is empty).
func draw_mana(requested: float) -> float:
	if requested <= 0.0:
		return 0.0
	var taken := minf(requested, mana)
	if taken <= 0.0:
		return 0.0
	mana -= taken
	if mana < 1e-7:
		mana = 0.0
	mana_changed.emit(mana, max_mana)
	return taken


## Puts mana into the reserve, up to the maximum. Returns how much fit.
func add_mana(amount: float) -> float:
	var added := minf(amount, max_mana - mana)
	if added <= 0.0:
		return 0.0
	mana += added
	mana_changed.emit(mana, max_mana)
	return added


## Passive absorption: draws ether (1 ether = 1 mana) from the nearest voxels and adds it
## to the reserve until it is full. The drained voxels stay empty.
func _absorb_ether(delta: float) -> void:
	if is_dead or passive_absorb_rate <= 0.0 or mana >= max_mana:
		return
	if _ether_field == null or not is_instance_valid(_ether_field):
		_ether_field = get_tree().get_first_node_in_group("ether_field")
		if _ether_field == null:
			return
	var wanted := minf(passive_absorb_rate * delta, max_mana - mana)
	var taken: float = _ether_field.draw_ether(_absorb_point, wanted)
	if taken > 0.0:
		add_mana(taken)


# ----------------------------------------------------------------------------------------
# Casting
# ----------------------------------------------------------------------------------------

## The spell being cast right now (not yet released), or null.
func get_casting_spell() -> RigidBody3D:
	return _spell if _has_casting_spell() else null


func _has_casting_spell() -> bool:
	return _spell != null and is_instance_valid(_spell) and _spell.is_casting()


## Makes sure there is a spell in Casting phase (summons a new one if needed).
func _ensure_casting_spell() -> bool:
	if _spell != null and is_instance_valid(_spell) and not _spell.is_casting():
		_spell = null

	if _spell == null or not is_instance_valid(_spell):
		if spell_scene == null or get_parent() == null:
			return false
		_spell = spell_scene.instantiate() as RigidBody3D
		# The spell is not a child of the character: it is held in front of the cast point (the
		# fingertips) and collides with the world by itself, so it can't push the character.
		get_parent().add_child(_spell)
		_spell.begin_casting(cast_point, self)
		# The spell's mana comes from this character's reserve, starting mana included;
		# with the reserve empty, no spell forms.
		_spell.mana_source = self
		if not _spell.draw_initial_mana():
			get_parent().remove_child(_spell)
			_spell.queue_free()
			_spell = null
			return false
		_emit_cast_status()

	return _spell.is_casting()


func _emit_cast_status() -> void:
	cast_status.emit(_spell.mana_radius, _spell.acceleration_speed, _spell.get_density())


func _begin_mana() -> void:
	if _holding_mana:
		return
	if not _ensure_casting_spell():
		return
	_holding_mana = true


func _begin_fire() -> void:
	if _holding_fire:
		return
	if not _ensure_casting_spell():
		return
	# Tapping sets the element; holding summons mana exactly like the mana rune.
	_spell.set_element("fire")
	_holding_fire = true


## Shape runes tap: they change the shape of the spell being cast (nothing without one).
func _apply_shape(shape_id: String) -> void:
	if not _has_casting_spell():
		return
	_spell.set_shape(shape_id)


func _begin_acceleration() -> void:
	if not _has_casting_spell():
		return
	if not _spell.begin_acceleration():
		# Not enough mana in the reserve for the minimum start: nothing happens.
		return
	_holding_acceleration = true
	_emit_cast_status()


func _begin_density() -> void:
	if not _has_casting_spell():
		return
	_holding_density = true
	_emit_cast_status()


## The spell being cast has failed: it dissolves, its mana is lost, and the character is left
## with nothing in hand.
func _fizzle_spell() -> void:
	release_holds()
	_spell.fizzle()
	_spell = null
	cast_ended.emit()
	spell_fizzled.emit()


## Feeds the held runes into the spell being cast.
func _charge_spell(delta: float) -> void:
	# Mana and Fire both summon mana; holding both together still grows only once.
	if _holding_mana or _holding_fire:
		_spell.grow_mana(delta)
	if _holding_acceleration:
		_spell.charge_acceleration(delta)
	if _holding_density:
		_spell.densify(delta)
	_emit_cast_status()


# ----------------------------------------------------------------------------------------
# Aim and cast point
# ----------------------------------------------------------------------------------------

## Unit direction from the aim pivot (a fixed point on the body, see `aim_pivot`) toward what
## the character aims at (see `aim_provider`). It does not depend on where the hands are, so
## arm animations never swing it.
func get_aim_direction() -> Vector3:
	return get_aim_direction_from(to_global(aim_pivot))


## Unit direction from any world point `from` toward what the character aims at.
func get_aim_direction_from(from: Vector3) -> Vector3:
	if aim_provider.is_valid():
		return aim_provider.call(from)
	var ahead := -global_transform.basis.z
	ahead.y = 0.0
	return ahead.normalized()


## Where the spell is summoned right now: the midpoint of the casting fingertips, read from
## the live pose (the cast point node is only updated after the skeleton finishes posing, one
## frame late). Falls back to the cast point when the bones are missing.
func get_cast_position() -> Vector3:
	if _cast_bones.is_empty():
		return cast_point.global_position
	var sum := Vector3.ZERO
	for bone in _cast_bones:
		sum += _skeleton.get_bone_global_pose(bone).origin
	return _skeleton.to_global(sum / _cast_bones.size())


# ----------------------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------------------

func _ready() -> void:
	health = max_health
	mana = max_mana
	# The ether flows into this point on the character's body (also the inflow motes' target).
	_absorb_point = Node3D.new()
	_absorb_point.name = "AbsorbPoint"
	_absorb_point.position = Vector3(0.0, absorb_point_height, 0.0)
	add_child(_absorb_point)
	_setup_character_model()


func _process(delta: float) -> void:
	_absorb_ether(delta)

	holding_spell = _has_casting_spell()
	summoning = holding_spell and (_holding_mana or _holding_fire)
	if holding_spell:
		_charge_spell(delta)


func _physics_process(delta: float) -> void:
	var sprinting := sprint_input and not is_dead
	var speed := run_speed if sprinting else walk_speed

	var forward := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z)
	var right := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z)
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()

	var input := Vector2.ZERO if is_dead else move_input
	var direction := right * input.x + forward * -input.y
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0
		_jumping = false
		if _jump_requested:
			velocity.y = jump_velocity
			_jumping = true
			_play_anim("jump")
	_jump_requested = false

	_fit_body_capsule()
	move_and_slide()
	_update_animation(direction, sprinting)


# ----------------------------------------------------------------------------------------
# Character model and animations
# ----------------------------------------------------------------------------------------

func _setup_character_model() -> void:
	# The character model is placed in character.tscn (so the editor shows it); load it only if missing.
	var character: Node3D = null
	if _model_root.get_child_count() > 0:
		character = _model_root.get_child(0) as Node3D
	if character == null:
		character = load("res://assets/models/character/walking.fbx").instantiate()
		_model_root.add_child(character)
	_anim = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _anim == null:
		push_error("Character model missing AnimationPlayer")
		return

	_install_animation_library(_anim)
	_anim.animation_finished.connect(_on_animation_finished)
	_play_idle()
	_setup_cast_point(character)
	if _skeleton != null:
		_setup_body_capsule()


## The movement capsule: its bottom follows the lowest foot and its top the head, so it shrinks
## and expands with the pose (curled up in the air, it is small). Its width stays the same.
func _setup_body_capsule() -> void:
	var capsule := _body_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	# Every character resizes its own capsule: the shape must not be shared by the instances.
	_body_capsule = capsule.duplicate() as CapsuleShape3D
	_body_shape.shape = _body_capsule
	_head_bone = _skeleton.find_bone(BODY_HEAD_BONE)
	for bone_name in BODY_FOOT_BONES:
		var bone := _skeleton.find_bone(bone_name)
		if bone >= 0:
			_foot_bones.append(bone)
	if _head_bone < 0 or _foot_bones.is_empty():
		push_warning("Head or foot bones not found; the movement capsule keeps its scene size")
		_head_bone = -1
		return
	_rest_feet_y = INF
	for bone in _foot_bones:
		var rest_point := _skeleton.get_bone_global_rest(bone).origin
		_rest_feet_y = minf(_rest_feet_y, to_local(_skeleton.to_global(rest_point)).y)
	_fit_body_capsule()


## Fits the movement capsule to the pose: bottom on the lowest foot (never below the character's
## origin), top on the head. A capsule is never shorter than a sphere of its radius.
func _fit_body_capsule() -> void:
	if _head_bone < 0:
		return
	var top := _bone_height(_head_bone) + BODY_TOP_MARGIN
	var lowest := INF
	for bone in _foot_bones:
		lowest = minf(lowest, _bone_height(bone))
	var bottom := maxf(lowest - _rest_feet_y, 0.0)
	var height := maxf(top - bottom, _body_capsule.radius * 2.0)
	_body_capsule.height = height
	_body_shape.position.y = bottom + height * 0.5


## Height of a bone above the character's origin, in the current pose.
func _bone_height(bone: int) -> float:
	var point := _skeleton.get_bone_global_pose(bone).origin
	return to_local(_skeleton.to_global(point)).y


## Makes the cast point node follow the fingertips (right after the skeleton has been posed).
## Its rotation stays that of the character. Spells use `get_cast_position()` and
## `get_aim_direction()` instead, which are exact on every frame.
func _setup_cast_point(character: Node) -> void:
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	for bone_name in cast_bone_names:
		var bone := _skeleton.find_bone(bone_name)
		if bone >= 0:
			_cast_bones.append(bone)
	if _cast_bones.is_empty():
		push_warning("Cast bones not found; the cast point keeps its scene position")
		return
	_skeleton.skeleton_updated.connect(_sync_cast_point)
	_skeleton.force_update_all_bone_transforms()
	_sync_cast_point()


func _sync_cast_point() -> void:
	if _cast_bones.is_empty():
		return
	var sum := Vector3.ZERO
	for bone in _cast_bones:
		sum += _skeleton.get_bone_global_pose(bone).origin
	cast_point.global_position = _skeleton.to_global(sum / _cast_bones.size())


func _install_animation_library(ap: AnimationPlayer) -> void:
	var sources := {
		"idle": "res://assets/models/character/idle.fbx",
		"walk": "res://assets/models/character/walking.fbx",
		"run": "res://assets/models/character/running.fbx",
		"jump": "res://assets/models/character/jumping.fbx",
		"cast": "res://assets/models/character/mana_casting.fbx",
		"spell_idle": "res://assets/models/character/spell_idle.fbx",
		"spell_walk": "res://assets/models/character/spell_walking.fbx",
		"spell_run": "res://assets/models/character/spell_running.fbx",
		"death": "res://assets/models/character/death.fbx",
	}

	var lib := AnimationLibrary.new()
	for anim_name in sources.keys():
		var packed: PackedScene = load(sources[anim_name])
		var temp: Node = packed.instantiate()
		var src_ap := temp.get_node("AnimationPlayer") as AnimationPlayer
		var src_anim := src_ap.get_animation("mixamo_com")
		if src_anim == null:
			# Fallback if naming differs.
			var list := src_ap.get_animation_list()
			if list.size() > 0:
				src_anim = src_ap.get_animation(list[0])
		if src_anim == null:
			temp.queue_free()
			continue

		var anim: Animation = src_anim.duplicate(true)
		if anim_name == "jump" or anim_name == "cast" or anim_name == "death":
			anim.loop_mode = Animation.LOOP_NONE
		else:
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(anim_name, anim)
		temp.queue_free()

	for existing in ap.get_animation_library_list():
		ap.remove_animation_library(existing)
	ap.add_animation_library("", lib)


func _update_animation(direction: Vector3, sprinting: bool) -> void:
	if _anim == null:
		return

	# Dead: the death animation plays once and the character stays on its last pose.
	if is_dead:
		if not _death_started and _anim.has_animation("death"):
			_death_started = true
			_cast_phase = CastPhase.NONE
			_play_anim("death")
		return

	if _jumping or not is_on_floor():
		_cast_phase = CastPhase.NONE
		if _anim.current_animation != "jump":
			_play_anim("jump")
		return

	# Drawing mana: the summoning pose takes over from idle / walk / run while it lasts,
	# and while it plays back to the start after the rune is released.
	if _update_cast():
		return

	if direction.length_squared() > 0.0001:
		var move_anim := "run" if sprinting else "walk"
		# Holding an unreleased spell: the same moves in the spell stance.
		if holding_spell and _anim.has_animation("spell_" + move_anim):
			move_anim = "spell_" + move_anim
		_play_anim(move_anim)
	else:
		_play_idle()


## Drives the summoning animation. Returns true while it controls the character's pose
## (so idle / walk / run must not play), false once the character is back at the start pose.
##  - rune held: the clip plays forward to its last frame and stays there;
##  - rune released: the same clip plays backwards from wherever it is, down to its first frame.
## Pressing the rune again while it is reversing turns it around from the current pose.
func _update_cast() -> bool:
	if not _anim.has_animation("cast"):
		return false
	# Something else (e.g. jump) took over the character: forget the summoning phase.
	if _cast_phase != CastPhase.NONE and _anim.assigned_animation != "cast":
		_cast_phase = CastPhase.NONE
	var length := _anim.get_animation("cast").length

	if summoning:
		match _cast_phase:
			CastPhase.NONE:
				_anim.speed_scale = 1.0
				_anim.play("cast", anim_blend_time)
				_cast_phase = CastPhase.FORWARD
			CastPhase.REVERSE:
				_play_cast_from(_anim.current_animation_position, 1.0)
				_cast_phase = CastPhase.FORWARD
			CastPhase.FORWARD:
				if _anim.current_animation_position >= length - CAST_END_MARGIN or not _anim.is_playing():
					_play_cast_from(length, 1.0)
					_anim.pause()
					_cast_phase = CastPhase.HOLD
		return true

	match _cast_phase:
		CastPhase.FORWARD, CastPhase.HOLD:
			var from := length if _cast_phase == CastPhase.HOLD else _anim.current_animation_position
			_play_cast_from(from, -1.0)
			_cast_phase = CastPhase.REVERSE
			return true
		CastPhase.REVERSE:
			if _anim.current_animation_position <= CAST_END_MARGIN or not _anim.is_playing():
				_cast_phase = CastPhase.NONE
				return false
			return true
	return false


## Plays the cast clip from `position` at `speed` (negative = backwards), without cross-fade.
func _play_cast_from(position: float, speed: float) -> void:
	_anim.speed_scale = 1.0
	if speed < 0.0 and position >= _anim.get_animation("cast").length:
		# Backwards from the very last frame: seeking there stops a non-looping clip.
		_anim.play("cast", 0.0, speed, true)
		return
	_anim.play("cast", 0.0, speed)
	_anim.seek(position, true)


func _play_anim(anim_name: String) -> void:
	if _anim == null:
		return
	if not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name and _anim.is_playing():
		_anim.speed_scale = 1.0
		return
	_anim.speed_scale = 1.0
	_anim.play(anim_name, anim_blend_time)


func _play_idle() -> void:
	if _anim == null:
		return
	# Holding an unreleased spell: a ready stance instead of the plain idle.
	if holding_spell and _anim.has_animation("spell_idle"):
		_play_anim("spell_idle")
		return
	if _anim.has_animation("idle"):
		_play_anim("idle")
		return
	# Fallback if the idle clip is missing: hold the start of the walk pose.
	if _anim.current_animation != "walk":
		_anim.play("walk")
	_anim.speed_scale = 0.0
	_anim.seek(0.0, true)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"jump" and is_on_floor():
		_jumping = false
