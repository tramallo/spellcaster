# Runes

What each rune does and costs, as built now. These are implementation specifications, not design
decisions: the values can change at any time. The design rules (spell lifecycle, what a rune is,
failure) are in `spellcrafting-system-plan.md`. The runes are defined in
`scripts/runes/rune_catalog.gd`, and the player's hotbar is Q, E, R, T (slot 1 starts with Cube).

## Rune kinds

| Kind | Input | When it applies | Runes |
|------|-------|-----------------|-------|
| `summon` | hold | Casting | Mana, Fire |
| `movement` | hold | Release (the speed is stored in Casting and given as a kick on release) | Acceleration |
| `density` | hold | Casting | Density |
| `shape` | tap | Casting | Spike, Cube |

Every rune except Mana and Fire needs a spell in Casting; pressed without one, it does nothing.

## Paying: the pool, and failure

Every mana a rune asks for is taken from the character's mana pool (the reserve, 20 at most; a
character starts with it full). Nothing is ever paid in part: if the pool cannot cover what the
rune asks, the spell fails (`spell_fizzled`) and the mana already invested in it is lost. The
pool refills only by passive absorption (see `game_world.md`).

- A spell needs its **starting mana** (see Summoning) to form. If the pool holds less, nothing
  forms and nothing is taken.
- While a spell is being cast, any rune that cannot be paid makes it fail: Mana and Fire while
  growing, Acceleration at its start and while growing.

## Summoning (Mana and Fire)

- Pressing Mana (or Fire) with no spell in Casting creates one, paying its **starting mana**: a
  starting radius of 0.075 m (`start_radius`), which at 0.5 m per mana is 0.15 mana.
- Holding the rune adds mana at 1 mana per second (`mana_per_second`), taken from the pool.
- Fire summons exactly like Mana, and sets the spell's element to fire (it only changes the
  colour for now).

### Size, density and the size limit

- **Size from mana:** at density 1, 1 mana makes a 0.5 m radius (`radius_per_mana`). Density
  divides that natural radius to get the real one.
- **Mass** is the spell's mana, 1 to 1, from the moment it forms. Size and density do not change
  it.
- **Size limit:** new mana goes partly to size and partly to density. The size share is 1 for
  small spells and fades smoothly (smoothstep) to 0 across a band centred on 0.5 mana
  (`size_limit_mana`), from 0.125 to 0.875 (`size_limit_softness` = 0.375, half the band). Size
  therefore stops at 0.25 m radius (0.5 m diameter), and every extra mana raises density instead
  (density = mana / 0.25 m x 0.5, so twice the mana).
- **Gravity:** every spell is pulled by half the world's gravity (`spell_gravity_scale` = 0.5).
  Gravity acceleration does not depend on mass (no air drag for now); mass matters for impacts.

## Acceleration

- Costs mana from the **pool**, not from the spell: 0.25 mana per 1 speed
  (`mana_per_acceleration`). The spell's own mana, size, density and mass are not touched.
- Pressed, it starts at 0.1 speed, paying 0.025 mana. If the pool cannot pay that, the spell
  fails.
- Held, the speed grows 11.5 per second (`acceleration_growth_per_second`), which costs 2.875 mana
  per second (1 speed takes about 0.08 s). If the pool cannot pay a step, the spell fails.
- Releasing the key locks the speed. Pressing it again continues from the locked speed.
- On release of the spell it gets its full speed at once, as a kick along its aim (no ramp);
  gravity and collisions decide the rest.
- Damage grows with it: every point of speed is a point of damage (`damage_per_acceleration`).

## Density

Holding the Density rune compresses the spell: its size shrinks while its mana, and so its mass,
stay the same. The gain is 3.2 density per second (`density_gain_per_second`), easing out as the
size approaches the smallest radius, 0.01 m (`min_radius`). It costs no mana.

## Shape runes (Spike and Cube)

A shape rune **sets** the spell's shape: it does not transform the current one, so the last
shape rune used is the shape, and the shape runes replace each other. Pressing the rune of the
shape the spell already has (or is changing to) does nothing.

- Shapes are convex polyhedra whose corners lie on the unit sphere, scaled by the spell's radius,
  so a shaped spell fits inside the sphere it replaces and the mana, size and density rules stay
  as they are.
- The change is a smooth morph of 0.3 s (`shape_morph_time`). To replace one shape with another,
  the spell morphs back to a sphere (0.3 s) and then into the new shape (0.3 s). The spell's
  collision is a sphere while it morphs and the shape itself when the morph is complete.
- **Spike** (slot T, glyph △): a 3-sided pyramid (regular tetrahedron) whose point faces the
  front of the spell (the crosshair aim). Its flat base sits on the caster's fingertips.
- **Cube** (glyph □): a cube whose diagonals are hidden, so only its edges show.
- After launch every spell, shaped or not, keeps its front toward its direction of travel
  (dart-like, no tumbling) while it moves faster than 0.5 m/s; slower than that it is a normal
  physics body.
