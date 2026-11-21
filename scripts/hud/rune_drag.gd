extends Control

## Shared drag state for hotbar <-> inventory rune moves.

var _source: Node = null
var _payload: Dictionary = {}
var _ghost: Control = null


func _ready() -> void:
	add_to_group("rune_drag")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_dragging() -> bool:
	return _source != null


func begin_drag(slot: Node) -> void:
	if slot == null or slot.rune_id.is_empty():
		return
	cancel_drag()

	_source = slot
	_payload = {
		"rune_id": slot.rune_id,
		"source_kind": slot.slot_kind,
		"source_index": slot.slot_index,
	}

	_ghost = PanelContainer.new()
	_ghost.custom_minimum_size = Vector2(48, 52)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.12, 0.06, 0.92)
	style.border_color = Color(0.85, 0.65, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_ghost.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "%s\n%s" % [_glyph(slot.rune_id), _display_name(slot.rune_id)]
	_ghost.add_child(label)
	add_child(_ghost)
	_update_ghost_pos()


func cancel_drag() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_source = null
	_payload.clear()


func _process(_delta: float) -> void:
	if _ghost != null:
		_update_ghost_pos()


func _input(event: InputEvent) -> void:
	if _source == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drop()
		get_viewport().set_input_as_handled()


func _finish_drop() -> void:
	var target := _find_slot_under_mouse()
	if target != null and target != _source:
		var outgoing: String = target.rune_id
		var incoming: String = str(_payload.get("rune_id", ""))
		target.set_rune(incoming)
		_source.set_rune(outgoing)
	cancel_drag()


func _find_slot_under_mouse() -> Node:
	var mouse := get_viewport().get_mouse_position()
	for node in get_tree().get_nodes_in_group("rune_slots"):
		if not node is Control:
			continue
		if not node.drag_enabled:
			continue
		var rect := (node as Control).get_global_rect()
		if rect.has_point(mouse):
			return node
	return null


func _update_ghost_pos() -> void:
	if _ghost == null:
		return
	_ghost.global_position = get_viewport().get_mouse_position() - Vector2(24, 26)


func _glyph(rune_id: String) -> String:
	const Catalog = preload("res://scripts/runes/rune_catalog.gd")
	return Catalog.glyph(rune_id)


func _display_name(rune_id: String) -> String:
	const Catalog = preload("res://scripts/runes/rune_catalog.gd")
	return Catalog.display_name(rune_id)
