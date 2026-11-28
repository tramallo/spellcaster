# Game world

How the world of Spellcaster is built physically: collisions, characters, the ether field, health
and the training dummy. These are implementation specifications, not design decisions, and can
change at any time. The design rules (spells, runes, mana) are in `spellcrafting-system-plan.md`,
and what each rune does is in `runes.md`.

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
- **Damage** = the spell's mana + its acceleration speed x `damage_per_acceleration` (1, so every
  point of speed is a point of damage). Density, shape and element do not count yet.
- A spell that hurts a character disappears 0.5 s later (`despawn_delay_after_hit`); meanwhile it
  is a normal physics body and deals no more damage. A held spell hurts nobody.
- Touching anything that cannot take damage (anything without `take_damage`: other spells) does
  nothing: the spell stays.
- **Aim while casting:** the spell's front points along the line from a fixed pivot on the
  caster's body (`aim_pivot`, about chest height) to the point under the crosshair (the first
  world surface along the camera ray, or the far sky). The pivot does not move with animations,
  so the direction stays steady while the hand moves. The spell is held at the live fingertips (no
  frame lag) and its direction is independent of its position, so collision push-outs never turn
  it. On release the spell turns to aim from where it actually is (the hand is off the pivot's
  line, so the pivot's direction alone would pass beside the target), takes that as its launch
  direction and starts from rest (it does not inherit the speed of the hand); its acceleration
  speed then throws it along that direction in that same instant, and afterwards it follows its
  own modifiers and physics (gravity still bends it).
- **World limit:** any spell farther than 1000 m from the centre of the world (0, 0, 0), in any
  direction, disappears (`max_distance_from_center`). Spells fall through the floor, so this is
  what removes them.

## Characters

- The player and the training dummy are instances of the same character scene
  (`scenes/character.tscn`): body, model, animations, mana pool (with ether absorption), health
  and casting. A character has no input of its own: whatever drives it does so through an intent
  API (move, sprint, jump, turn, aim, rune pressed/released, release spell), so every character
  behaves the same. This prepares multiplayer: a remote character would be driven by network
  commands instead. Structure only for now, no networking nodes.
- The player's controller (`scenes/player_controller.tscn`, a child of the character) turns
  keyboard and mouse into those commands and owns the camera, the crosshair aim and the link to
  the HUD. The dummy has no player controller: a script controller drives it instead.
- **Health:** `max_health` is 20. `take_damage` and `heal` change it, never below 0 or above the
  maximum. The player's health is shown as a red bar under the mana bar (`health_bar.gd`).
  Reaching 0 is death, as the plan defines it.
- **Mana pool:** `max_mana` is 20 and a character starts with it full. It is shown for the
  player as a small bar with a number ("14.3 / 20") under the hotbar. Spells pay from it (see
  `runes.md`).

### Training dummy

`scripts/dummy_controller.gd` uses the same intent API as the player. It summons a spell with 3
mana (Mana rune), adds 1 speed (Acceleration rune), turns it into a spike (Spike rune, after the
0.3 s morph) and releases it, then starts the next one right away. Each throw costs 3.25 mana from
its pool, and it waits until the pool holds that much (ether absorption refills it). It never
aims: the spell leaves straight ahead of it, level, and gravity applies as to any spell. The
dummy faces away from the player's start, so its spells fly away from him. A dead dummy stops
throwing.

## Ether field

The environment's ether (`scripts/ether/ether_field.gd`). Only the characters' passive absorption
takes from it; spells never touch it.

- It is stored as voxels of 0.5 m (`voxel_size`), up to 4 m above the floor (`ether_height`),
  over the ground area. Currently that is one half of the floor (the +Z half; the border is
  blocky). 1 ether = 1 mana. Each full voxel holds a fixed amount set directly
  (`ether_per_voxel`, 0.003); there is no volume-to-mana conversion.
- **Passive absorption:** while its pool is not full, a character absorbs ether at 0.5 ether per
  second (`passive_absorb_rate`), converting it to mana. It takes it from the nearest voxel that
  still holds ether (distance to the closest point of the voxel), with unlimited reach; when
  that voxel is empty it moves on to the next nearest. In the empty half it pulls from the
  nearest ether, far away. Absorption stops when the pool is full, and when the character dies.
- Drained voxels stay empty: ether does not recover yet. A character that moves while absorbing
  keeps drawing from whichever voxel is nearest, so walking while absorbing empties a trail of
  voxels along the path.
- **Display:** ether is shown as violet motes floating in the air over the ether area. A mote
  dims with the ether left in its voxel and disappears when the voxel is drained. Violet inflow
  motes fly from a drained voxel to the character that absorbed it. An alternative display
  (`show_bars`, off by default) draws each voxel as a see-through cube whose height is its ether
  amount.
