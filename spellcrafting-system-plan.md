# Spellcrafting system --- Current plan

The specification is divided into four sections:

-   **Decided:** Confirmed rules. These cannot be changed unless
    explicitly requested.
-   **Assumed:** Provisional principles. These can be changed, but must
    not conflict with decided rules.
-   **Deferred:** Points intentionally postponed. They are not open
    questions; they will be addressed later.
-   **Open questions:** Unresolved points that need clarification.

Currently, there are **36 decisions, 9 assumptions, 3 deferred items,
and no open questions**.

## 1. Decided

### Elements and spell creation

| ID   | Decision |
|------|----------|
| D-01 | There will be elements that can be used in spells. |
| D-02 | Players create spells by combining different spell modifiers. |
| D-09 | Every spell has a base element. |
| D-12 | Spells are created and cast simultaneously. Players activate/call each desired modifier, followed by an element, which starts the final phase of casting. The spell manifests when the player stops drawing ether (see D-13, D-26). |
| D-13 | A spell can contain only one element. Calling the element starts the final phase: ether begins to be drawn from the player's pool. The spell launches/manifests when the player stops drawing. |
| D-17 | Calling an element without modifiers produces a static elemental sphere. By default, its initial size depends on the amount of ether invested (see D-35). It falls under gravity immediately once manifested. |
| D-21 | A spell only manifests after its element is called and the player stops drawing ether. All modifiers have already been activated at that point. |
| D-26 | When calling the element, the player decides how much ether to invest in it by how long they keep drawing. By default, this determines the initial elemental sphere's size (see D-35). |

### Spell modifiers

| ID   | Decision |
|------|----------|
| D-03 | Spell modifiers have their own drawbacks. |
| D-04 | A spell without shape modifications manifests as a sphere. |
| D-05 | Modifiers can affect different aspects of a spell, such as shape, size, movement, etc. |
| D-06 | Drawbacks should ideally relate to the property being modified. |
| D-07 | Modifiers can interact with other modifiers. |
| D-08 | Modifiers may be divided into categories, such as shape, movement, temporal, interaction, etc. |
| D-10 | Every spell starts from a default manifestation before modifiers are applied. |
| D-11 | Modifiers alter specific properties or behaviors of a spell. |
| D-14 | Each modifier operates on the current state of the spell when activated. It does not need to know which modifiers were previously activated. |
| D-15 | The same modifier can be activated multiple times in one spell. |
| D-16 | Modifiers can have opposite or partially opposite effects. |
| D-23 | Modifiers can affect properties that previous modifiers have already changed. |
| D-24 | Modifiers cannot reset the spell to a previous state. Each modifier operates on the state received from the previous modifier, or the base state if it is first. |
| D-36 | A modifier's ether cost counts as a drawback (see D-03), but it does not limit its other drawbacks. Each modifier defines whether it has ether drawbacks, practical drawbacks, or both. |

### Ether and resources

| ID   | Decision |
|------|----------|
| D-19 | Modifiers do not consume ether when activated. Each modifier adds to or otherwise changes the spell's total ether cost (see D-27). Ether is drawn only when the element is called. |
| D-27 | The spell's total ether cost is a spell property. Each modifier defines how it changes that cost: a fixed extra cost, a value calculated from the ether invested in the element, or a value calculated from other factors. Modifiers are applied sequentially, so their effect on cost is also sequential and order matters. |
| D-28 | The player has a personal ether pool. Spells draw ether from it. |
| D-29 | The player naturally absorbs ether from the surroundings into their pool, at a certain pace and radius around their position, until the pool is full. |
| D-31 | Absorbing ether depletes the ether of the place it comes from. Each place slowly recovers its ether over time. |
| D-33 | While the player draws, the pool drains according to the spell's cost function. Fixed extra costs are paid as a lump when drawing starts. If the pool cannot cover a lump, the spell fails immediately (see D-30). |
| D-35 | By default, the spell's size grows with the ether invested, so density stays at 1. A modifier can fix the size, making the spell denser; in that case, the invested ether may not be visible. |

### Casting and gameplay

| ID   | Decision |
|------|----------|
| D-18 | The player can cancel an already activated modifier and restart the casting process, as long as ether drawing has not started (see D-32). |
| D-20 | Each modifier can specify its own casting time. By default, modifier activation is immediate. |
| D-22 | There are no separate attack or defense actions. Spells perform those functions. The player can cast while moving. |
| D-25 | Cancelling a spell removes all activated modifiers. The entire spell construction is cancelled. Cancelling is only possible before ether drawing starts; since no ether has been drawn, there is nothing to recover. |
| D-30 | If the pool runs out of ether while drawing, before the player stops, the spell fails: nothing manifests, all ether drawn is restored, and all activated modifiers are wiped. |
| D-32 | Once ether drawing starts, the spell is confirmed and can no longer be cancelled. The player either stops drawing (the spell launches/manifests) or runs out of ether (the spell fails, see D-30). |
| D-34 | While the player draws, the spell is visible in its current form: a sphere if there are no shape modifiers, otherwise the shape defined by its modifiers. |

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

Based on the decided rules, casting follows this sequence:

1.  **Start with the default spell state.** The spell has a default
    manifestation, which is a sphere.
2.  **Activate modifiers.** Each modifier applies its effect to the
    current spell state and changes the spell's total ether cost
    sequentially. No ether is consumed at this point. A modifier may
    have its own casting time.
3.  **Repeat modifiers as desired.** Modifiers can be repeated, and
    there is currently no assumed limit. Each operates on the state left
    by the previous modifier.
4.  **Cancel, if desired.** Cancelling is only possible before drawing
    starts. It removes all activated modifiers and restarts the spell
    construction. Nothing needs to be recovered, since no ether has been
    drawn.
5.  **Call the element.** The player chooses the element. This starts
    the final phase: fixed extra costs are paid as a lump (if the pool
    cannot cover them, the spell fails), and then ether is drawn
    gradually from the player's pool according to the cost function.
    From this point the spell is confirmed and cannot be cancelled. The
    spell is visible while the player draws, and by default its size
    grows with the ether invested.
6.  **Stop drawing.** When the player stops, the spell launches and
    manifests with the resulting properties and behaviors. If the pool
    empties before the player stops, the spell fails: nothing manifests,
    all drawn ether is restored and all modifiers are wiped.

Independently of casting, the player's pool refills over time by
absorbing ether from the surroundings (at a certain pace and radius),
which depletes that place's ether until it slowly recovers.

## 4. Core design principles

These are the implications of the current specification:

-   Modifiers transform the current spell state sequentially, including
    its ether cost.
-   A modifier doesn't need to know what came before it.
-   Modifiers can affect properties already modified by previous
    modifiers.
-   Opposing modifiers are allowed; their effects can counteract or
    partially counteract each other.
-   The system should favor emergent combinations rather than predefined
    spell recipes.
-   The element is called last and is what actually starts drawing
    ether and, once the player stops, manifests the spell.
-   Ether is the limiting resource: it comes from the world, fills the
    player's pool, and is only spent when the player confirms the spell.
-   Ether cost counts as a drawback of a modifier, but a modifier can
    also have other, practical drawbacks.

## 5. Deferred

These points were intentionally postponed. They are not open questions.

-   **Density:** what density does, and what advantages and
    disadvantages it has, like any other property.
-   **Fixed-size feedback:** how the player perceives the invested ether
    when a modifier fixes the spell's size (presentation only).
-   **Interruptions:** whether and how ether drawing can be interrupted
    (for example by damage or stuns).

## 6. Open questions

None currently.

------------------------------------------------------------------------

This is the current baseline. Future changes should preserve the
distinction between decided rules and assumptions, and every change
should trigger a review of potentially affected assumptions.
