extends PanelContainer

const RuneCatalog = preload("res://scripts/runes/rune_catalog.gd")

signal content_changed

@onready var _key_label: Label = %KeyLabel
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _charge_bar: ProgressBar = %ChargeBar
@onready var _glyph: Label = %GlyphLabel
@onready var _active_glow: ColorRect = %ActiveGlow

## "hotbar" or "inventory"
var slot_kind: String = "hotbar"
var slot_index: int = 0
var key_text: String = ""
var rune_id: String = ""
var drag_enabled: bool = false

var _pressed: bool = false


func _ready() -> void:
	_ignore_mouse_on_children(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_gui_input)


func setup(p_key_text: String, id: String, _display_name: String = "", _glyph: String = "") -> void:
	key_text = p_key_text
	if not is_node_ready():
		call_deferred("setup", p_key_text, id, _display_name, _glyph)
		return
	set_rune(id)


func set_rune(id: String) -> void:
	if not is_node_ready():
		call_deferred("set_rune", id)
		return

	rune_id = id
	var filled := not id.is_empty() and RuneCatalog.has_id(id)
	if not filled:
		rune_id = ""

	_key_label.text = key_text
	_key_label.visible = not key_text.is_empty()

	if rune_id.is_empty():
		_name_label.text = "Empty"
		_name_label.modulate = Color(0.55, 0.42, 0.28, 0.7)
		_glyph.text = "·"
		_glyph.modulate = Color(0.35, 0.25, 0.15, 0.55)
		_charge_bar.visible = false
		_value_label.visible = false
	else:
		_name_label.text = RuneCatalog.display_name(rune_id)
		_name_label.modulate = Color(0.92, 0.78, 0.48, 1.0)
		_glyph.text = RuneCatalog.glyph(rune_id)
		_glyph.modulate = Color(0.95, 0.82, 0.45, 1.0)
		var shows_charge := rune_id == "acceleration" or rune_id == "density"
		_charge_bar.visible = shows_charge
		if shows_charge:
			set_charge(1.0 if rune_id == "density" else 0.0)
		elif rune_id == "mana" or rune_id == "fire":
			set_mana(0.0)
		else:
			_value_label.visible = false
			set_charge(0.0)

	set_pressed(false)
	content_changed.emit()


func clear_rune() -> void:
	set_rune("")


func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled
	_ignore_mouse_on_children(self)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_pressed(pressed: bool) -> void:
	_pressed = pressed
	if _active_glow == null:
		return
	_active_glow.visible = pressed and not rune_id.is_empty()
	modulate = Color(1.15, 1.05, 0.9, 1.0) if pressed else Color.WHITE


## Shows the accumulated mana amount (in radius units) on the mana rune.
func set_mana(amount: float) -> void:
	if _value_label == null:
		return
	if rune_id != "mana" and rune_id != "fire":
		return
	# Only the hotbar shows the live amount; inventory copies stay clean.
	_value_label.visible = slot_kind == "hotbar"
	_value_label.text = "%.3f" % amount


func set_charge(value: float) -> void:
	if _charge_bar == null:
		return
	if rune_id != "acceleration" and rune_id != "density":
		_value_label.visible = false
		return
	_value_label.visible = value > 0.0 or _pressed or rune_id == "density"
	_value_label.text = "%.1f" % value
	_charge_bar.max_value = 1.0
	if rune_id == "density":
		# 1 = natural; fill grows as density rises.
		_charge_bar.value = 1.0 - (1.0 / maxf(value, 1.0))
	else:
		_charge_bar.value = value / (value + 10.0)


func _on_gui_input(event: InputEvent) -> void:
	if not drag_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if rune_id.is_empty():
			return
		var drag := _drag_controller()
		if drag != null:
			drag.begin_drag(self)
			accept_event()


func _drag_controller() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("rune_drag")


func _ignore_mouse_on_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child != self:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_on_children(child)
