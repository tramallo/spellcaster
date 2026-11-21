# Spellcrafting system --- Current plan

The specification is divided into four sections:

-   **Decided:** Confirmed rules. These cannot be changed unless
    explicitly requested.
-   **Assumed:** Provisional principles. These can be changed, but must
    not conflict with decided rules.
-   **Deferred:** Points intentionally postponed. They are not open
    questions; they will be addressed later.
-   **Open questions:** Unresolved points that need clarification.

Currently, there are **40 decisions, 9 assumptions, 6 deferred items,
and no open questions**.

## 1. Decided

### Spell lifecycle and phases

| ID   | Decision |
|------|----------|
| D-12 | A spell has a lifecycle with phases. For now there are exactly two: **Casting** and **Release**. More phases may be added later. |
| D-21 | The player enters **Release** by pressing Space. Release commits the spell into the world as a free object and activates all modifiers whose effects apply on the Release phase. |
| D-32 | Once Release has started, the spell is committed. Casting for that spell is over. |
| D-37 | The player may have only one spell under construction at a time. |
| D-38 | During Casting, the spell stays in front of the caster/camera (current prototype placement). World-anchoring may be revisited later. |

### Mana summon and visibility

| ID   | Decision |
|------|----------|
| D-26 | To create a spell, the player must **summon mana**. A successful summon is enough to start Casting; there is no larger minimum threshold. |
| D-34 | Summoning mana makes the spell visible and invests into it. By default, more summoned mana makes the spell bigger. |
| D-35 | Mana can be summoned at any time during Casting (including after runes have been applied), until Release. The player may finalize size at the end if desired. |
| D-39 | Until ether is reconnected to gameplay, mana investment is unlimited for development and testing. |

### Elements and runes

| ID   | Decision |
|------|----------|
| D-01 | There will be elements that can be used in spells. |
| D-02 | Players create spells by activating **runes**: elemental runes and modifier runes. |
| D-09 | A spell may have at most one element. Having no element is valid: the spell is **pure mana**. |
| D-13 | An elemental rune sets or replaces the spell's current element. Calling an element does not complete the spell and does not start Release. |
| D-17 | A spell with no shape modifiers manifests as a sphere (elemental or pure mana). On Release, if no deferred movement modifier applies, the spell falls under gravity. |
| D-40 | After a successful mana summon, the player may apply elemental runes and modifier runes in any order. |

### Spell modifiers (runes)

| ID   | Decision |
|------|----------|
| D-03 | Spell modifiers have their own drawbacks. |
| D-04 | A spell without shape modifications manifests as a sphere. |
| D-05 | Modifiers can affect different aspects of a spell, such as shape, size, movement, etc. |
| D-06 | Drawbacks should ideally relate to the property being modified. |
| D-07 | Modifiers can interact with other modifiers. |
| D-08 | Modifiers may be divided into categories, such as shape, movement, temporal, interaction, etc. |
| D-10 | Every spell starts from a default manifestation before modifiers are applied (a mana sphere after summon). |
| D-11 | Modifiers alter specific properties or behaviors of a spell. |
| D-14 | Each modifier operates on the current state of the spell when activated. It does not need to know which modifiers were previously activated. |
| D-15 | The same modifier can be activated multiple times in one spell. |
| D-16 | Modifiers can have opposite or partially opposite effects. |
| D-20 | Each rune defines its own input behavior. Some are **tap** (apply once). Some are **hold** (player holds to select a value). By default, if unspecified, treat as tap/immediate. |
| D-23 | Modifiers can affect properties that previous modifiers have already changed. |
| D-24 | Modifiers cannot reset the spell to a previous state. Each modifier operates on the state received from the previous modifier, or the base state if it is first. |
| D-36 | A modifier's ether cost counts as a drawback (see D-03), but it does not limit its other drawbacks. Each modifier defines whether it has ether drawbacks, practical drawbacks, or both. |
| D-41 | Each modifier defines **when** its effect applies: during **Casting** (immediate) and/or during **Release** (deferred). Example: a shape change may apply in Casting; acceleration may apply in Release. |
| D-42 | For hold-to-set-value runes (e.g. acceleration): while held, the player selects the value; on key release the value is locked. The player may then continue Casting (more runes / more mana) or enter Release. Locking the value does not itself enter Release. |

### Ether and resources

Ether remains part of the design. Its connection to the new lifecycle (when cost is paid, failure cases, etc.) is deferred while spell behavior is developed. The following still hold as resource-world rules:

| ID   | Decision |
|------|----------|
| D-19 | Modifiers do not consume ether merely by being activated as runes during Casting. How and when ether is ultimately spent relative to summon/Release is deferred (see Deferred). |
| D-27 | The spell's total ether cost is a spell property. Each modifier defines how it changes that cost: a fixed extra cost, a value calculated from invested mana/ether, or a value calculated from other factors. Modifiers are applied sequentially, so their effect on cost is also sequential and order matters. |
| D-28 | The player has a personal ether pool. Spells draw ether from it. |
| D-29 | The player naturally absorbs ether from the surroundings into their pool, at a certain pace and radius around their position, until the pool is full. |
| D-31 | Absorbing ether depletes the ether of the place it comes from. Each place slowly recovers its ether over time. |

**Ether drawing (prototype, supersedes D-28 / D-29 for now; D-31 partly):**

| ID   | Decision |
|------|----------|
| D-43 | Ether is stored as voxels of 0.5 m, up to 4 m above the floor, over the ground area (currently one half of the floor; the region border is blocky). 1 ether = 1 mana (`mana_radius`). Each full voxel holds a fixed amount of ether set directly (`ether_per_voxel`, currently 0.003); there is no volume-to-mana conversion. |
| D-44 | Summoning mana takes mana from the player's mana reserve, not from the ether around the spell. Fire takes it the same way, since it summons mana like the Mana rune. The reserve (max 20 mana) starts full; mana a spell takes is never returned, and the reserve only refills by passive absorption (D-53). |
| D-45 | (Ether draw, not used by spells while the reserve is active.) A spell draws from the nearest voxel that still holds ether (distance to the closest point of the voxel), with unlimited reach. When that voxel is empty it moves on to the next nearest. Inflow motes fly from the drained voxel to the spell. |
| D-46 | Summon speed is scaled by the mana left in the reserve: full speed while it covers the request, proportionally less when the last mana cannot cover it, zero when the reserve is empty. (The same rule applied to the voxel ether draw.) |
| D-47 | Drained ether does not recover yet (recovery per D-31 is deferred). |
| D-48 | The spell's starting mana is also paid from the reserve. With the reserve empty, no spell forms; with little left, the spell starts smaller. |
| D-49 | Drained voxels stay empty. A spell that moves while summoning keeps drawing from whichever voxel is nearest, so walking and summoning empties a trail of voxels along the path. |
| D-50 | Ether is shown as violet motes floating in the air over the ether area: a mote dims with the ether left in its voxel and disappears when the voxel is drained. Motes from a drained voxel fly to the spell while it draws. An alternative display (`show_bars`, off by default) draws each voxel as a see-through cube whose height is its ether amount. |
| D-51 | A spell's size comes from its mana: at density 1, 1 mana makes a 0.5 m radius (`radius_per_mana`, tunable). Density divides that natural radius to get the actual size, and adding mana adds size at the same rate. |
| D-52 | The player's mana reserve is shown as a small bar with a number ("14.3 / 20") under the hotbar. Only the Mana and Fire runes use the reserve; acceleration and density cost no mana. The ether field stays in the world as visuals only for now (motes and air tint; nothing drains it). |
| D-53 | While the reserve is not full, the player passively absorbs ether from the ether field into it, at 0.5 ether per second (`passive_absorb_rate`), 1 ether = 1 mana. He takes it from the nearest voxels with unlimited reach (D-45 rules), so absorbing empties voxels permanently. Violet inflow motes fly from the drained voxel to the player. In the empty half he pulls from the nearest ether, far away. Absorption stops when the reserve is full. |
| D-54 | Soft size limit while summoning: new mana goes partly to size and partly to density. The size share is 1 for small spells and fades smoothly (smoothstep) to 0 across a band centred on 0.5 mana (`size_limit_mana`), 0.125 to 0.875 by default (`size_limit_softness` = 0.375, half the band). Size therefore stops at 0.25 m radius, 0.5 m diameter (0.5 mana of size) and every extra mana raises density instead (density = mana / 0.25 m x 0.5, i.e. twice the mana, since the radius no longer grows). The Density rune still compresses on top of this, unchanged. |
| D-55 | Shape runes (kind "shape" in the rune catalog) change the shape of the spell being cast; they tap (apply once) and do nothing without a spell in Casting. Shapes are convex polyhedra whose corners lie on a unit sphere, scaled by the spell's radius, so a shaped spell fits inside the sphere it replaces and mana, size and density rules stay as they are. |
| D-56 | The Spike rune (hotbar slot T, glyph △) turns the spell into a 3-sided pyramid (regular tetrahedron) whose point faces the front of the spell (the crosshair aim). The change is a smooth 0.3 s morph from the sphere (`shape_morph_time`). Using Spike again on a pyramid does nothing: modifiers never reset a spell to an earlier state (D-24). The pyramid's flat base sits on the caster's fingertips. |
| D-57 | After launch, a shaped spell keeps its point toward its direction of travel (dart-like, no tumbling) while it moves faster than 0.5 m/s; it is a normal physics body when slower. A shaped spell's collision is the shape itself (a sphere during the morph). |
| D-58 | While casting, the spell's front points along the line from a fixed pivot on the caster's body (about chest height, `aim_pivot`) to the point under the crosshair (first world surface along the camera ray, or the far sky). The pivot does not move with animations, so the spell's direction stays steady while the hand moves; the spell is held at the live fingertips (no frame lag) and its direction is independent of its position, so collision push-outs never turn it. On release the spell turns to aim from where it actually is (the hand is off the pivot's line, so the pivot's direction alone would pass beside the target) and takes that direction as its launch direction, starting from rest (it does not inherit the speed of the hand's movement); its acceleration speed then throws it along that fixed direction in that same instant, and afterwards the spell follows its own modifiers and physics (gravity still bends it). |
| D-59 | The player and the training dummy are instances of the same character scene (`scenes/character.tscn`): body, model, animations, mana reserve (with ether absorption) and casting. A character has no input of its own; whatever drives it does so through an intent API (move, sprint, jump, turn, aim, rune pressed/released, release spell), so every character behaves identically. The player's controller (`scenes/player_controller.tscn`, a child of the character) turns keyboard and mouse into those commands and owns the camera, crosshair aim and the link to the HUD; the dummy has no player controller (it is driven by a script controller instead, D-62). This prepares multiplayer: a remote character would be driven by network commands instead. Structure only for now, no networking nodes. |
| D-60 | Collisions stay flat for now: everything hits everything. Characters (layer 2), the world and spells collide with each other and the crosshair aim hits characters too. The only exception is that a spell ignores its own caster's body while it is held (the hand is inside it). Fine tuning is deferred. |
| D-61 | Every character has health (`max_health`, 20 to start), shown for the player as a red bar under the mana bar (HUD, `health_bar.gd`). `take_damage` and `heal` change it, never below 0 or above the maximum. Nothing deals damage yet, and reaching 0 has no effect yet. |
| D-62 | The training dummy is driven by a script controller (`dummy_controller.gd`, a child of the dummy) that uses the same intent API as the player: it summons a spell with 3 mana (Mana rune), adds 1 speed to it (Acceleration rune, paid from its reserve, so each throw costs 4 mana), turns it into a spike (Spike rune, after the 0.3 s morph) and releases it, then starts the next one right away, for as long as its reserve holds the mana for both (it waits otherwise; ether absorption refills it). It never aims: the spell leaves straight ahead of it, level, and gravity applies as to any spell. The dummy faces away from the player's start, so its spells fly away from him. |
| D-63 | Damage: a released spell that touches an entity that can take damage (anything with `take_damage`: characters now) hurts it once and disappears 0.5 s later (`despawn_delay_after_hit`); in that time it stays a normal physics body and deals no more damage. Damage = the spell's mana + its acceleration speed x `damage_per_acceleration` (1 for now, so every point of speed is a point of damage); other modifiers (density, shape, element) do not count yet. A spell that is still held hurts nobody. Everything hits everything: the caster is hurt by its own released spell too. Touching anything that cannot take damage (floor, props, other spells) does nothing: the spell stays. Fine tuning is deferred. |
| D-64 | Death: a character whose health reaches 0 dies (every character, the dummy included). It plays the death animation once (immediately, also in mid-air) and stays on its last pose. It ignores every command (move, jump, turn, runes, release), cannot heal, and nothing revives it yet. Its passive ether absorption stops the moment it dies. A spell it was holding vanishes with its mana. Its body stays solid: spells hit it and the crosshair aims at it, and a hit does no damage because its health is already 0. A dead dummy stops throwing. |
| D-65 | Guard: any spell that gets farther than 1000 m from the centre of the world (0, 0, 0), in any direction, disappears (`max_distance_from_center`). |
| D-66 | A spell's mass is its mana, 1 to 1 (1 mana = 1 mass), from the moment it forms and as it grows; density and size do not change it. Every spell, fire included, is pulled by half the world's gravity (`spell_gravity_scale` = 0.5). Gravity acceleration itself does not depend on mass (no air drag for now); mass matters for impacts. |
| D-67 | The Acceleration rune is paid with mana from the player's reserve (the same one summoning uses), not from the spell: every 1 of acceleration speed costs 1 mana (`mana_per_acceleration`). It starts at a minimum of 0.1 speed (paying 0.1 mana) when first pressed and then grows 0.8 per second while held (so it costs 0.8 mana per second, and 1 speed takes about 1.1 s), then locks as before. The spell's own mana, size, density and mass are not touched by accelerating, so they only depend on the mana summoned. If the reserve cannot pay the 0.1 minimum, pressing the rune does nothing; if it runs low while held, the speed grows more slowly and stops when the reserve is empty (like summoning). On release the spell gets its full acceleration speed instantly, as a kick along its aim (no ramp); gravity and collisions then decide the rest. A spell can no longer fizzle from accelerating (the fizzle mechanism stays in the code but nothing triggers it for now). |

## 2. Assumed

These are working principles, not permanent rules.

| ID   | Assumption |
|------|------------|
| A-01 | Initial elements will be Fire, Earth, Air and Water. |
| A-02 | Modifiers can have different levels of power, with stronger modifiers generally having stronger drawbacks. |
| A-03 | Spell properties can include damage, area, range, speed, duration, density and ether consumption. |
| A-05 | Players should be able to discover unexpected spell combinations through experimentation. |
| A-07 | A modifier's drawback is intrinsic to that modifier. |
| A-08 | Every spell has a set of properties that can be evaluated. |
| A-10 | There is no limit to the number of modifiers that can be activated in one spell. |
| A-11 | Modifiers do not require other modifiers to be activated first. |
| A-12 | Ideally, there should be no incompatible modifier combinations. Players should be able to combine anything and discover the resulting behavior. |

**Note:** A-04, A-06 and A-09 were intentionally removed and have not
been reintroduced.

## 3. Current casting process

Based on the decided rules, the lifecycle is:

### Casting

1.  **Summon mana.** The player summons mana (prototype: hold/use the
    summon control). On success, a spell construct appears (default:
    sphere) and Casting is active. Only one construct at a time.
2.  **Optionally summon more mana** at any time during Casting to invest
    more and grow the spell (unlimited while ether is ignored).
3.  **Activate runes** in any order:
    -   **Elemental rune:** sets or replaces the element (or leave pure
        mana if none was chosen).
    -   **Modifier rune:** applies according to its definition
        (tap/hold input; Casting and/or Release application).
4.  **Hold-runes:** hold to select a value; key-up locks the value.
    Casting continues afterward unless the player enters Release.
5.  **Immediate (Casting) modifiers** change the construct as soon as
    they apply (e.g. shape).
6.  **Deferred (Release) modifiers** store their chosen parameters
    during Casting (e.g. acceleration speed) but do not fire yet.

### Release

7.  **Press Space.** The spell enters Release: it becomes a free world
    object. Deferred modifier effects activate. If nothing provides
    movement, the spell falls under gravity.
8.  Casting for that spell ends.

Cancel is allowed by design during Casting, but is not part of the
current prototype scope.

Ether absorption into the player's pool (D-28, D-29, D-31) remains
planned; spending/limits are ignored until reconnected.

## 4. Core design principles

These are the implications of the current specification:

-   Spells are built in **Casting** and committed in **Release**.
-   **Mana summon** creates the construct and drives default size;
    element does not complete the spell.
-   **Pure mana** spells are valid.
-   Runes transform spell state; each rune defines input (tap/hold) and
    application phase (Casting and/or Release).
-   A modifier doesn't need to know what came before it.
-   Modifiers can affect properties already modified by previous
    modifiers.
-   Opposing modifiers are allowed; their effects can counteract or
    partially counteract each other.
-   The system should favor emergent combinations rather than predefined
    spell recipes.
-   Ether remains the long-term limiting resource, but spell behavior is
    developed first without enforcing ether spend.
-   Ether cost counts as a drawback of a modifier, but a modifier can
    also have other, practical drawbacks.

## 5. Deferred

These points were intentionally postponed. They are not open questions.

-   **Density:** what density does, and what advantages and
    disadvantages it has, like any other property.
-   **Fixed-size feedback:** how the player perceives invested mana/ether
    when a modifier fixes the spell's size (presentation only).
-   **Interruptions:** whether and how Casting or Release can be
    interrupted (for example by damage or stuns).
-   **Ether spend wiring:** when ether is paid relative to mana summon,
    runes, and Release; lump costs; empty-pool failure (old D-30 / D-33
    territory under the new lifecycle).
-   **Cancel implementation:** cancel is decided for Casting (D-18,
    D-25) but not required in the prototype yet.
-   **Additional lifecycle phases:** only Casting and Release for now.

## 6. Open questions

None currently.

------------------------------------------------------------------------

This is the current baseline. Future changes should preserve the
distinction between decided rules and assumptions, and every change
should trigger a review of potentially affected assumptions.
