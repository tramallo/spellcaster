extends Control
## Small bar under the hotbar showing the player's mana reserve ("14.3 / 20").

@export var bar_size: Vector2 = Vector2(220.0, 16.0)
@export var top_offset: float = 76.0
@export var fill_color: Color = Color(0.55, 0.82, 1.0, 1.0)

var _bar: ProgressBar
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -bar_size.x * 0.5
	offset_right = bar_size.x * 0.5
	offset_top = top_offset
	offset_bottom = top_offset + bar_size.y

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	bg.border_color = Color(0.72, 0.52, 0.22, 1.0)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)


func set_pool(current: float, maximum: float) -> void:
	if _bar == null:
		return
	_bar.value = clampf(current / maxf(maximum, 0.0001), 0.0, 1.0)
	_label.text = "%.1f / %s" % [current, str(snappedf(maximum, 0.1))]
