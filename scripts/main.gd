extends Node3D
## The test arena. Sets up the local player's HUD: the health and mana reserve bars, the crosshair, and the
## hotbar and inventory, which the player's controller is connected to.

const MANA_POOL_BAR := preload("res://scripts/hud/mana_pool_bar.gd")
const HEALTH_BAR := preload("res://scripts/hud/health_bar.gd")
const CROSSHAIR := preload("res://scripts/hud/crosshair.gd")

@onready var _player: CharacterBody3D = $Player
@onready var _rune_bar: Control = $HUD/RuneBar
@onready var _inventory: Control = $HUD/Inventory

var _health_bar: Control
var _mana_bar: Control
var _crosshair: Control


func _ready() -> void:
	# Red health bar under the hotbar, following the player's health.
	_health_bar = HEALTH_BAR.new()
	$HUD.add_child(_health_bar)
	_player.health_changed.connect(_health_bar.set_pool)
	_health_bar.set_pool(_player.health, _player.max_health)

	# Mana reserve bar under the hotbar, following the player's reserve.
	_mana_bar = MANA_POOL_BAR.new()
	$HUD.add_child(_mana_bar)
	_player.mana_changed.connect(_mana_bar.set_pool)
	_mana_bar.set_pool(_player.mana, _player.max_mana)

	_crosshair = CROSSHAIR.new()
	$HUD.add_child(_crosshair)

	_rune_bar.reset_charges()
	_inventory.opened.connect(_crosshair.hide)
	_inventory.closed.connect(_crosshair.show)

	# The controller turns the player's keyboard and mouse into commands for the character.
	$Player/Controller.setup(_rune_bar, _inventory)