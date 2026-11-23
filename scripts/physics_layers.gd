extends RefCounted
## Collision layers of the game (bit values, for `collision_layer` / `collision_mask`).
## What each one is for, and who collides with whom: docs/game_world.md.
## The same names are set in Project Settings > Layer Names > 3D Physics.

## The solid world: floor, props and the characters' movement capsules.
const PHYSICS := 1
## Everything magic: the spells, and the characters' hurtboxes (the parts of the body spells hit).
const MAGIC := 2
