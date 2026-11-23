# Game world

How the world of Spellcaster is built physically. The design rules (spells, runes, mana) are in
`spellcrafting-system-plan.md`.

## Collision layers

Godot 3D physics layers. The names are also set in Project Settings > Layer Names > 3D Physics,
and the constants are in `scripts/physics_layers.gd`.

| # | Name | Bit value | What is on it |
|---|------|-----------|---------------|
| 1 | `physics` | 1 | The solid world: the floor and props, and every character's **movement capsule**. |
| 2 | `magic` | 2 | Every spell, and every character's **hurtboxes** (the parts of the body spells hit). |

Who collides with whom (a layer's *mask* is the list of layers a thing looks at):

| Thing | Layer | Mask | Meaning |
|-------|-------|------|---------|
| Floor / props | `physics` | - | Static, anything on `physics` collides with them. |
| Character movement capsule | `physics` | `physics` | Walks on the floor, stops at props and at other characters. Spells never touch it. |
| Hurtbox (an `Area3D` per body part) | `magic` | `magic` | Detects spells entering it and tells the spell which character it touched. |
| Spell (held) | none | none | No collision at all while it is held in the hand. |
| Spell (released) | `magic` | `magic` | Collides only with other spells. It falls through the floor (the 1000 m guard removes it) and flies through characters' bodies; it hurts through the hurtboxes. |
| Camera arm, crosshair aim ray | - | `physics` | The aim hits the world and the characters' movement capsules, not the hurtboxes. |

## Characters: two kinds of collider

- **Movement capsule** (`CollisionShape3D` on the `CharacterBody3D`, layer `physics`). It is what
  walks and collides with the floor. It keeps its width (radius 0.3) but its height follows the
  pose every physics frame: the **bottom follows the lowest foot** bone (never below the
  character's origin) and the **top follows the head** (top of the head bone). A character curled
  up in the air has a short capsule. It is never shorter than a sphere of its radius. Every
  character has its own capsule resource.
- **Hurtboxes** (10 `Area3D`, layer `magic`, script `scripts/hurtbox.gd`): real nodes of
  `scenes/character.tscn`, each inside a `BoneAttachment3D` under the model's `Skeleton3D`
  (the model is set to "Editable Children"), so they follow the animation and you can see and
  adjust each one in the editor. All parts count the same: there is no extra damage for a part
  (no headshots), they only give an exact hit area.

| Part | Shape | Bones |
|------|-------|-------|
| Head | sphere, r 0.11 | centre between Head and HeadTop_End |
| Chest (with neck) | capsule, r 0.17 | Spine to Head |
| Arms (2) | capsule, r 0.06 | Arm to ForeArm |
| Forearms (2, with hands) | capsule, r 0.05 | ForeArm to HandMiddle4 |
| Legs (2) | capsule, r 0.09 | UpLeg to Leg |
| Shins (2, with feet) | capsule, r 0.07 | Leg to ToeBase |

## Spells and hits

- A spell hurts a character when it enters one of that character's hurtboxes (`hit_character`);
  it hurts only once and disappears 0.5 s after.
- A released spell is moved forward along its launch direction, just far enough to be clear of its
  caster's hurtboxes, before it gets its collision, so it does not hit its own caster as it leaves
  the hand. After that the caster's hurtboxes count like any other: a caster who does not throw
  the spell away and gets hit by it has only himself to blame (by design, no special rule).
- Hurtbox detection is discrete (it checks once per physics step): a spell faster than about
  its own size per physics step can pass through a thin part.
