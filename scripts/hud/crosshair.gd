extends Control
## Tiny aiming cross at the centre of the view. Spells are aimed at what it points to.

## Length of each of the four arms, in pixels.
@export var arm_length: float = 3.0
## Empty space between the centre and the start of each arm, in pixels.
@export var gap: float = 2.0
@export var thickness: float = 1.0
@export var color: Color = Color(1, 1, 1, 0.9)
## Dark edge around the arms so the cross stays visible on bright and dark backgrounds.
@export var outline_color: Color = Color(0, 0, 0, 0.6)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var center := (size * 0.5).round()
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from: Vector2 = center + direction * gap
		var to: Vector2 = center + direction * (gap + arm_length)
		draw_line(from, to, outline_color, thickness + 2.0)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var from: Vector2 = center + direction * gap
		var to: Vector2 = center + direction * (gap + arm_length)
		draw_line(from, to, color, thickness)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
