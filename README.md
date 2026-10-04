# Fat Penguin

A cartoony mobile game based on real ecology. Penguins dive for fish to fuel up, but every fish makes them fatter and clumsier. Predators hunt whoever is most tempting. The ice keeps shrinking until there's nowhere left to hide.

> **Logo concept:** an overstuffed penguin falling through cracking ice.

## Status

**Prototype 0 (movement toy) is in progress.** A placeholder penguin can swim, boost, porpoise, launch onto the ice, walk, belly-slide, slide down chutes, hop up steps, bump other penguins, eat fish and get fat. Two leopard seals (the first piece of Prototype 1) hunt the water. There are no goals yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

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
| Flipper push (mid-slide) | Space again | A again | Tap again |
| Dig in / brake (mid-slide) | S / Down | Left stick back | Pull the stick back |
| Reset to spawn | R | Start | – |
| Energy −10 / +10 (testing) | Q / E | – | – |
| Infinite energy (testing) | F2 | – | – |
| Show or hide debug info | F1 | – | – |

**Things to try:**

- Dive deep, pitch up, then boost to rocket out of the water onto the iceberg. You'll land in a belly-slide.
- Compare a thin penguin with a fat one (Q/E): the fat one turns wider and gets less height when launching.
- Run low and you get thin and weak, but never quite stuck: the cold can't take you below the energy floor, and if you spend below it you get your breath back in a few seconds. You can also climb out of the water without boosting using the low ramp on the east side of the iceberg.
- Try the three floes (easy, medium and hard): each sits higher above the water.
- **The plateau** in the middle of the iceberg: walk into the small east steps to hop up (anyone can), or the big north steps (thin penguins only; press Q to slim down). Slide back down the gentle south chute or the steep west one. The south chute will shoot you into the sea unless you dig in (pull back) at the bottom.
- **Leopard seals:** two patrol the water around the berg. An orange ring around you means one has locked on. When the ring flashes and a line appears, that line is where it's about to lunge: turn off it or boost. If you're caught you're eaten, and you start again on the ice. Seals go for the fattest penguin they can see, and noisy bumps draw them. Don't stand right at the ice edge: a lunge reaches about a metre onto the ice. A starving seal goes off to eat from a school, which is your chance to slip past (F1 shows the nearest seal's state and hunger). Stand near the edge and a seal may lie in wait right under it: a still, dark shape. Go in there and it lunges almost at once. Slide across the berg and go in somewhere else, or, coming home, boost and launch from 6–7 m out so you fly over it.
- **Orcas:** a pod of three swims farther out. They won't chase you in open water unless you swim right up to them, but stand near an ice edge they're passing and they'll line up with their fins showing, raise a swell and charge. The ice you're on turns orange: walk out of it before the wave breaks. On your feet the wave skids you to the edge, where you can still scramble back; on your belly it washes you straight in, where the orcas are waiting. Stand on a floe (or near the berg's edge) and they may ram it instead: dark shadows gather under the ice, the water bulges and the floe turns orange, then it tips and you slide off into the water. Pull back to dig in and hold on until it rights itself. Rammed, the big berg only rocks, but the jolt can still shove you in if you're right at the edge. In the water the pod traps you. Near the ice, fins race to get between you and home: beat them back, or swim round the end of the wall with a boost; swim at the wall and you're lunged at. Out in open water they circle you and blow a ring of bubbles that you can't swim through (but you can boost through) and that keeps you at the surface. Then the ring squeezes, a tail slap stuns you if you're in the orange middle, and an orca lunges. Get washed in by a wave and the pod goes straight on to the next step. F1 shows which attack is coming, how long until it hits, and which step of the trap it is.
- **Fish schools:** fish come in three species, and each schools only with its own kind: silver Antarctic silverfish in big tight schools, small dark lanternfish deeper down, and big pale icefish in loose little groups. Swim through a school to grab several in one pass. An eaten fish comes back beside its school.
- **Bumping:** belly-slide into the blue dummy penguins. A thin one standing skids about a metre; one lying on its belly flies. Get stuffed (E) and you hit like a bowling ball; slide into the fat dummy while thin and you bounce off, but knock a fish loose. The dummy near the south-west edge teeters before it falls in. Get knocked to an edge yourself and pull the stick back to scramble to safety (costs a little energy).

## Tuning

Every penguin balance number is in **`tuning/penguin_tuning_default.tres`**, each fish species is in **`tuning/fish/`**, and the predators are in **`tuning/predators/`** (`leopard_seal.tres`, `orca.tres`, `orca_pod.tres`, and the pod's attacks `orca_wave.tres`, `orca_ram.tres`, `orca_cut_off.tres` and `orca_carousel.tres`). What spawns in the movement toy is in `levels/movement_toy/predators/`. Select one in the FileSystem dock and edit the values in the Inspector; no code changes needed. When a value feels right, copy it into [docs/TUNING.md](docs/TUNING.md).

## Project layout

```
actors/penguin/     Penguin controller (penguin.gd) + placeholder model scene
actors/fish/        Fish pickup (schools with its own species)
actors/predators/   Predators: predator.gd (every kind), leopard seal and orca scenes, pods (predator_pod.gd,
                    orca_pod.gd), pod attacks (pod_attack.gd; on the ice edge_attack.gd, wave_attack.gd,
                    ram_attack.gd; in the water cut_off_attack.gd, carousel_attack.gd; effects ice_wave.gd,
                    bubble_wall.gd), and spawning (PredatorSpawn + PredatorSpawner)
camera/             Follow camera (also switches on the underwater fog)
levels/             tippable_ice.gd (ice that orcas can tip), ice_edges.gd (where the ice ends, for predators)
levels/movement_toy Prototype 0 test level (iceberg + plateau, ramp, floes, fish, dummy penguins)
tuning/             PenguinTuning resource class + default values; FishSpecies class + species in tuning/fish/;
                    PredatorTuning / PodTuning / PodAttackTuning classes + the seal, orca, orca pod
                    and its attacks in tuning/predators/
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

If a pull adds a new script class and the test fails with "Could not find type", open the project in the editor once (or run `godot --headless --import --path .`) so Godot registers the new class, then run the test again.

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
