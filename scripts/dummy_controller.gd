extends Node
## Behavior of the training dummy: a controller like the player's, but it is a script instead of
## a keyboard. It drives the character it is attached to (its parent) through the same intent
## API (rune presses, release), so the dummy casts exactly like the player does.
##
## It repeats, for as long as it has the mana: summon a spell with `spell_mana` mana, charge its
## acceleration up to `spell_speed`, turn it into a spike, and release it. It never aims: the
## spell leaves in a straight line in front of him.

@export var spell_mana: float = 3.0
@export var spell_speed: float = 1.0
## Mana from the reserve that each 1 of speed costs (the spell's mana_per_acceleration).
@export var mana_per_speed: float = 0.25
@export var shape_rune: String = "spike"

enum Step { WAIT_MANA, SUMMON, ACCELERATE, SHAPE }

var _character: CharacterBody3D
var _step: Step = Step.WAIT_MANA
var _shape_timer: float = 0.0


func _ready() -> void:
	_character = get_parent() as CharacterBody3D
	if _character == null:
		push_error("DummyController must be a child of a character")
		set_process(false)
		return
	# A dead dummy stops throwing.
	_character.died.connect(set_process.bind(false))


func _process(delta: float) -> void:
	if _step == Step.WAIT_MANA:
		_try_to_start()
		return

	var spell: RigidBody3D = _character.get_casting_spell()
	if spell == null:
		# The spell is gone (never formed, or released by something else): start over.
		_character.release_holds()
		_step = Step.WAIT_MANA
		return

	match _step:
		Step.SUMMON:
			# Hold the mana rune until the spell has all its mana.
			if spell.mana_radius >= spell_mana:
				_character.rune_released("mana")
				_character.rune_pressed("acceleration")
				_step = Step.ACCELERATE
		Step.ACCELERATE:
			# Hold the acceleration rune until the spell reaches its speed.
			if spell.acceleration_speed >= spell_speed:
				_character.rune_released("acceleration")
				_character.rune_pressed(shape_rune)
				_shape_timer = spell.shape_morph_time
				_step = Step.SHAPE
		Step.SHAPE:
			# Let the spell finish turning into the shape, then throw it.
			_shape_timer -= delta
			if _shape_timer <= 0.0:
				_character.release_spell()
				_step = Step.WAIT_MANA


## Starts the next spell when the reserve holds the mana for it and for its speed (both come
## from the reserve), otherwise waits.
func _try_to_start() -> void:
	if _character.mana < spell_mana + spell_speed * mana_per_speed:
		return
	_character.rune_pressed("mana")
	if _character.get_casting_spell() != null:
		_step = Step.SUMMON