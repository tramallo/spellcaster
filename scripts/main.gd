extends Node3D

const RUNE_ACTIONS := [
	"rune_slot_0",
	"rune_slot_1",
	"rune_slot_2",
	"rune_slot_3",
]

@export var spell_scene: PackedScene

@onready var _cast_point: Node3D = $Player/CastPoint
@onready var _rune_bar: Control = $HUD/RuneBar
@onready var _inventory: Control = $HUD/Inventory

var _spell: RigidBody3D
var _holding_mana: bool = false
var _holding_acceleration: bool = false


func _ready() -> void:
	_rune_bar.reset_charges()
	_inventory.opened.connect(_on_inventory_opened)
	_inventory.closed.connect(_on_inventory_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_inventory.toggle()
		get_viewport().set_input_as_handled()
		return

	if _inventory.is_open():
		return

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

	if event.is_action_pressed("release_spell"):
		# Only release while playing with captured cursor (not the click that re-captures).
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_release_spell()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _inventory.is_open():
		return
	if _spell == null or not is_instance_valid(_spell) or not _spell.is_casting():
		return

	if _holding_mana:
		_spell.grow_mana(delta)

	if _holding_acceleration:
		_spell.charge_acceleration(delta)

	_rune_bar.update_acceleration(_spell.acceleration_speed)


func _on_inventory_opened() -> void:
	_holding_mana = false
	_holding_acceleration = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_closed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_rune_pressed(slot_index: int) -> void:
	var slot: Node = _rune_bar.get_slot(slot_index)
	var rune_id: String = slot.rune_id
	if rune_id.is_empty():
		return

	_rune_bar.set_slot_pressed(slot_index, true)

	match rune_id:
		"mana":
			_begin_mana()
		"acceleration":
			_begin_acceleration()


func _on_rune_released(slot_index: int) -> void:
	var slot: Node = _rune_bar.get_slot(slot_index)
	var rune_id: String = slot.rune_id
	_rune_bar.set_slot_pressed(slot_index, false)

	match rune_id:
		"mana":
			_holding_mana = false
		"acceleration":
			_holding_acceleration = false
			if _spell != null and is_instance_valid(_spell) and _spell.is_casting():
				_rune_bar.update_acceleration(_spell.acceleration_speed)


func _begin_mana() -> void:
	if _holding_mana:
		return

	if _spell != null and is_instance_valid(_spell) and not _spell.is_casting():
		_spell = null

	if _spell == null or not is_instance_valid(_spell):
		if spell_scene == null:
			return
		_spell = spell_scene.instantiate() as RigidBody3D
		_cast_point.add_child(_spell)
		_spell.position = Vector3.ZERO
		_rune_bar.update_acceleration(0.0)

	if not _spell.is_casting():
		return

	_holding_mana = true


func _begin_acceleration() -> void:
	if _spell == null or not is_instance_valid(_spell):
		return
	if not _spell.is_casting():
		return
	_spell.begin_acceleration()
	_rune_bar.update_acceleration(_spell.acceleration_speed)
	_holding_acceleration = true


func _release_spell() -> void:
	if _spell == null or not is_instance_valid(_spell):
		return
	if not _spell.is_casting():
		return

	_holding_mana = false
	_holding_acceleration = false

	var global_xform: Transform3D = _spell.global_transform
	_cast_point.remove_child(_spell)
	add_child(_spell)
	_spell.global_transform = global_xform
	_spell.release()
	_spell = null
	_rune_bar.reset_charges()
