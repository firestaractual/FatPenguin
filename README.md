# Fat Penguin

A cartoony mobile game based on real ecology. Penguins dive for fish to fuel up, but every fish makes them fatter and clumsier. Predators hunt whoever is most tempting. The ice keeps shrinking until there's nowhere left to hide.

> **Logo concept:** an overstuffed penguin falling through cracking ice.

## Status

**Prototype 0 (movement toy) is in progress.** A placeholder penguin can swim, boost, porpoise, launch onto the ice, walk, belly-slide, slide down chutes, hop up steps and across gaps, bump other penguins, eat fish and get fat. The ice is a field of bergs of real shapes to climb, with ice tunnels and pack ice, and colonies of computer penguins huddle on them and go fishing. Two leopard seals (the first piece of Prototype 1) and a pod of orcas hunt the water, and two humpback whales roam it: not enemies, but they feed with bubble nets and drive orcas off. It starts at a title screen (feed the penguin until he falls through the ice), and has a HUD (an air meter and control prompts), a pause menu and settings. There are no goals yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

- **Engine:** Godot 4.7.2 (standard build), GDScript
- **Renderer:** Mobile

## Getting started

1. Install **Godot 4.7.2 stable**, the standard build rather than .NET, from [godotengine.org](https://godotengine.org/download).
2. In the Godot Project Manager, click **Import** and pick `project.godot` in this folder.
3. Press **F5**. On the title screen, tap, click or press Space to feed the penguin; when he's fat enough he falls through the ice and the movement toy starts. (Open `levels/movement_toy/movement_toy.tscn` and press **F6** to skip the title.)

## Controls

| | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Steer (water: turn + up/down; ice: walk) | WASD / arrows | Left stick | Left half of the screen (floating stick) |
| Boost (water) / belly-slide (ice) | Space | A | Tap the right half of the screen |
| Flipper push (mid-slide) | Space again | A again | Tap again |
| Dig in / brake (mid-slide) | S / Down | Left stick back | Pull the stick back |
| Pause (Resume, Restart, Settings, Quit to title) | Esc / P | Start | Pause button, top right |
| Reset to spawn (testing) | R | – | – |
| Energy −10 / +10 (testing) | Q / E | – | – |
| Infinite energy (testing) | F2 | – | – |
| Show or hide debug info (hidden at first) | F1 | – | Settings › Show debug info |

**Settings** (from the title screen or the pause menu, saved between sessions): invert swim pitch, left-handed touch controls (stick on the right), hints (the control prompts and warnings at the bottom of the screen; each prompt stops once you've done what it teaches a few times), screen effects (Full, Reduced or Off: the dimming, tunnel vision and black-outs below), and show debug info.

**Things to try:**

- Dive deep, pitch up, then boost to rocket out of the water onto the iceberg. You'll land in a belly-slide.
- Compare a thin penguin with a fat one (Q/E): the fat one turns wider and gets less height when launching.
- Run low and you get thin and weak, but never quite stuck: the cold can't take you below the energy floor, and if you spend below it you get your breath back in a few seconds. You can also climb out of the water without boosting using the low ramp on the east side of the iceberg.
- Try the three floes (easy, medium and hard): each sits higher above the water.
- **The plateau** in the middle of the iceberg: walk into the small east steps to hop up (anyone can), or the big north steps (thin penguins only; press Q to slim down). Slide back down the gentle south chute or the steep west one. The south chute will shoot you into the sea unless you dig in (pull back) at the bottom.
- **Leopard seals:** two patrol the water around the berg, and they hear you splash in from farther off than they can see. An orange ring around you means one has locked on. When the ring flashes and a line appears, that line is where it's about to lunge: turn off it or boost. If you're caught you're eaten, and you start again on the ice. Seals go for the fattest penguin they can see, and noisy bumps draw them. Don't stand right at the ice edge: a lunge reaches about a metre onto the ice. A starving seal goes off to eat from a school, which is your chance to slip past (F1 shows the nearest seal's state and hunger). Stand near the edge and a seal may lie in wait right under it: a still, dark shape. Go in there and it lunges almost at once. Slide across the berg and go in somewhere else, or, coming home, boost and launch from 6–7 m out so you fly over it.
- **Orcas:** a pod of three swims farther out. They won't chase you in open water unless you swim right up to them, but stand near an ice edge they're passing and they'll line up with their fins showing, raise a swell and charge. The ice you're on turns orange: walk out of it before the wave breaks. On your feet the wave skids you to the edge, where you can still scramble back; on your belly it washes you straight in, where the orcas are waiting. Stand on a floe (or near the berg's edge) and they may ram it instead: dark shadows gather under the ice, the water bulges and the floe turns orange, then it tips and you slide off into the water. Pull back to dig in and hold on until it rights itself. Rammed, the big berg only rocks, but the jolt can still shove you in if you're right at the edge. In the water the pod traps you. Near the ice, fins race to get between you and home: beat them back, or swim round the end of the wall with a boost; swim at the wall and you're lunged at. Out in open water they circle you and blow a ring of bubbles that you can't swim through (but you can boost through) and that keeps you at the surface. Then the ring squeezes, a tail slap stuns you if you're in the orange middle, and an orca lunges. Get washed in by a wave and the pod goes straight on to the next step. F1 shows which attack is coming, how long until it hits, and which step of the trap it is.
- **Orcas press the attack:** an orca's lunge is aimed where you're going, not where you are (the strike line shows it), so keep doing the same thing and you're caught: change course, or boost, when the line appears. Miss you, and the next orca of the pod comes straight in from another side while the first gets its breath back; they shadow the hunt so one is always close. Don't swim into one, either: touching an orca's body (or any whale's) shoves you off and **dazes** you for about 2 s (no boost, slow and wobbly, your heading drifting), and the orca strikes at once.
- **Humpbacks:** two humpback whales cruise round the berg field. From afar, at the surface, one looks a lot like an orca: a dark back and a fin. Look for the size (twice an orca), the little fin far back on a hump, the long white flippers, the slow pace, the bushy blow when it comes up to breathe, and its flukes rising as it dives. They never eat penguins. Every minute or so one feeds: it circles a fish school deep down, blowing a ring of bubbles that closes in, the fish pack into a ball at the surface and the water boils, then it lunges straight up through the middle and swallows the lot (that school is gone for 45 s). Be in the ring when it comes up and you're scooped up and thrown out, dazed and a fish lighter: swim clear when the prompt says so. And humpbacks hate orcas: when orcas hunt a penguin within 35 m of one, it comes over, and once it's within 10 m of that penguin the orcas give up (a pod calls its attack off). Any penguin that close to a humpback is safe from orcas, so a hunted penguin can swim to one, if it can tell it from an orca in time. Not from leopard seals, though.
- **The berg field:** five more bergs sit round the home berg, each a real kind of iceberg and each its own climb. The **mesa** (flat-topped, 3 m high) is too tall to launch onto: find its ice foot, the ramp along one side. The **wedge** is a long slope to swim onto and walk up, to a cliff. The **pinnacle** has a low shelf and a spire with steps spiralling up it, each flight taller than the last (slim down with Q to reach the lookout), and a chute back down. The **dome** is too steep to stand on except for a stair up its east side. The **drydock** is a U with a lagoon too shallow for orcas.
- **Ice tunnels:** walk through the cave in the pinnacle's spire, or swim through the tunnels in the keels of the mesa and the wedge (dive about 3 m down at either end of the berg and look for the opening). An orca can't follow you in; a leopard seal can. The mesa's is long, so watch your air.
- **Pack ice:** two chains of small floes lead from the home berg to the wedge and the pinnacle. Walk at a gap and you hop it if you're thin enough; fat, you stop at the edge, and the only way on is to swim.
- **Colonies:** computer penguins (tinted differently from you) huddle in the middle of their bergs, the cold ones on the windward edge walking round to the sheltered side. When they get hungry they wait at the edge for a few others and go fishing together, then swim home and climb out by the same ramps and launches you use. Predators hunt them as they hunt you, so going out with a party is cover.
- **Feel the danger:** when a predator is near, the edges of the screen slowly darken, closing in from the sides, darker the closer it is and darkest when it's hunting you, with a heartbeat at its worst. Boosting narrows your view a little; a hit (a whale's body, a tail slap, a lunge from close by, a hard bump) closes it right in, and getting caught blacks it out. Turn it down or off in Settings › Screen effects.
- **Food:** besides fish schools there are pink **krill swarms** near the surface (keep your beak in one and you keep eating; a whole swarm is worth six fish) and **squid** (worth two and a half fish, but get close and it jets away squirting ink; it tires after three jets, so chase it down or boost). About one fish in ten is **sick**: yellow-green, bloated, blotchy, swimming on its side behind its school. Eat one and you're queasy for 6 s (slow, no boost, no belly-slide, the screen swims and goes green) and you throw it back up.
- **Fish schools:** fish come in three species, and each schools only with its own kind: silver Antarctic silverfish in big tight schools, small dark lanternfish deeper down, and big pale icefish in loose little groups. Swim through a school to grab several in one pass. An eaten fish comes back beside its school.
- **Bumping:** belly-slide into the blue dummy penguins. A thin one standing skids a few metres (a full-speed hit can put it in the water); one lying on its belly flies. Get stuffed (E) and you hit like a bowling ball; slide into the fat dummy while thin and you bounce off, but knock a fish loose. The dummy near the south-west edge teeters before it falls in. Get knocked to an edge yourself and pull the stick back to scramble to safety (costs a little energy).

## Tuning

Every penguin balance number is in **`tuning/penguin_tuning_default.tres`**, the NPC penguins' behaviour is in **`tuning/npc_default.tres`**, each fish species is in **`tuning/fish/`**, the predators are in **`tuning/predators/`** (`leopard_seal.tres`, `orca.tres`, `orca_pod.tres`, and the pod's attacks `orca_wave.tres`, `orca_ram.tres`, `orca_cut_off.tres` and `orca_carousel.tres`), the humpback is **`tuning/humpback.tres`**, krill and squid are **`tuning/krill.tres`** and **`tuning/squid.tres`**, and the screen effects are **`tuning/screen_fx.tres`**. What spawns in the movement toy is in `levels/movement_toy/predators/`. Select one in the FileSystem dock and edit the values in the Inspector; no code changes needed. Each berg's size and shape are on its node under `BergField` in the movement toy scene: select it and edit them in the Inspector, and the berg rebuilds as you go. When a value feels right, copy it into [docs/TUNING.md](docs/TUNING.md).

## Project layout

```
actors/penguin/     Penguin body and movement rules (penguin.gd) + placeholder model scene, and its parts:
                    controls (penguin_input.gd; player_input.gd for each player, brain_input.gd for NPCs),
                    energy and air (penguin_vitals.gd), the look (penguin_look.gd, on the Model node);
                    penguin_brain.gd drives NPCs
actors/fish/        Fish pickup (schools with its own species)
actors/swimmer.gd   What every big swimmer shares (steering, staying in the water, ice, its shadow, a whale's
                    body that dazes penguins): the base of predators and whales
actors/whales/      The humpback (humpback.gd + scene)
actors/food/        Krill swarms (krill_swarm.gd) and squid (squid.gd); fish are in actors/fish/
actors/predators/   Predators: predator.gd (every kind), leopard seal and orca scenes, pods (predator_pod.gd,
                    orca_pod.gd), pod attacks (pod_attack.gd; on the ice edge_attack.gd, wave_attack.gd,
                    ram_attack.gd; in the water cut_off_attack.gd, carousel_attack.gd; effects ice_wave.gd,
                    bubble_wall.gd), and spawning (PredatorSpawn + PredatorSpawner)
camera/             Follow camera (also switches on the underwater fog)
core/               What every part shares: game_world.gd (water level, physics layers), game_mode.gd
                    (a level's rules: what a catch does), game_settings.gd (the player's settings, saved to
                    user://settings.cfg)
levels/             tippable_ice.gd (ice that orcas can tip), ice_edges.gd (where the ice ends, for predators)
levels/bergs/       IceBerg (ice_berg.gd, the base class) and each kind of berg: tabular, wedge, drydock,
                    pinnacle, dome; home_floe.gd (the original berg) and floe_chain.gd (pack ice)
levels/movement_toy Prototype 0 test level (home berg + plateau, ramp, floes, berg field, fish, colonies,
                    dummy penguins)
tuning/             PenguinTuning resource class + default values; FishSpecies class + species in tuning/fish/;
                    NpcTuning + npc_default.tres (NPC penguins); PredatorTuning / PodTuning /
                    PodAttackTuning classes + the seal, orca, orca pod and its attacks in tuning/predators/
ui/                 Touch controls, the debug layer (debug_hud: numbers and tester keys, hidden unless
                    asked for) and input_device.gd (which device the player is using, for prompts)
ui/hud/             The in-game HUD: air meter, control prompts, pause button, and the screen effects
                    (screen_fx.gd + shaders: dimming near predators, tunnel vision, black-outs, queasy)
ui/menus/           Pause menu and the settings sheet
ui/title/           The title screen (the feeding gag)
ui/theme/, ui/fonts The UI theme (fat_penguin_theme.tres, set project-wide) and its fonts (Outfit, Erica One;
                    SIL Open Font License, licence files alongside)
art/materials/      Placeholder materials
tests/              Headless smoke test: movement_smoke_test.gd runs the suites in tests/suites/;
                    tests/trials/ holds tuning trials (whale_trials.gd: orca attacks against a bot penguin)
docs/               Design docs (ignored by Godot)
```

## Testing

A headless smoke test drives the penguin through every movement and checks the results:

```
godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd
```

Exit code 0 means every check passed. Run it after changing movement code or tuning values. The checks are grouped in suites (`tests/suites/`); to run only some, add them after a lone `--`:

```
godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd -- --only=orcas,npcs
```

The suites are movement, bumping, fish, seals, orcas, whales, bergs, npcs, players and ui. Predators and NPC penguins make random choices, so a run can fail now and then where it usually passes: every run prints its seed, and `-- --seed=N` replays it.

Tuning trials play many short encounters and print how often a bot penguin gets caught (they're not pass/fail). For the orcas, with each scenario and the bot's reaction to a lunge warning:

```
godot --headless --fixed-fps 60 --path . --script res://tests/trials/whale_trials.gd -- --scenario=lunge --policy=turn --reaction=0.2 --runs=30
```

The script's header lists the scenarios and policies; docs/TUNING.md has the results the current numbers were tuned to.

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
