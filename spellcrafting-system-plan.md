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

**Superseded by lifecycle rewrite (no longer in force):** the old rules that calling an element started ether draw / completed the spell, and that stopping ether draw launched the spell. See D-12, D-13, D-21, D-26, D-34, D-35.

### Casting and gameplay

| ID   | Decision |
|------|----------|
| D-18 | The player can cancel during Casting (before Release). Cancel behavior exists in the design but is not required in the prototype yet (see Deferred). |
| D-22 | There are no separate attack or defense actions. Spells perform those functions. The player can cast while moving. |
| D-25 | Cancelling a spell removes the construct and all activated runes for that spell. Details of resource recovery once ether is wired are deferred. |

**Removed from force pending ether rewiring:** D-30, D-33 (ether-draw failure / drain-while-drawing tied to the old element-final flow).

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
