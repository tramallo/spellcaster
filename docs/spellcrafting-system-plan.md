# Spellcrafting system --- Current plan

The specification is divided into four sections:

-   **Decided:** Confirmed rules. These cannot be changed unless
    explicitly requested.
-   **Assumed:** Provisional principles. These can be changed, but must
    not conflict with decided rules.
-   **Deferred:** Points intentionally postponed. They are not open
    questions; they will be addressed later.
-   **Open questions:** Unresolved points that need clarification.

**Scope:** this document records design decisions. Balance values, each
rune's own behavior, and development or testing setup are not decisions
here; they live in the code and in the rune definitions and can change
at any time. Implementation specifications live in their own files:
`game_world.md` (the physical world: collision layers, characters,
hurtboxes, ether field, health, the training dummy) and `runes.md`
(what each rune does and costs).

Currently, there are **47 decisions, 17 assumptions, 8
deferred items, and no open questions**.

## 1. Decided

### Spell lifecycle and phases

| ID   | Decision |
|------|----------|
| D-12 | A spell has a lifecycle with phases. For now there are two: **Casting** and **Release**. The number of phases is not final; more may be added later. |
| D-21 | The player enters **Release** with a dedicated input (key binding not decided). Release commits the spell into the world as a free object and activates all modifiers whose effects apply on the Release phase. |
| D-32 | Once Release has started, the spell is committed. Casting for that spell is over. |
| D-37 | The player may have only one spell under construction at a time. |
| D-38 | During Casting, the spell stays in front of the caster/camera (current prototype placement). World-anchoring may be revisited later. |

### Mana summon and failure

| ID   | Decision |
|------|----------|
| D-26 | To create a spell, the player must **summon mana** (draw it from their mana pool). A successful summon is enough to start Casting; there is no larger minimum threshold. |
| D-34 | Summoning mana makes the spell visible and invests into it. By default, more summoned mana makes the spell bigger, up to a size limit (see D-54). |
| D-35 | Mana can be summoned at any time during Casting (including after runes have been applied), until Release. The player may finalize size at the end if desired. |
| D-68 | A spell fails when the player's mana pool cannot pay what a rune asks of it, no matter what or how mana is being consumed. Mana is never paid in part: whatever the pool cannot cover makes the spell fail. When a spell fails, the mana invested in it is lost (it is not returned to the player's pool). |

### Elements and runes

| ID   | Decision |
|------|----------|
| D-01 | There will be elements that can be used in spells. |
| D-02 | Players create spells by activating **runes**: elemental runes and modifier runes ("rune" is a working name, see A-13). |
| D-09 | A spell may have at most one element. Having no element is valid: the spell is **pure mana**. |
| D-13 | An elemental rune sets or replaces the spell's current element. It does not complete the spell and does not start Release. |
| D-17 | A spell with no shape modifiers manifests as a sphere (elemental or pure mana). A released spell with no movement modifier simply falls under gravity (gravity applies to every spell, see A-21). |
| D-40 | The only minimum for a spell to exist is that it has some mana. Once it exists, the player may apply any runes (elemental or modifier), in any order and any number of times. Whether a spell has modifiers, and how many, is the player's choice. |

### Spell modifiers (runes)

| ID   | Decision |
|------|----------|
| D-03 | Spell modifiers may have drawbacks of their own, defined by each rune. A rune may have none. |
| D-04 | A spell without shape modifications manifests as a sphere. |
| D-05 | Modifiers can affect different aspects of a spell, such as shape, size, movement, etc. |
| D-06 | When a rune has drawbacks, they should ideally relate to the property being modified. |
| D-07 | Modifiers can interact with other modifiers. |
| D-08 | Modifiers may be divided into categories, such as shape, movement, temporal, interaction, etc. |
| D-10 | Every spell starts from a default manifestation before modifiers are applied (a mana sphere after summon). |
| D-11 | Modifiers alter specific properties or behaviors of a spell. |
| D-14 | Each modifier operates on the current state of the spell when activated. It does not need to know which modifiers were previously activated. |
| D-15 | The same modifier can be activated multiple times in one spell. |
| D-16 | Modifiers can have opposite or partially opposite effects. |
| D-20 | Each rune defines its own input behavior (for example tap or hold). By default, if unspecified, treat it as tap/immediate. |
| D-23 | Modifiers can affect properties that previous modifiers have already changed. |
| D-24 | Modifiers cannot reset the spell to a previous state. Each modifier operates on the state received from the previous modifier, or the base state if it is first. |
| D-36 | A rune's mana cost counts as a drawback (see D-03), but it does not limit its other drawbacks. Each rune defines whether it has mana drawbacks, practical drawbacks, both, or none. |
| D-41 | Each modifier defines **when** its effect applies: during **Casting** (immediate) and/or during **Release** (deferred). Example: a shape change may apply in Casting; acceleration may apply in Release. Deferred effects apply in the order their runes were activated. |
| D-42 | Holding a rune, or locking its held value, never enters Release by itself; Release is a separate action (D-21). What each rune does when held or locked is defined by that rune. |
| D-69 | Each rune's behavior is independent from the others: a rune may have no drawbacks, only drawbacks, or any mix. Runes are created and balanced individually by the developers. Runes do not block each other (shape changes are runes too). |
| D-70 | Each rune defines whether it needs an existing spell (with mana) in order to work. Most do; some may not. |
| D-71 | A shape rune sets the spell's shape. Shape is a property that is set, not transformed: the last shape rune used decides the shape, so shape runes replace each other rather than stack. |

### Ether and resources

Terms: *ether* is the substance in the environment; *mana* is the substance in the player's pool and invested in spells (see A-13).

| ID   | Decision |
|------|----------|
| D-19 | Whether a rune costs mana, and how and when it is paid, is defined by each rune. A rune may cost nothing. |
| D-27 | A spell's mana cost comes from its runes. Each rune defines its own cost, if any: a fixed amount, an amount calculated from the mana invested, or a value calculated from other factors. Costs are paid from the player's mana pool. (Cost handling was simplified: there is no sequential cost calculation.) |
| D-28 | The player has a personal mana pool (also called reserve). Runes that cost mana take it from this pool. Runes never draw ether from the environment directly; the player does. |
| D-29 | The player naturally absorbs ether from the surroundings, converts it to mana and stores it in their pool, at a certain pace and radius around their position, until the pool is full. |
| D-31 | Absorbing ether depletes the ether of the place it comes from. Each place slowly recovers its ether over time. |

### Absorption and spell mechanics

D-45 overrides the radius in D-29 for now.

| ID   | Decision |
|------|----------|
| D-44 | Summoning mana takes mana from the player's mana pool (reserve), not directly from the environment. Mana a spell takes is never returned (see D-68); the pool refills only by absorbing ether (D-29). |
| D-45 | When the player absorbs ether, it is taken from the nearest voxel that still holds ether (distance to the closest point of the voxel), with unlimited reach for now. When that voxel is empty it moves on to the next nearest. |
| D-54 | Past a certain spell size, newly summoned mana increases the spell's density instead of its size, so spells do not grow too massive by default. The transition is gradual, not abrupt. The size threshold and the shape of the transition are balance values. |
| D-55 | Shapes are convex polyhedra whose corners lie on the unit sphere, scaled by the spell's radius, so a shaped spell always fits inside the sphere it replaces. This simplifies things: mana, size and density rules are unchanged by shape. A spell's density is defined by its mana relative to its radius, not by the real volumetric density of its shape; the two may differ. |
| D-57 | After launch, every spell keeps its front toward its direction of travel (dart-like, no tumbling) while it moves above a small speed threshold; below it, it is a normal physics body. A shaped spell's collision is the shape itself. |
| D-63 | A released spell that touches an entity that can take damage hurts it once, then disappears after a short delay; in that time it stays a normal physics body and deals no more damage. A spell that is still held hurts nobody. The caster can be hurt by its own released spell. How much damage a spell deals is a balance configuration, and its formula is not final. |
| D-64 | A character whose health reaches 0 dies. It plays the death animation once (immediately, also in mid-air) and stays on its last pose. It ignores every command (move, jump, turn, runes, release), cannot heal, and nothing revives it yet. Its passive ether absorption stops the moment it dies. A spell it was holding vanishes with its mana. Its body stays solid: spells hit it and the crosshair aims at it, and a hit does no damage because its health is already 0. |

## 2. Assumed

These are working principles, not permanent rules.

| ID   | Assumption |
|------|------------|
| A-01 | Initial elements will be Fire, Earth, Air and Water. |
| A-02 | Modifiers can have different levels of power, with stronger modifiers generally having stronger drawbacks (where they have drawbacks, see D-03 and D-69). |
| A-03 | Spell properties can include damage, area, range, speed, duration, density and mana cost. |
| A-05 | Players should be able to discover unexpected spell combinations through experimentation. |
| A-07 | A modifier's drawback, if it has one, is intrinsic to that modifier. |
| A-08 | Every spell has a set of properties that can be evaluated. |
| A-10 | There is no limit to the number of modifiers that can be activated in one spell. |
| A-11 | Modifiers do not require other modifiers to be activated first. |
| A-12 | Ideally, there should be no incompatible modifier combinations. Players should be able to combine anything and discover the resulting behavior. |
| A-13 | Terminology is provisional. "Rune" is a working name for the elements and modifiers the player activates. "Ether" is the substance in the environment; "mana" is the substance in the player's pool (also called reserve) and invested in spells. The real names are not decided. |
| A-14 | Players can carry only a limited number of runes at a time (limited slots), because a game with too many buttons is not fun. The number of slots is not decided. |
| A-15 | The ether in the environment is provisionally stored as a grid of small voxels, each holding a fixed amount of ether. This representation is for development and may change. |
| A-16 | Environmental ether is shown in the world as floating motes, and motes from a drained voxel fly to the player while absorbing. The presentation is provisional. |
| A-17 | The player's mana pool is shown on the HUD (currently a bar with a number). The presentation is provisional. |
| A-18 | Passive absorption works at a pace that is provisional and will be balanced while the game develops. |
| A-19 | Characters have health that damage reduces. Its value and display are provisional and will be decided later. |
| A-21 | A spell's mass equals its mana (1 to 1), and spells are pulled by gravity at a reduced rate (currently half the world's). This may be modified later. |

**Note:** A-04, A-06, A-09 and A-20 were intentionally removed and have
not been reintroduced. (Collision layers and who hits whom are defined
in `game_world.md`.)

## 3. Current casting process

Based on the decided rules, the lifecycle is:

### Before casting

The player's mana pool fills over time by passively absorbing ether
from the environment (D-29). Runes that cost mana spend it from this
pool.

### Casting

1.  **Summon mana.** The player draws mana from their pool. As soon as
    the spell has some mana, a spell construct appears (default:
    sphere) and Casting is active. Only one construct at a time.
2.  **Optionally summon more mana** at any time during Casting. The
    spell grows in size up to a limit; beyond it, extra mana makes the
    spell denser.
3.  **Activate runes** in any order and any number of times:
    -   **Elemental rune:** sets or replaces the element (or leave pure
        mana if none was chosen).
    -   **Modifier rune:** applies according to its own definition
        (tap/hold input; Casting and/or Release application; mana cost,
        if any; whether it needs an existing spell).
4.  **Hold-runes:** behavior is defined by each rune. Holding or locking
    a value never enters Release.
5.  **Immediate (Casting) modifiers** change the construct as soon as
    they apply (e.g. shape: a shape rune sets the spell's shape,
    replacing the previous one, D-71).
6.  **Deferred (Release) modifiers** store their chosen parameters
    during Casting but do not fire yet.
7.  **Failure.** If the player's mana pool cannot pay what a rune asks,
    the spell fails and the mana invested in it is lost (D-68).

### Release

8.  **The player enters Release.** The spell becomes a free world
    object. Deferred modifier effects activate in the order their runes
    were activated. If nothing provides movement, the spell falls under
    gravity.
9.  Casting for that spell ends.

Cancel is not part of the current design (see Deferred).

## 4. Core design principles

These are the implications of the current specification:

-   Spells are built in **Casting** and committed in **Release**.
-   **Mana summon** creates the construct and drives default size;
    element does not complete the spell.
-   **Pure mana** spells are valid. The only minimum for a spell is that
    it has some mana.
-   Runes transform spell state; each rune defines its own input
    (tap/hold), application phase (Casting and/or Release), mana cost
    (if any) and drawbacks (if any).
-   Each rune is independent from the others; runes do not block each
    other.
-   A modifier doesn't need to know what came before it.
-   Shape is set, not transformed: a shape rune decides the shape and
    replaces any previous one (D-71).
-   Modifiers can affect properties already modified by previous
    modifiers.
-   Opposing modifiers are allowed; their effects can counteract or
    partially counteract each other.
-   The system should favor emergent combinations rather than predefined
    spell recipes.
-   Ether is the limiting resource: the player absorbs it from the
    environment into a mana pool, and runes spend mana from that pool.
    Runes never draw ether from the environment directly.
-   A spell fails when the pool cannot pay what a rune asks, and its
    invested mana is lost.
-   Mana cost counts as a drawback of a rune, but a rune can also have
    other, practical drawbacks, or none.

## 5. Deferred

These points were intentionally postponed. They are not open questions.

-   **Density:** what density does, and what advantages and
    disadvantages it has, like any other property.
-   **Fixed-size feedback:** how the player perceives invested mana when
    a modifier fixes the spell's size (presentation only).
-   **Interruptions:** whether and how Casting or Release can be
    interrupted (for example by damage or stuns).
-   **Cancel:** the ability to cancel a spell under construction. It is
    not part of the current design and will be implemented later.
-   **Additional lifecycle phases:** only Casting and Release for now;
    the final number of phases is not decided.
-   **Key bindings:** not decided; under development and subject to
    change at any time.
-   **Camera:** not decided; for now it stays over the shoulder.
-   **Number of rune slots:** see A-14.

## 6. Open questions

None currently.

------------------------------------------------------------------------

This is the current baseline. Future changes should preserve the
distinction between decided rules and assumptions, and every change
should trigger a review of potentially affected assumptions.
