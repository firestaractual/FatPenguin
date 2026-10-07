class_name GameWorld
extends RefCounted
## What every part of the game agrees on about the world: where the water is, and which physics
## layer is which. (The layers are also named in Project Settings > Layer Names > 3D Physics.)
## Never instanced: use the constants, GameWorld.WATER_LEVEL and so on.

## The water surface is at y = 0. Anything below it is water.
const WATER_LEVEL := 0.0

## Physics layers, as collision bits.
## Layer 1, "world": ice, the seafloor, the level's walls. Ground, ledge and edge probes ray-cast
## against this layer only, so nothing mistakes a penguin for ice.
const WORLD_LAYER := 1
## Layer 2, "penguins": every penguin, player or not. Penguins collide with the world and each
## other (bumps are resolved by hand in Penguin._bump()).
const PENGUIN_LAYER := 2
## Layer 3, "predators": they collide with the world only. Their catches are by distance.
const PREDATOR_LAYER := 4
