# Fat Penguin — Decision Log

Newest first. Each entry records what was decided and why. To reverse a decision, add a new entry rather than editing an old one.

---

## 2026-10-08: Playtest fixes: feeling the danger, harder knocks, hungrier predators, more food, sick fish

From Ben's playtest of the whale build. See GDD §4.5, §4.11, §5.1–5.3 and §5.6, ART_DIRECTION (Readability), TUNING (Bumping, Screen effects, Predators, Fish, Krill, Squid, Queasy).

- **Feeling the danger (screen effects):** the screen now tells you how much trouble you're in, without a meter.
  - **Anxiety:** when a predator is within 25 m (you sense it, in sight or not), the edges of the screen slowly darken, closing in from the sides; closer is darker, and one hunting you (locked on, lining up a lunge, a pod's attack on you) takes it near full, with a heartbeat throb at its worst. It creeps in over a couple of seconds and fades back out over three or four once you're clear. A sated predator counts for a third; on the ice, anything but a hunt counts for half. Humpbacks don't count: they aren't predators (telling them apart by eye is still the skill; the dread comes from what's really hunting you).
  - **Tunnel vision when boosting:** mild, quick in, slower out.
  - **Hits close the screen in:** a whale's body (dazed), a tail slap (stunned), a lunge at you from close by (hit or miss), a hard bump from a penguin; the stronger the hit, the further it closes and the longer it takes to open back up. **Caught:** it blacks out, then comes back.
  - The dark is a deep navy black, never the danger colour. A **Screen effects** setting (Full, Reduced, Off) is in Settings, for players they bother.
- **Harder knocks:** penguin-on-penguin bumps now hit 1.5 × harder than the collision maths alone (`bump_knock_mult`) and bounce a little more (0.85, was 0.8), so a penguin is easier to dislodge. A thin penguin's full-speed hit now skids a standing thin one ~5.4 m (was ~2.3), enough to put it in the water from the middle of a small floe; feet still beat belly by far, and a fat penguin is still hard to shift (~1 m). Outside shoves (a wave, a ram's jolt, a whale) aren't scaled: a first try that made everyone's footing worse (more knock on your feet, a shorter teeter) also made digging in on a rammed floe fail, so it was undone.
- **Predators come for you more readily ("jumped in right in front of the sea lions and nothing happened"):** headless trials showed seals mostly do react, but three things let a penguin off: a seal lying in wait ignored anyone more than 6 m off, a starving seal ignored anyone not right up to it while it went to eat (a third of its time), and seals only noticed penguins they could see within 20 m. Now:
  - **They hear you go in:** a splash (going in, bursting out) makes noise, and a noisy penguin is noticed farther off, up to 35 m for a seal (20 m for an orca).
  - **An ambush breaks for a swimmer within 14 m:** it comes out after you.
  - **Starving, it still breaks off for a penguin within 10 m.** Seals get hungry more slowly too (0.6 a second, was 1), so they go off to feed less often.
  - Seals see 24 m (was 20), chase for 15 s (was 12) out to 30 m (was 25). Orcas notice penguins within 12 m (was 8; still not out in open water from far off), and the pod attacks sooner (first attack after 6 s, was 10; 12 s between traps, was 20).
  - Trials, a penguin jumping off the ice near a seal: it locks on and lines up a lunge 15 times in 16 (was 12 in 16, with the misses an ambushing or feeding seal).
- **More food, and new kinds:**
  - **More fish:** 28 schools and 36 loose fish (was 20 and 24), about 300 fish.
  - **Krill swarms:** 8 pink clouds of krill near the surface (0.6–3 m down). Keep your beak in one and you eat krill steadily, 12 a second at 0.75 energy each: 80 in a swarm, worth six fish if you stay for all of it. Eaten out, it forms again nearby after 40 s. Krill are what Adélie penguins really live on.
  - **Squid:** 6, a big meal (25 energy, two and a half fish) that won't sit still: come within 4.5 m and it jets away at 9 m/s, squirting ink. It can jet only every 1.4 s, and after three in a row it's spent for 6 s, so you chase it down, or catch it with a boost.
- **Sick fish (diseased, or full of parasites):** about one fish in ten. They look it: sickly yellow-green, bloated, blotchy with dark parasite cysts, listing on their side and swimming lamely behind their school with the odd twitch. Eat one and you're **queasy** for 6 s: no boost, no belly-slide, half speed, slow turns and a wandering heading, the screen swims and goes green, and you throw the fish back up a second later, worth nothing (you're 3 energy down instead). NPC penguins can tell and pass them over (unless they blunder into one); predators eat them like any fish.
- **Why:** the playtest showed the game didn't feel dangerous enough: predators were easy to ignore and there was no sense of threat until a lunge. Knocks were too gentle for bumper-car PvP. More food and food that behaves differently (stay in a swarm, chase a squid, spot the sick fish) give foraging some decisions.
- **Reuse:** `ScreenFx` (`ui/hud/screen_fx.gd`, in `GameHud`, numbers in `tuning/screen_fx.tres`) only reads the penguin and the predators. `Penguin.eat(energy)` for any food, `eat_sick_fish()`, `sicken()`, `is_queasy()`, `queasiness()`, and the `sickened` / `threw_up` signals. `Fish.sick` / `make_sick()`. `KrillSwarm` and `Squid` (`actors/food/`, numbers in `tuning/krill.tres` and `tuning/squid.tres`) build their own looks in code. `GameSettings.screen_effects`.
- **Not yet:** humpbacks feeding on krill swarms, predators reacting to krill and squid, sick fish making predators sick, a sound for the heartbeat.
- Proposed.

## 2026-10-08: Orcas press their attacks; whale bodies daze; humpbacks

- **Change:** orcas no longer lunge several times and miss. A whale's body is now a hazard that dazes you. A new animal, the humpback whale, shares the water: not an enemy, but it feeds with bubble nets and drives orcas off. See GDD §5.3 and §5.5, TUNING (Dazed, Orca, Orca pod, Humpback).
- **Why orcas missed:** headless trials showed each lunge aimed at where the penguin was, so anyone just swimming round was already off the line by the time the jaws got there (a circling penguin was caught by 2 lunges in 10), and after a miss nothing happened for 2.5 s.
- **Orcas lead their lunges:** each lunge is aimed where you'll be when the jaws arrive if you keep doing what you're doing, straight or round the turn you're making (`Penguin.turning()`). The strike line shows the aimed line, so the warning stays honest: change course or boost and it misses. To keep each lunge fair: the warning is 0.7 s (the seal's 0.6), and the catch reach is 1.2 m (was 1.8; aiming ahead, it doesn't need the slack). Trials: a penguin that does nothing is caught 81% of the time; one that turns off the line within 0.2 s, 19%; one that boosts, 10%. The lunge also starts farther out (8 m) and carries farther.
- **Relay strikes:** when an orca's lunge misses, the nearest other orca of the pod strikes straight away from where it is, with its own warning and strike line, while the first gets its breath back. Up to 3 in a row; while one hunts, the others shadow it 10 m off either side so one is always close. Not while a group attack is lining up or under way.
- **Whale bodies daze (dazed + drifting):** touch a whale's body (an orca's 6 m, a humpback's 12 m) and you're shoved off it and dazed for about 2 s: stunned (no boost, slow turns, slow swimming) and your heading drifts, as if spun in its wake. An orca you bump strikes at once. It's what "the whale keeps attacking" means: a bump costs you your dodge.
- **The humpback:**
  - **Looks like an orca from afar:** a dark back, a fin and a dark shadow at the surface. Up close: twice the size, a little fin far back on a hump, long white flippers, a slow pace. Its bushy blow (every 25–40 s) and its flukes rising as it dives are the tells.
  - **Bubble net (scooped and tossed):** about once a minute it circles a school in open water, deep, blowing a ring of bubbles that closes in over 8 s and herds the fish into a ball at the surface; the water boils; then it lunges up through the middle and swallows the school, which stays gone for 45 s. A penguin in the ring is scooped up and thrown out, dazed for 2.5 s, and a fish comes back up. Never eaten. The warning is white foam (it isn't an attack, so no danger colour), plus a prompt and NPCs that swim clear.
  - **Drives orcas off (they mob orcas):** when orcas hunt a penguin within 35 m of it, it comes over at 4 m/s, blowing, and once it's within 10 m of that penguin the orcas give up and a pod calls its attack off. It stays by the penguin for 10 s. Any penguin within 10 m of a humpback is off limits to orcas (`PredatorTuning.shy_of_humpbacks`), so a hunted penguin can hide by one. Seals don't care.
  - **Why:** real humpbacks do both (bubble-net feeding, and breaking up orca hunts). A refuge that's easy to mistake for the threat turns an open-water escape into a decision, and the net makes schools contested by something besides predators.
- **Reuse:** `Swimmer` (`actors/swimmer.gd`) is now the base of every big swimmer: steering, staying in the water, getting round or under ice, the shadow, and a whale's body (`SwimmerTuning.body_length`). `Predator` extends it; `Humpback` (`actors/whales/humpback.gd`) does too. `Penguin.disorient()` dazes, `Penguin.toss()` throws, `Penguin.lose_fish()` spills one. `Fish.herd()` / `herd_near()` / `gulp_near()` and `get_eaten(respawn_after)` let anything net and clear a school. `PredatorPod.call_off()` ends an attack from outside. Tuning trials live in `tests/trials/` (`whale_trials.gd`).
- **Not yet:** humpback song, breaching for show, a calf, humpbacks protecting penguins from leopard seals, and orcas that learn to wait a humpback out.
- Proposed.

## 2026-10-07: A real UI: the title gag, a HUD that teaches, debug numbers out of sight

- **Change:** the movement toy gets a real UI instead of a debug overlay. The game starts at a title screen; in play there's a HUD, a pause menu and settings; the debug numbers and the wall of tester notes are hidden unless asked for.
- **Title screen (GDD §1):** the logo acted out, with the game's own placeholder penguin. It stands on a disc of thin, gray-blue ice (the only thin ice in the game). Each tap, click, Space or A throws it a fish; it gulps it down and swells (about 1.9× as wide by the sixth). From the third fish the ice cracks along its seams, more with each one; on the sixth it drops straight through, the pieces tip into the water, and the splash whites out into the game. The game scene loads in the background meanwhile. Settings are reachable from here.
- **HUD:** no energy bar, still (body size is the energy display, §4.1). An **air meter**, a row of six bubbles that pop as your breath runs out, shows only underwater and short of breath, and pulses when nearly out. A **pause button** sits top right. **Control prompts** at the bottom replace the wall of hint text: a short prompt naming the control for the device you're using ("SPACE boost", "TAP belly-slide", "PULL BACK dig in to brake") at the moment it's useful. Each tutorial prompt stops once you've done the thing a few times (2–3), and remembers that between sessions. Warnings always show and cut in first: low on air, teetering at an edge, a seal locked on (the first three times).
- **Pause menu:** Resume, Restart, Settings, Quit to title. Esc, P or a gamepad's Start, or the pause button. It pauses by itself when a phone sends the game to the background (§8). The game really stops: fish respawns and pickup delays wait too.
- **Settings** (saved on the device): invert swim pitch (moved here from the penguin's tuning: it's a player preference, not balance), left-handed touch controls (stick on the right), hints on or off, and show debug info.
- **Debug numbers:** hidden by default. F1 or the settings switch shows them (the same setting); the tester keys (Q/E/F2/R) still work either way. R no longer sits on the gamepad's Start, which pauses now.
- **Look:** chunky and rounded to match the logo brief. The wordmark is Erica One (very fat letters), the UI text Outfit; both are free fonts under the SIL Open Font License, in `ui/fonts/` with their licences. (Fredoka was the first choice but couldn't be fetched into the project; swap it in through the theme if wanted.) White and pale-cyan "ice" panels, navy text, sky-blue highlights. No orange anywhere in the UI: the beak's orange sits close to the reserved danger colour, so the UI stays clear of that whole range.
- **Why:** the toy is about to be played by people who weren't there when it was built. A first-time player needs to know which button does what at the moment it matters, not from a paragraph of notes, and the title gag sets the tone (fat is funny, and risky) before the first dive.
- **Reuse:** `GameHud` takes one penguin, so coop can have one per player. Prompts are a table (`ControlPrompts.PROMPTS`): a new verb's prompt is a line plus a condition. `GameSettings` holds anything the player chooses. One theme (`ui/theme/fat_penguin_theme.tres`) styles everything, with a type variation per kind of element.
- **Not yet:** real logo art, sound, a how-to-play page, autosave on backgrounding, button remapping, and a HUD per player for split screen.
- Proposed.

## 2026-10-05: A berg field to climb, ice tunnels, and colonies of NPC penguins

- **Change:** the movement toy grows from one berg into a berg field about 200 m across: the home floe, five new bergs, two chains of pack ice, and 25 computer penguins living in colonies on four of the bergs. See GDD §4.6, §4.10 and §8, and TUNING (Berg field, NPC penguins).
- **True to real ice:** each new berg is one of the real shapes that ice services classify (tabular, wedge, drydock, pinnacle, dome), and sits as deep as that kind really does: draft about 5 × the height above water for tabular and wedge bergs, 4 × for domes, 2 × for pinnacles, 1 × for drydocks. They're penguin-sized, 1–6 m above the water (bergy bits and small bergs), with footprints of 16–32 m, a little long for their height so there's room to walk and huddle.
- **A platformer and a maze:** each berg is a climbing puzzle built only from moves the game already has (walk, hop, slide, launch, swim), and each has its own way up:
  - **Mesa (tabular, 3 m):** sheer all round and too tall to launch onto. The one way up is its ice foot, a ramp along one long side. Waves can't wash a top this high.
  - **Wedge (4 m):** a 12° slope you swim onto and walk up, to a crest that ends in a cliff.
  - **Drydock (2.5 m):** a U-shaped berg with a lagoon 1.3 m deep (a seal can swim in, an orca can't), a shelf out of the water at the back, steps up the back wall, and an ice bridge across the mouth.
  - **Pinnacle (shelf 1 m, spire 6 m):** a low shelf you can launch onto from anywhere, and a spire in three tiers. Steps spiral round it, and each flight is harder than the last: 0.4 m (anyone), 0.7 m (energy about 50 or less), 0.8 m (about 25 or less). There's a lookout on top, a 28° chute back down, and a cave through the base.
  - **Dome (4 m):** about 22° all round, too steep to stand on, so the whole berg is one chute except a stair of 0.4 m ledges up its east side.
- **Tunnels, both kinds:**
  - **Walk-through:** the pinnacle's cave, 2.4 × 1.8 m.
  - **Swim tunnels** through the keels of the mesa (3 m down) and the wedge (2.5 m down): 2.2 m wide and 1.8 m high. A leopard seal (1.2 m across) can follow you through; an orca (2 m) can't. The mesa's is 35 m end to end, about 8 s of your 25 s of air. So a tunnel loses an orca but not a seal.
- **Pack ice, and gap hops are built:** two chains of small floes run from the home floe, one to the wedge and one to the pinnacle, with gaps of 0.5–1.4 m. Walk at a gap and you hop it if you can reach (1.5 m thin, down to 0.6 m stuffed); on your feet you stop at one you can't, as GDD §4.9 has it. The chains are a thin penguin's shortcut; a fat one swims.
- **NPC colonies:** 10 penguins on the home floe, 6 on the mesa, 5 on the pinnacle and 4 on the wedge.
  - **They huddle** in the middle of their berg and the huddle turns over the way emperor huddles do: a cold penguin on the windward edge peels off and walks round to the sheltered lee side, and a warm one in the middle stops pushing and gets moved toward the wind. Everyone takes turns on the cold edge. Sheltered, an NPC burns energy at 0.2 × the base rate; exposed, 0.6 ×.
  - **They go fishing in parties:** a hungry one (energy under 35) walks to the edge facing the nearest school and waits for others. Three go in together, like Adélies crowding at the ice edge until one goes and the rest follow. They eat until they're at 70, or for 50 s at most, then swim home to a ramp, or boost and launch onto a low edge. One knocked in swims home too. Predators hunt them the same as you, so a party is cover.
- **Predators in a field:** seals and orcas patrol round one berg at a time, and now and then head off to another one nearby (a quarter of a seal's patrol legs, a third of an orca's). A predator can't swim into water too shallow for it (it stops, as at a wall), and one pressed against ice slides along it rather than pushing head-on, which is how a seal finds a tunnel mouth. The wave only washes ice up to 1.5 m above the water.
- **Why:** routes and climbing give the ice something to do between trips, and the real shapes keep it believable. NPCs make the waddle a real crowd before there's multiplayer, and tunnels and lagoons give the seal and the orca a difference you can use.
- **Reuse:**
  - `IceBerg` (`levels/bergs/ice_berg.gd`) is the base for every berg. It builds its collision and meshes in code (`box`, `slope`, `steps`, `keel` with a tunnel through it, `frustum`) and answers what predators, fish and NPCs need to know: `reach()`, `top_height()`, `waddle_spot()`, `exits()` (ways out of the water) and `tunnels()`. A new berg is a short script. `HomeFloe` describes the original berg; `FloeChain` builds pack ice.
  - `PenguinBrain` (`actors/penguin/penguin_brain.gd`) drives an NPC through `Penguin.wish_dir`, the same input a stick gives, so NPCs move by exactly the player's rules. Its numbers are in `NpcTuning` (`tuning/npc_default.tres`).
- **Not yet:** bergs that drift, roll or calve; NPCs that bump you, or each other, on purpose; breathing holes.
- Proposed.

## 2026-10-04: Seals lie in ambush; orcas trap penguins in the water

- **The plan:** the remaining predator attacks for the movement toy. Leopard seals get one: the edge ambush. Orcas focus on trapping a penguin rather than chasing it, so they get two attacks in the water, the cut-off and the carousel, and their attacks now chain into one trap. Left for later: the seal's haul-out lunge onto the ice and its strike from below, and the orcas' strand lunge (the kill-screen lunge) and relay chase. See GDD §5.3 and TUNING, Predators.
- **Seal edge ambush:** at the end of a patrol leg (half the time), or after losing a penguin that climbed out, a seal lies in wait under the ice edge nearest a penguin standing within 10 m of it. It holds still 1.6 m out and 1.2 m down, a dark shadow under the edge, and moves along the edge if that penguin does. It lets swimmers come to it, and anyone who comes within 6 m in the water (going in, or coming home) gets a lunge after a short 0.4 s warning, instead of the usual 0.6 s. It gives up after waiting 15 s at one spot, or when nobody's near that edge any more.
  - **To beat it:** go in somewhere else. 8 m or more along the edge, it doesn't strike, and a belly-slide across the berg leaves it a long swim round. Or come home fast: boost and launch from 6–7 m out, just before you're within its reach, and you fly over it (cruising in, or launching closer, and you're caught; launching from farther out falls short).
- **Orca cut-off:** a penguin in the water 4–10 m from the ice finds the pod racing to get between it and home. The orcas form a wall of fins, 4 m apart, then close in from 7 m to 4.5 m over 5 s, with a line on the water in the danger colour that you mustn't cross. Swim at the wall and the nearest orca lunges (the usual warning). Pushed out 10 m from the ice, the penguin is handed straight to the carousel; still near the ice when the time's up, the nearest orca lunges.
  - **To beat it:** see the fins heading for the gap and race them home, or slip round the end of the wall with a boost, or dive deep under it.
- **Orca carousel:** a penguin 10 m or more from the ice gets ringed in. The orcas spread around it in a ring 10 m wide (radius), 2 m down, and circle. Then they blow a wall of bubbles that stops anyone swimming out through it (a boost still breaks through) and lifts anyone inside to the surface (no diving out), and squeeze the ring to 4.5 m over 5 s. The middle, where the slap will land, is marked in the danger colour for the last 3 s or so. One orca rises and tail-slaps it: anyone there is stunned for 1.2 s (no boost, slow turns, slow swimming). Then another lunges, with the usual warning. Real orcas herd herring this way (carousel feeding).
  - **To beat it:** get away before the bubbles go up, or boost out through them early. Inside, keep to the edge of the ring, out of the slap zone, and dodge the lunge.
- **Traps:** an attack can lead straight into others, with no cooldown in between: the wave and the ram lead into the cut-off (a penguin knocked in that swims off the edge is cut off), and the cut-off into the carousel. The 20 s cooldown comes when the whole trap ends. A trap is at most 4 attacks.
- **Shadows:** a predator within about 3 m of the surface now shows as a dark shadow on the water above it (ART_DIRECTION: predators under the surface read as shadows). It's what makes a seal lying in wait, or orcas lining up, readable from the ice.
- **Every attack can be beaten:** each new one has a counter that uses a skill the game already teaches (launching out, boosting, out-turning a big orca, diving), and a warning in the art-direction order (a shadow, then the water moving, then the danger colour).
- **Reuse:**
  - `PodAttack` now has a step for each phase (`steer`, `lined_up`, `warned`, `charged`, `escaped`, `hunt`), so an attack decides where its predators go and when each step is done. `EdgeAttack` holds what the wave and the ram share; `CutOffAttack` and `CarouselAttack` are the first attacks in the water.
  - `PodAttackTuning` gets `chains_into` (the trap's next steps) and `starts_alone`.
  - `Predator` gets `order_strike()` (a pod's strike, with the usual lunge warning), orders that hold it in place without breaking off to hunt, and `recall()`.
  - `IceEdges` (`levels/ice_edges.gd`): where the edge nearest a penguin on the ice is, and where the nearest ice is from a penguin in the water. Used by the ambush, the cut-off and the carousel.
  - `Penguin.stun()` and `Penguin.drift()` (a current in the water: the bubbles).
  - `BubbleWall`: the bubble ring and foam.
- Proposed.

## 2026-10-04: Orcas ram the ice; pod attacks are data

- **Change:** orca pods get a second attack, the ram. In playtesting the pod pushed the berg by accident and knocked the player off, and it felt right, so it's now on purpose. When a penguin stands on a floe (or within 8 m of the berg's edge facing the pod), the orcas gather 6 m out and 4 m down, rush up and ram the edge, and the ice tips toward them. A small floe tips steeply (25° for the 4 m floe): you slip onto your belly and slide off the low side into the water, where the orcas are waiting, unless you dig in (pull back) and hold on until it rights itself (2 s tipped, then 1.2 s to settle). The big berg only rocks (about 1.2°), but the jolt shoves anyone near the rammed edge toward the water. The wave is unchanged; when both attacks have a target the pod picks one at random (the ram is weighted 1.5 to the wave's 1). See GDD §5.3 and TUNING, Predators.
- **Why dig-in saves you:** on a floe there isn't time to walk off (the whole floe is the danger zone, and from its middle the edge is 2+ s away), and the water is where the orcas are. Pulling back is the answer, as it is at the bottom of the south chute. Leaving early also works: the pod takes a few seconds to gather.
- **The warning comes in the art-direction order:** dark shadows gathering under the ice edge, then the water bulging there, then the ice that will be hit marked in the danger colour (the whole floe, or an 8 × 16 m strip of the berg's edge). In the smoke test the ram hits 2.8 s after the pod has gathered, and the zone is up for about 2 s.
- **How far ice tips:** 200 ÷ radius^1.5 degrees, up to 30°. Big ice barely moves, which is also why the berg's rim only drops about 0.6 m and nobody standing 5 m in falls off.
- **Reuse:** group attacks are now data, so a new one is a script and a resource, not a new pod class:
  - `PodAttack` (`actors/predators/pod_attack.gd`): one attack's targeting, line-up and charge spots, warning visuals and strike. `WaveAttack` and `RamAttack` extend it, with shared helpers for finding a penguin near an edge, lining up off it and marking the danger zone.
  - `PodAttackTuning` (`tuning/pod_attack_tuning.gd`): the steps every attack shares (weight, warning, charge speed, hunt, cooldown), extended by `WaveAttackTuning` and `RamAttackTuning`. A pod lists the attacks it knows in `PodTuning.attacks`.
  - `PredatorPod` runs every attack through the same steps (line up, warn, charge, strike, hunt). `OrcaPod` is now just a name, and `OrcaPodTuning` is no longer used (its wave values moved to `tuning/predators/orca_wave.tres`; `tuning/orca_pod_tuning.gd` is a leftover stub that can be deleted).
  - `TippableIce` (`levels/tippable_ice.gd`): marks a piece of ice that can tip, made of one or more bodies (the berg is the ice, the plateau and the ramp). Only ice marked this way can be rammed. The movement toy marks the berg and the three floes.
- **Not yet:** ice breaking up under a ram, rams on drifting floes, and a hunger meter that makes a starving pod ram more.
- Proposed.

## 2026-10-02: Orca pods wash penguins off the ice; predators are built from shared parts

- **Change:** an orca pod (three orcas) joins the movement toy, the first piece of Prototype 2. As the GDD says, orcas don't chase in open water: on patrol the pod swims in a V and an orca only goes after a penguin in the water within 8 m. Their attack is the wave. When a penguin stands within 3 m of an ice edge facing the pod, the orcas line up side by side 14 m out with their fins showing, raise a swell, charge, and break a wave over the edge that shoves everyone in a 12 × 3 m zone toward the water. Then they hold off the edge for 6 s and go after whoever went in. See GDD §5.3 and TUNING, Predators.
- **The warning comes in the art-direction order:** fins lining up, then the swell, then the danger zone marked on the ice in the danger colour, at least 2 s before the charge. In the smoke test the wave hits 4–5 s after the pod has lined up, and walking out of a 3 m zone takes under 2 s.
- **What the wave does:** the shove works like a bump. On your feet you skid about 3 m, so you end up teetering at the edge and can still scramble back (4 energy). On your belly you go straight in. A bump during a wave stacks with it (GDD §4.5).
- **Reuse:** predators are now built from shared parts, so a new kind is mostly data:
  - `Predator`: one script for every kind. It does the swimming, sight, targeting, hunger and feeding, and the lunge with its ring and strike line. A kind is a `PredatorTuning` resource plus a scene with a model. The leopard seal and the orca both use it.
  - `PredatorPod`: groups predators, keeps them in formation and can give them orders. `OrcaPod` adds the wave on top, and the wave visual is its own `IceWave` effect.
  - `PredatorSpawn` / `PredatorSpawner`: a level lists what spawns, how many, alone or in pods, and where around the ice. The movement toy's seals and orcas are two entries.
  - `Penguin.push()`: an outside shove that reuses the bump knockback.
- **Not yet:** kill-screen lunges across the floe, the pod's hunger meter (campaign Breakup levels), waves that wash right across small floes, and real orca art.
- Proposed.

## 2026-10-02: Faster seals that catch more often

- **Playtest:** the seals were too slow to give a good chase, and didn't catch much.
- **Measured:** from 10 m behind, a seal took 8–10 s to run down a penguin swimming in a straight line, and a stuffed one usually got away inside 12 s. A penguin that turned at each warning was never caught.
- **Change:** faster everywhere: patrol 2.5 → 3.5 m/s, chase 5.5 → 6.5 m/s, acceleration 4 → 8 m/s², turn rate 75 → 85 °/s (a thin penguin still out-turns it), sight 18 → 20 m. Lunges start from 5 m (was 4), carry about 6 m (12 m/s for 0.5 s, was 11 for 0.45), catch within 1.3 m of the jaws (was 1.2) and come every 2 s (was 3).
- **The warning stays fair:** during the warning the seal now stops closing in and just matches its target's speed. It used to keep closing until 3 m, and with a faster seal that made the lunge almost undodgeable. A turn 0.2 s into the warning still dodges a lunge every time.
- **Result:** a penguin that does nothing is caught in about 5 s. One that dodges every lunge by turning usually gets caught within about 9 s anyway, because the seal keeps coming. Boosting still gets away, at 8 energy a boost. Escaping a seal now takes the ice, boosts or a tight turning fight. What a catch costs is unchanged: you're eaten and respawn on the ice. See TUNING, Predators.
- Proposed.

## 2026-10-01: Leopard seals hunt the movement toy; a catch means you're eaten

- **Change:** the first predator from Prototype 1, the leopard seal, is in the movement toy (two of them). It patrols a loop 4 m off the ice edge, swinging past schools, and hunts the most tempting penguin it can see using the targeting rule (GDD §5.1: size, noise and closeness, switching only for a 25% better target). See GDD §5.3 and TUNING, Predators.
- **What it can see:** penguins in the water within 18 m, but penguins out of the water only within 6 m (the edge ambush), and never through ice. Up on the plateau you're out of reach.
- **Chase and lunge:** it chases at 5.5 m/s, faster than a cruising penguin (4–4.6) and slower than a boost (9–11). A thin penguin (120 °/s) out-turns it (75 °/s); a stuffed one (66 °/s) can't. In lunge range it lines up a strike: for 0.6 s the lock-on ring flashes and a line marks exactly where the lunge will go, and the seal holds off at 3 m instead of closing in. Then it dashes along the line, catching anything near its jaws. Turning off the line or boosting dodges it; doing nothing gets you caught. A lunge reaches about a metre onto the ice, so standing right at the edge is dangerous and 4 m in is safe.
- **Hunger:** a seal gets hungrier all the time. It hunts penguins and ignores fish until it's starving; a starving seal goes to the nearest school and eats fish until it's fed, though it still lunges at a penguin that swims right up to it. That's the readable window to slip past. After eating a penguin it's sated (slow and harmless) for 8 s.
- **A catch means you're eaten** (in the movement toy): a puff of feathers, a splash, and you're back at your spawn point with starting energy. This settles GDD §11's "single-player catch" question for the toy only; the campaign's "fat is armor" rule (§8) stays proposed.
- **Bump noise is built** now that something listens: 0.4 for a soft bump, 1.0 for a hard one, fading over 2 s. A brawl near a seal draws it.
- **Why the warning works this way:** a first version aimed the lunge at the end of the warning and kept closing in during it. In headless trials no reaction could dodge that, which breaks "every death should feel like I misjudged that." Locking the strike line at the start of the warning and holding off fixed it: with a 0.2 s reaction, doing nothing was caught every time and turning or boosting escaped every time. React late (0.45 s) and only a boost still works.
- **Not yet:** breathing holes (no holes yet), bubble trails, chum, spilled fish from eaten penguins, and real seal art.
- Proposed. Numbers in TUNING (Predators).

## 2026-10-01: More fish, closer to the ice; fish value stays at 10

- **Playtest:** there wasn't enough food. Trips came up empty.
- **Cause:** schooling (below) clumped the same number of fish into fewer, farther spots. From the ice edge the nearest fish went from ~11 m to ~20 m away on average, and up to 47 m on the worst side, against ~20–25 m of underwater visibility.
- **Change:** 12 schools instead of 8, one in each slice of the ring around the berg, so every side has one, and all of them 6–20 m off the ice edge. Bigger schools (silverfish 8–14, lanternfish 8–12, icefish 4–6) and 16 loose fish instead of 12. That's about 130 fish instead of 72. From the edge, the nearest fish is now ~13 m away on average (22 m at worst), and about 21 fish are within 25 m, three times as many as before. See TUNING, Fish.
- **Why not make fish worth more:** fish value is load-bearing. The overfill threshold (two fish from a fresh start), fish spills, the chum cost and the food-pulse scarcity check are all counted in fish, so a bigger number would let one school fill you twice over and take the decision out of a trip. The problem was reaching food, not what it was worth. If trips still come up short, fish value is one number in `penguin_tuning_default.tres`, but those checks would need redoing.
- **Cost:** fish more than 40 m from the camera, lost in the fog, now update every 4th physics frame. The ~130 fish cost about the same as the 72 did.

## 2026-10-01: Fish come in species and school with their own kind

- **Change:** fish now come in three species based on real Antarctic forage fish (Antarctic silverfish, lanternfish, mackerel icefish), and they school by species. A fish is pulled toward fish of its own kind within school range (6 m), keeps a little personal space, matches their heading and stays near a home spot. It ignores every other species, so schools never mix, even when two kinds swim through each other. See GDD §4.11.
- **Schools stay schools:** school mates slowly share one home spot, so a school that forms stays formed. A lone fish that drifts into range of its own kind joins for good, two schools of the same kind that meet merge, and an eaten fish comes back beside its school.
- **More fish start in schools:** the movement toy spawns 8 single-species schools (every species gets at least one) and 12 loose fish, instead of 4 schools and 40 loose fish. About 85% of the fish are now in a school, up from about 40%.
- **Why:** real forage fish school with their own kind (a fish that looks different from its school mates is the easiest one for a predator to pick out), and schools are the raw material for food pulses and bait balls (§4.3). Clumped food also turns a trip into a choice of which school to hit, instead of a scatter of single pickups.
- **Kept the same:** every fish is still worth +10 energy, and the eat radius is the same for every species. Species differ only in look, size, speed, how tight they school and how deep they swim. Fish don't react to penguins yet.
- **Cost:** a schooling fish costs about 7–8 µs per physics frame on a desktop CPU, against about 2 µs for the old circling fish (about 0.5 ms for the toy's 72 fish). Check it on a phone; if it's too much, move the swarm maths into one manager or update steering at 30 Hz.
- Proposed. Numbers in TUNING (Fish).

## 2026-10-01: Faster on land, slicker ice, and a brake

- **Playtest:** moving on the ice felt slow, and slides wanted to go further.
- **Change:** walking, the flop and the mid-slide flipper push are 1.5× faster (walk 1.8 m/s, flop 7.5 m/s, push +2.25 m/s; walk acceleration scaled to match). Ice friction drops from 0.6 to 0.45 m/s², so a flop from standing glides ~62 m, further than the berg is wide.
- **Brake:** since a slide could no longer be stopped on the ice, pulling the stick back mid-slide now digs your feet in (+6 m/s²), stopping a full-speed slide in about 4 m. It was already listed as the fix if slides felt too all-in (GDD §4.5).
- **Cost:** full-speed bumps knock a standing penguin about twice as far (TUNING, bump checks). Fine on the big berg, but the 8 m kill-screen floe will need a bigger floe, more grip or a lower knockback cap when it's built.

## 2026-10-01: Energy has a floor for now; an exhausted state comes later

- **Playtest:** at zero energy the penguin couldn't flop or boost, so it crawled at walking speed on the ice and couldn't launch out of the water. Exhaustion was fun, but a hard zero made it too hard.
- **For now:** the cold can't drain you below an energy floor (20), and spending below it recovers up to the floor at 4 per second. An empty penguin is thin and weak but can always flop or boost again within a couple of seconds.
- **Cost:** it takes some pressure off the "eat early, then hide" strategy, since a camper reaches the kill screen with about three dodges instead of none (TUNING, energy checks).
- **Later:** design a real exhausted state to replace the floor (GDD §11, open question 10; ROADMAP Prototype 1). It should feel bad enough to avoid, never strand you, and bring back the pressure on campers.

## 2026-10-01: The iceberg is a 3D plateau: slide down, hop up

- The iceberg gets raised tiers instead of being one flat disc. The ways down are **chutes**, too steep to stand on, so you slide, and gravity speeds you up. The ways up are **ledges** you hop by walking into them. Hop height shrinks as you fatten, so tall steps are shortcuts only thin penguins can take. See GDD §4.9 and §4.10.
- **Why:** it puts the "full belly, bad jumper" rule from the thin-ice decision (below) on every trip, gives slides somewhere to build speed (so harder bumps), and adds ring-outs onto a lower tier as well as into the water.
- **Built in the Prototype 0 movement toy, together with bumping:** a plateau with two chutes and two staircases, slope physics for slides, automatic hops, and bumper-car collisions against dummy penguins (flop cost, mass, feet vs. belly, skid, tumble, teeter and scramble, spin-out, knockback immunity, chain hits, fish spills). Not built yet: bump noise and credit (need predators), crowd mass (needs the waddle), hops across gaps (need ice breakup).
- Locked as intent; the layout and numbers are proposed.

## 2026-10-01: PvP is physical: bumping, like bumper cars

- Sliding (or boosting) into rivals is now the main PvP move. There's no attack button: weight and speed decide who goes flying. See GDD §4.5.
- **This updates "PvP is indirect"** in "The core is swimming, evasion and greed" (below). Luring predators onto rivals stays, and bumps never kill directly. They move rivals toward predators, so predators still do all the killing.
- **Why:** the bump works at every scale of the game. You can knock a rival off the food, back into the water at the ice edge where the seal waits, or onto a lunge line in the kill screen. It plugs straight into fat vs. thin (fat is heavy and hard to move; thin can knock fish loose from overfed penguins), and it needs no extra button on a phone.
- The separate body-check/shove ability is folded into this. Its energy cost moves to the flop that starts a slide.
- **No new button:** bumping uses the controls from the Godot entry below (tap to belly-slide, tap again for a flipper push).
- Locked as intent; the details in GDD §4.5 are proposed.

## 2026-10-01: Thin ice is a title-screen gag, not a mechanic

- Reverses the follow-on proposal in "Renamed from 'Waddle' to 'Fat Penguin'" (below). In play, ice never breaks under a penguin's weight.
- The logo stays. The title screen acts it out: feed the penguin until it falls through.
- **Instead, a full belly makes you a bad jumper:** lower launches out of the water (already in the GDD) and shorter hops across the cracks that open as the ice breaks up. Those gaps keep the old idea of shortcuts only thin penguins can take.
- **Why:** energy has no meter, so a hard weight threshold for falling through would be hard to read from body size. A jump that shrinks smoothly as you fatten reads naturally and still gives thin penguins their shortcuts.

## 2026-10-01: Godot 4.7.2 + GDScript + Mobile renderer; Prototype 0 started

- **Godot 4.7.2** is the current stable release. 4.8 is still in development builds.
- **GDScript:** fastest to iterate in, with the most reliable mobile export.
- **Mobile renderer:** matches the target platform. It can be switched later if the PC look needs more.
- **Controls:** one thumb steers (a floating stick on the left half of the screen), and a tap on the right half boosts in water or belly-slides on ice. Keyboard and gamepad map to the same actions.
- **Swimming moves forward automatically:** penguins don't hover in water, and auto-forward keeps the controls to steering plus one button.
- **Low exits:** with a 1 m ice edge, a penguin with no energy can't launch out of the water, so every map needs a low exit (see GDD §4.10).

## 2026-10-01: Engine is Godot 4 (3D)

The project will be built in Godot 4 with 3D graphics. Version, scripting language and renderer are still to be confirmed.

## 2026-10-01: Renamed from "Waddle" to "Fat Penguin"

- The new name puts the core greed mechanic front and center.
- **Logo:** an overstuffed penguin falling through cracking ice.
- "Waddle" stays as the in-game word for the group of penguins on the ice (the safe zone).
- **Follow-on proposal:** thin ice that fat penguins fall through (GDD §4.5), so the logo shows a real mechanic.

## 2026-10-01: No camping; when to leave the waddle is the core decision

**Problem:** with storable energy, food front-loaded at the start and a waddle that was safe for free, the best strategy was to eat as much as possible right away, hide until the end, and dodge. Falling behind on that first trip was effectively a loss.

**Decision:** balance the game so every player has to refuel at least once, and make the timing of each departure the main strategy. The fixes:

- **Energy runs out:** a full belly lasts under half a round, and overfilling burns off faster.
- **Food comes in pulses:** timed food events that grow bigger and more dangerous, ending with the last meal before the kill screen.
- **The waddle costs something:** it still drains energy, and the huddle rotates you out to the edge.
- **Comebacks are possible:** predators target fat penguins first, and eaten penguins spill fish.

## 2026-10-01: Single-player levels are 5–10 minutes, with the kill screen only in later levels

- Single player is the longer, sit-down mode; multiplayer is the quick one.
- Last standing doesn't apply in single player, so each level has its own goal (Journey, Feast, Feed the chick, Hold out, Breakup).

## 2026-10-01: Food is energy, last penguin standing wins, and the round ends in a kill screen

- Food is the only resource. It fuels everything, and more of it makes you clumsier.
- Multiplayer win condition: **last penguin standing**. Bringing fish back to the chick is dropped from multiplayer (it stays as a campaign level type).
- **Kill screen:** the ice shrinks to a small floe that predators can lunge across, so the round always ends.

## 2026-10-01: Greed slows everyone, penguins and predators alike

- Carrying more food makes a penguin slower and clumsier.
- A predator that has just eaten is sated and sluggish. This gives survivors a breather and a risky chance at the spilled fish.

## 2026-10-01: Multiplayer rounds under 5 minutes, about 2 minutes on average

Built for short mobile sessions.

## 2026-10-01: The core is swimming, evasion and greed

- The original concept (gathering fish to meet a quota on a shrinking iceberg) was a list of pressures with no real actions for the player.
- **The fix:** build the game around one action, swimming, with greed and evasion as the decisions that shape it.
- **PvP is indirect:** luring predators onto other players instead of attacking them.

## 2026-10-01: Roadmap approved

Four prototypes, in order: movement toy → energy loop with a leopard seal → shrinking ice, orcas, kill screen and coop → free-for-all PvP. Asymmetric mode comes later. See [ROADMAP.md](ROADMAP.md).
