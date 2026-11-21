extends Object

## Every rune has a name, a glyph and a `kind` saying what it does to a spell:
##  - "summon":  puts mana into the spell (held)
##  - "movement": changes how the spell moves on Release
##  - "density":  compresses the spell
##  - "shape":    changes the spell's shape (`shape` = id in ShapeCatalog)
const RUNES := {
	"mana": {"name": "Mana", "glyph": "◇", "kind": "summon"},
	"fire": {"name": "Fire", "glyph": "▲", "kind": "summon"},
	"acceleration": {"name": "Accelerate", "glyph": "≫", "kind": "movement"},
	"density": {"name": "Density", "glyph": "◉", "kind": "density"},
	"spike": {"name": "Spike", "glyph": "△", "kind": "shape", "shape": "pyramid"},
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


## What the rune does ("summon", "movement", "density", "shape"); "" for an unknown rune.
static func kind(rune_id: String) -> String:
	if not RUNES.has(rune_id):
		return ""
	return str(RUNES[rune_id]["kind"])


## The shape a "shape" rune turns the spell into ("" for other runes).
static func shape_id(rune_id: String) -> String:
	if not RUNES.has(rune_id):
		return ""
	return str(RUNES[rune_id].get("shape", ""))
