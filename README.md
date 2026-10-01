# Fat Penguin

A cartoony mobile game based on real ecology. Penguins dive for fish to fuel up, but every fish makes them fatter and clumsier. Predators hunt whoever is most tempting. The ice keeps shrinking until there's nowhere left to hide.

> **Logo concept:** an overstuffed penguin falling through cracking ice.

## Status

**Prototype 0 (movement toy) is in progress.** A placeholder penguin can swim, boost, porpoise, launch onto the ice, walk, belly-slide, eat fish and get fat. There are no predators or goals yet, by design. See [docs/ROADMAP.md](docs/ROADMAP.md).

- **Engine:** Godot 4.7.2 (standard build), GDScript
- **Renderer:** Mobile

## Getting started

1. Install **Godot 4.7.2 stable**, the standard build rather than .NET, from [godotengine.org](https://godotengine.org/download).
2. In the Godot Project Manager, click **Import** and pick `project.godot` in this folder.
3. Press **F5** to play the movement toy.

## Controls

| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Steer (water: turn + up/down; ice: walk) | WASD / arrows | Left stick | Left half of the screen (floating stick) |
| Boost (water) / belly-slide (ice) | Space | A | Tap the right half of the screen |
| Reset to spawn | R | Start | – |
| Energy −10 / +10 (testing) | Q / E | – | – |
| Infinite energy (testing) | F2 | – | – |
| Show or hide debug info | F1 | – | – |

**Things to try:**

- Dive deep, pitch up, then boost to rocket out of the water onto the iceberg. You'll land in a belly-slide.
- Compare a thin penguin with a fat one (Q/E): the fat one turns wider and gets less height when launching.
- If you're out of energy and can't boost, climb out using the low ramp on the east side of the iceberg.
- Try the three floes (easy, medium and hard): each sits higher above the water.

## Tuning

Every balance number is in **`tuning/penguin_tuning_default.tres`**. Select it in the FileSystem dock and edit the values in the Inspector; no code changes needed. When a value feels right, copy it into [docs/TUNING.md](docs/TUNING.md).

## Project layout

```
actors/penguin/     Penguin controller (penguin.gd) + placeholder model scene
actors/fish/        Fish pickup
camera/             Follow camera (also switches on the underwater fog)
levels/movement_toy Prototype 0 test level (iceberg, ramp, floes, fish)
tuning/             PenguinTuning resource class + default values
ui/                 Debug HUD (air bar, numbers) and touch controls
art/materials/      Placeholder materials
tests/              Headless smoke test
docs/               Design docs (ignored by Godot)
```

## Testing

A headless smoke test drives the penguin through every movement and checks the results:

```
godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd
```

Exit code 0 means every check passed. Run it after changing movement code or tuning values.

## Docs

| Doc | What's in it |
|---|---|
| [docs/GDD.md](docs/GDD.md) | Game design document: pillars, core loop, mechanics, modes, open questions |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Prototype plan, with each prototype's goal, scope and success signals |
| [docs/TUNING.md](docs/TUNING.md) | Every balance number in one place (starting values for playtesting) |
| [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md) | Visual tone, readability rules, logo brief |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Dated log of design decisions and why they were made |

## The game in one paragraph

You leave the safety of the **waddle** (the penguin crowd on the ice) to dive for fish. Food is energy: it powers your boosts, dodges and shoves, but it also makes you fat, slow to turn and the predators' favorite target. Energy runs out, so you have to keep going back out, and the main decision is *when*. In multiplayer, the last penguin standing wins once the ice shrinks to a single floe and the orcas start lunging. In the single-player campaign, you live through a penguin's year one 5–10 minute level at a time.
