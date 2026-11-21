extends Object


const RUNES := {
	"mana": {"name": "Mana", "glyph": "◇"},
	"acceleration": {"name": "Accelerate", "glyph": "≫"},
}


static func has_id(rune_id: String) -> bool:
	return RUNES.has(rune_id)


static func display_name(rune_id: String) -> String:
	if not RUNES.has(rune_id):
		return ""
	return str(RUNES[rune_id]["name"])


static func glyph(rune_id: String) -> String:
	if not RUNES.has(rune_id):
		return "·"
	return str(RUNES[rune_id]["glyph"])
