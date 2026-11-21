extends Control

@onready var _slots: Array[Node] = [%Slot0, %Slot1, %Slot2, %Slot3]
@onready var _board: PanelContainer = %Board


func _ready() -> void:
	add_to_group("rune_bar")
	# Board must not steal clicks from slots.
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _board.find_children("*", "Control", true, false):
		if child != _board and not child.is_in_group("rune_slots"):
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_wood_theme()
	var keys := ["Q", "E", "R", "T"]
	var start_runes := ["mana", "acceleration", "", ""]
	for i in _slots.size():
		var slot: Node = _slots[i]
		slot.slot_kind = "hotbar"
		slot.slot_index = i
		slot.add_to_group("rune_slots")
		slot.setup(keys[i], start_runes[i])
		slot.set_drag_enabled(false)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


func get_slot(index: int) -> Node:
	return _slots[index]


func find_slot_by_rune(rune_id: String) -> Node:
	for slot in _slots:
		if slot.rune_id == rune_id:
			return slot
	return null


func set_slot_pressed(index: int, pressed: bool) -> void:
	_slots[index].set_pressed(pressed)


func update_acceleration(speed: float) -> void:
	var slot := find_slot_by_rune("acceleration")
	if slot != null:
		slot.set_charge(speed)


func reset_charges() -> void:
	var slot := find_slot_by_rune("acceleration")
	if slot != null:
		slot.set_charge(0.0)
	for s in _slots:
		s.set_pressed(false)


func set_drag_enabled(enabled: bool) -> void:
	for slot in _slots:
		slot.set_drag_enabled(enabled)


func _apply_wood_theme() -> void:
	var board_style := StyleBoxFlat.new()
	board_style.bg_color = Color(0.28, 0.16, 0.08, 0.94)
	board_style.border_color = Color(0.72, 0.52, 0.22, 1.0)
	board_style.set_border_width_all(1)
	board_style.set_corner_radius_all(5)
	board_style.shadow_color = Color(0, 0, 0, 0.35)
	board_style.shadow_size = 3
	board_style.shadow_offset = Vector2(0, 1)
	board_style.content_margin_left = 6
	board_style.content_margin_right = 6
	board_style.content_margin_top = 4
	board_style.content_margin_bottom = 4
	_board.add_theme_stylebox_override("panel", board_style)

	var inset := StyleBoxFlat.new()
	inset.bg_color = Color(0.14, 0.08, 0.04, 0.92)
	inset.border_color = Color(0.55, 0.38, 0.16, 1.0)
	inset.set_border_width_all(1)
	inset.set_corner_radius_all(4)
	inset.content_margin_left = 2
	inset.content_margin_right = 2
	inset.content_margin_top = 2
	inset.content_margin_bottom = 2

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	bar_bg.set_corner_radius_all(2)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.85, 0.55, 0.18, 1.0)
	bar_fill.set_corner_radius_all(2)

	for slot in _slots:
		slot.add_theme_stylebox_override("panel", inset.duplicate())
		var charge: ProgressBar = slot.get_node("%ChargeBar")
		charge.add_theme_stylebox_override("background", bar_bg.duplicate())
		charge.add_theme_stylebox_override("fill", bar_fill.duplicate())
