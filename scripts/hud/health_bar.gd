extends "res://scripts/hud/mana_pool_bar.gd"
## Red bar under the mana bar showing the player's health ("20.0 / 20"). It is the mana
## bar's widget with its own colour and place; feed it with `set_pool(current, maximum)`.


func _init() -> void:
	fill_color = Color(0.86, 0.13, 0.13, 1.0)
	top_offset = 98.0