extends Control

signal opened
signal closed

const INV_SLOT_COUNT := 16

@onready var _panel: PanelContainer = %Panel
@onready var _grid: GridContainer = %Grid

var _slots: Array[Node] = []
var _is_open: bool = false


func _ready() -> void:
	add_to_group("inventory_ui")
	# Let the hotbar receive input above the dimmed area.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	_apply_wood_theme()
	set_open(false)


func is_open() -> bool:
	return _is_open


func set_open(open: bool) -> void:
	_is_open = open
	visible = open
	_set_inventory_draggable(open)

	var rune_bar := get_tree().get_first_node_in_group("rune_bar")
	if rune_bar != null and rune_bar.has_method("set_drag_enabled"):
		rune_bar.set_drag_enabled(open)

	if open:
		opened.emit()
	else:
		closed.emit()


func toggle() -> void:
	set_open(not _is_open)


func _build_slots() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_slots.clear()

	var slot_scene: PackedScene = preload("res://scenes/hud/rune_slot.tscn")
	for i in INV_SLOT_COUNT:
		var slot: Node = slot_scene.instantiate()
		_grid.add_child(slot)
		slot.slot_kind = "inventory"
		slot.slot_index = i
		slot.add_to_group("rune_slots")
		# Fire starts in the first inventory slot; drag it to the hotbar to use it.
		slot.setup("", "fire" if i == 0 else "")
		slot.set_drag_enabled(false)
		_slots.append(slot)


func _set_inventory_draggable(enabled: bool) -> void:
	for slot in _slots:
		slot.set_drag_enabled(enabled)


func _apply_wood_theme() -> void:
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.28, 0.16, 0.08, 0.96)
	board_style.border_color = Color(0.72, 0.52, 0.22, 1.0)
	board_style.set_border_width_all(3)
	board_style.set_corner_radius_all(10)
	board_style.shadow_color = Color(0, 0, 0, 0.5)
	board_style.shadow_size = 10
	board_style.shadow_offset = Vector2(0, 4)
	board_style.content_margin_left = 16
	board_style.content_margin_right = 16
	board_style.content_margin_top = 14
	board_style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", board_style)

	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.14, 0.08, 0.04, 0.92)
	inset.border_color = Color(0.55, 0.38, 0.16, 1.0)
	inset.set_border_width_all(1)
	inset.set_corner_radius_all(5)

	for slot in _slots:
		slot.add_theme_stylebox_override("panel", inset.duplicate())
