extends Area3D
## One part of a character's body that spells can hit (head, chest, an arm...). The parts are
## nodes of `scenes/character.tscn`, each inside a BoneAttachment3D of the model's skeleton, so
## it follows the animation. Its layer and mask (`magic`) are set in the scene.
##
## When a spell enters it, the spell is told which character it touched (`hit_character`); the
## spell decides what that means. All the parts count the same: there is no per-part damage.

## The character this part belongs to: the CharacterBody3D above it in the scene.
var character: Node


func _ready() -> void:
	var node := get_parent()
	while node != null and not node is CharacterBody3D:
		node = node.get_parent()
	character = node
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if character != null and is_instance_valid(character) and body.has_method("hit_character"):
		body.hit_character(character)
