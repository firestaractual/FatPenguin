# Fat Penguin — Tuning Values

Last updated: 2026-10-05

**Every number here is a starting guess for playtesting.** Change them freely, but keep this file in step with the game.

**The live copy is in Godot:** `tuning/penguin_tuning_default.tres` (the class is `tuning/penguin_tuning.gd`). Edit the values in the Inspector, then copy the ones that work back here.

**In the game so far (Prototype 0, plus the leopard seal from Prototype 1):** base and overfill drain, fish value, boost, flop and scramble costs, fat vs. thin, movement, slopes and hops (including hops across gaps), bumping (except bump credit), bump noise, air, fish schooling, the berg field (its bergs, tunnels and pack ice), NPC penguins (huddling and fishing parties), the leopard seal (with its edge ambush), and the orca pod with its wave, ram, cut-off and carousel (from Prototype 2). Waddle drain, the other action costs, food pulses, the orcas' kill-screen lunges, rounds and campaign values arrive with later prototypes.

Units: energy runs from 0 (empty) to 100 (full). Time is in seconds, distance in meters.

---

## Energy

| Value | Start | Notes |
|---|---|---|
| Starting energy | 50 | Everyone starts half full, so nobody can skip the first pulse for free |
| Base drain (water or open ice) | 1.5 /s | |
| Drain at the waddle's edge | 1.2 /s | |
| Drain at the waddle's center | 0.8 /s | |
| Center time limit | 12 s | After that, the huddle rotates you to the edge |
| Overfill threshold | 70 | |
| Overfill drain multiplier | ×2 | Applies to any drain above the threshold |
| Energy floor | 20 | The cold can't drain you below this. A stand-in until there's an exhausted state |
| Recovery below the floor | +4 /s | Spend below the floor and it comes back up to the floor: a flop in under a second, a boost in about 2 s |
| Fish value | +10 | |
| Krill mouthful (optional) | +3 | Small, frequent food to fill the gaps |

**Check, how long a full belly lasts:** 100→70 at 3.0/s takes 10 s, then 70→20 (the floor) at 1.5/s takes 33 s, for about **43 s** with no boosting. That's well under half of the 2:00 before the kill screen. ✓

**Check, can you hide in the waddle after eating early?** Eat to full by about 0:20, then stay in the waddle. Even in the center the whole time (which rotation prevents), you'd hit the floor by about 1:40 and reach the kill screen with 20 energy: about three dodges, against up to 100 for whoever ate the last meal. ⚠ Refuelling still wins, but the floor takes some pressure off campers. Revisit when the exhausted state replaces the floor (DECISIONS, 2026-10-01).

## Energy costs

| Action | Cost |
|---|---|
| Bubble boost (including launching onto the ice) | 8 |
| Kill-screen dodge (quick sidestep on ice) | 6 |
| Flop (starting a belly-slide on purpose; this is how you bump) | 3 |
| Edge scramble (saving yourself from a teeter) | 4 |
| Chum drop | 10 (one fish) |

Landing on your belly after a launch is free, since the boost already paid for it. The bump itself, the mid-slide flipper push and hopping are free.

## Fat vs. thin handling

Each value scales in a straight line from energy 0 to energy 100. Swap in curves later if needed.

| Value | At 0 energy | At 100 energy |
|---|---|---|
| Turn rate | ×1.00 | ×0.55 |
| Acceleration | ×1.00 | ×0.60 |
| Cruise top speed | ×1.00 | ×1.15 |
| Boost top speed | ×1.00 | ×1.25 |
| Launch height | ×1.00 | ×0.65 |
| Body size (mostly width) | ×1.00 | ×1.60 |
| Collision radius | ×1.00 | ×1.30 |
| Mass (for bumps) | ×1.00 | ×2.00 |
| Hop height (up ledges) | ×1.00 | ×0.55 |
| Hop distance (across gaps) | ×1.00 | ×0.40 |
| Get-up time (belly to feet) | ×1.00 | ×2.00 |

Nothing has a hard threshold: ice never breaks under a penguin's weight (see DECISIONS, 2026-10-01).

**Check, hops across gaps** (crack widths are under Multiplayer round; the pack ice gaps are under Berg field): a thin penguin hops 1.5 m and clears every crack. At the starting 50 energy it hops 1.05 m, clearing up to the 1.0 m cracks. At the overfill threshold (70) it's 0.87 m, and when full it's 0.6 m, so an overfed penguin only clears the narrowest cracks. ✓

## Movement (base values for a thin penguin)

| Value | Start | Notes |
|---|---|---|
| Swim cruise speed | 4.0 m/s | |
| Boost peak speed | 9.0 m/s | |
| Boost duration | 0.8 s | |
| Boost cooldown | 0.5 s | |
| Porpoising starts at | 6.0 m/s | Leaps out of the water at speed |
| Walk speed (on ice) | 1.8 m/s | The slow penguin waddle. Called "walk" in code so it isn't confused with the waddle safe zone |
| Belly-slide starting speed | 7.5 m/s | A flop from standing. Slows down through friction |
| Belly-slide ice friction | 0.45 m/s² | A flop from standing glides ~62 m, further than the berg is wide |
| Dig-in brake | +6.0 m/s² | Pull the stick back mid-slide. Stops a 7.5 m/s slide in ~4.4 m |
| Get-up time (belly to feet) | 0.4 s | After the slide stops; you're still a puck until you're up |
| Skid friction on your feet | 2.5 m/s² | How quickly a standing penguin stops after a shove |
| Steepest slope you can stand on | 14° | Steeper is too slippery: you slip onto your belly and slide |
| Slope gravity on slides | ×1.0 | Real gravity along the slope: speeds you up going down, slows you going up |
| Slide top speed | 18 m/s | |
| Hop height | 0.9 m | Walk into a ledge this high or lower and you hop it. Taller (up to 1.6 m) and you try and fall short |
| Hop forward speed | 1.6 m/s | |
| Hop cooldown | 0.3 s | After landing |
| Hop distance | 1.5 m | Walk at a gap this wide or narrower and you hop it; on your feet you stop at a wider one. You look 3 m ahead (and 25° to each side) for ice across a gap |
| Ice edge height above water | 1.0 m | |
| Speed needed to launch onto ice | 7.0 m/s | A boost can reach it; cruising can't |

## Movement feel (added with Prototype 0)

| Value | Start | Notes |
|---|---|---|
| Swim acceleration | 6.0 m/s² | Getting up to cruise speed |
| Swim drag | 5.0 m/s² | A boost bleeding back down to cruise speed |
| Swim turn rate | 120 °/s | Scaled by the fat turn multiplier |
| Max swim pitch | 75° | |
| Pitch return | 25 °/s | Nose drifts back to level with no up/down input |
| Max pitch at the surface | 50° | How far the nose can tilt up while cruising along the top, to aim a launch |
| Speed kept on water entry | 80% | |
| Walk acceleration | 9.0 m/s² | Scaled with walk speed so it reaches it just as quickly |
| Walk turn rate | 300 °/s | Penguins walk where they face, so fat ones feel the wider turns |
| Belly-slide turn rate | 45 °/s | |
| Belly-slide grip | 1.5 | How fast the slide follows the direction you're facing |
| Belly-slide flipper push | +2.25 m/s | Tap action mid-slide; 0.4 s cooldown |
| Slide stops at | 0.8 m/s | Stands back up below this speed |
| Landing speed that becomes a slide | 2.5 m/s | Horizontal speed when landing |
| Gravity | 9.8 m/s² | |
| Air steering | 30 °/s | |

**Check, launching onto the 1 m ice edge:** a thin penguin needs to cross the surface rising at about 5.6 m/s to clear the edge. Cruising at 4 m/s can't do it; a boost (9 m/s) at 40° or steeper can. The headless smoke test confirms the boost-and-launch route works.

## Bumping

Knockback follows a simple collision: the target's push-off speed is (1 + bounciness) × hitter mass ÷ (hitter mass + target mass) × closing speed, then multiplied by grip if the target is on its feet. The prototype does this by hand in `Penguin._bump()` rather than with rigid bodies, so these numbers are exactly what you get.

| Value | Start | Notes |
|---|---|---|
| Bump speed | 2.0 m/s closing | Below this, penguins just push each other |
| Hard-bump speed | 4.0 m/s closing | Causes spin-outs (side hits) and fish spills |
| Bounciness | 0.85 | 1.0 would be perfect billiard balls. Was 0.8 |
| Bump knock | ×1.5 | Penguin-on-penguin bumps hit this much harder than the collision maths alone (DECISIONS, 2026-10-08: easier to dislodge). Outside shoves (waves, rams, whales) aren't scaled |
| Grip on your feet | ×0.5 knockback | Penguins on their belly take ×1.0 |
| Skid friction (knocked on your feet) | 2.5 m/s² | |
| Tumble friction (knocked onto your belly) | 2.0 m/s² | Higher than a normal slide (0.45), so one hit can't send someone across the whole iceberg |
| Max knockback speed | 6.0 m/s | |
| Knockback in water | ×0.35 | Drag soaks it up; water bumps are short shoves (×1.5 for a bump) |
| Water drag on knockback | 6.0 m/s² | |
| Chain transfer | 50% | Share of a hit passed on when a knocked penguin hits another |
| Crowd mass | Masses of all touching penguins add | Why nobody gets knocked out of the middle of the waddle. Not built yet (no waddle) |
| Spin-out | 0.5 s | No steering or dodging |
| Knockback immunity | 0.75 s | After any bump. No juggling |
| Teeter window | 0.6 s | Penguins on their feet only; belly-sliders go straight in |
| Fish spill | 1 fish per hard bump | Only from penguins above the overfill threshold (70) |
| Bump noise | 0.4 soft, 1.0 hard | Added to both penguins' noise score (capped at 1); fades over 2 s. Predators count it when picking a target |
| Credit window | 5 s | A predator catch this soon after a bump credits the bumper. Not built yet |

**Check, how far does a bump send you?** A full-speed slide (a 7.5 m/s flop) into a penguin that isn't moving, on ice:

| Hitter → target | Target on its feet | Target on its belly |
|---|---|---|
| Thin → thin | ~5.4 m (was ~2.3) | ~9 m (capped) |
| Fat → thin | ~7.2 m (capped; was ~4.1) | ~9 m (capped) |
| Thin → fat | ~1.1 m (was ~1.0) | ~5 m |
| Fat → fat | ~5.4 m (was ~2.3) | ~9 m (capped) |

The smoke test launches its hitters at a fixed 5 m/s (from 3 m away, so they arrive a little slower) and measures thin → thin on its feet **2.2 m** (was 0.9), fat → thin on its belly **8.9 m**, thin → fat on its feet **0.96 m** (was 0.4). ✓

- The kill-screen floe is ≈8 m across, so its edge is ~4 m from the middle. Since the playtest (DECISIONS, 2026-10-08) a full-speed hit from anyone puts a standing penguin of the same size or smaller in the water from the middle of it: knocks are meant to be substantial. Standing still beats lying down by far, and a fat penguin is hard to shift. ⚠ Playtest whether standing is now too weak a defense on the big berg.
- A lunge line only needs a ~1 m shove, which any full-speed hit gives. ✓
- A thin penguin moves a standing fat one ~1 m. Its main tool against fat is still the fish spill. ✓

**Check, sliding on the kill-screen floe:** a missed 7.5 m/s slide glides ~62 m if you let it, so on the 8 m floe a miss ends in the water unless you dig in: the brake stops it in ~4.4 m (the smoke test measures 4.3). A hit soaks up the hitter's speed instead. After a full-speed hit the hitter is left with ~0.75 m/s (thin on thin, fat on fat) or bounces back (thin on fat), and stops almost at once. Fat on thin is the exception: the fat penguin keeps sliding at 3 m/s for about another 9 m, so it has to dig in too. ✓ A miss means braking hard or swimming.

### Queasy (a sick fish)

In `tuning/penguin_tuning.gd` (the Queasy group; not overridden in `penguin_tuning_default.tres`).

| Value | Start | Notes |
|---|---|---|
| Lasts | 6 s | |
| Boost and belly-slide | None | |
| Speed | × 0.55 swimming and walking | |
| Turn rate | × 0.5 | |
| Heading wander | up to 40 °/s | A slow sway, gentler than dazed |
| Throws it back up | 1 s after eating | The fish gives nothing; you're 3 energy down instead |

### Stunned (an orca's tail slap)

The live values are in `tuning/penguin_tuning_default.tres` (the Stunned group). How long you're stunned comes from the attack (the carousel: 1.2 s).

| Value | Start | Notes |
|---|---|---|
| Boost | None | |
| Turn rate | × 0.35 | A thin penguin turns 42 °/s, slower than an orca |
| Swim speed | × 0.6 of cruise | 2.4 m/s thin |

### Dazed (a whale's body, a humpback's scoop)

Dazed is stunned (above, for the same time) plus a heading that wanders. `daze_drift_deg` is in `tuning/penguin_tuning.gd` (the Dazed group); how long and how hard come from the whale (`SwimmerTuning`, the Body group, in each whale's `.tres`).

| Value | Start | Notes |
|---|---|---|
| Heading drift | up to 110 °/s | A wobble, not a spin: it swings both ways and eases off in the last 0.5 s. A third of it pitches you up and down too |
| Orca body | 6 m long, 0.9 m thick; 1.8 s dazed, shoved off at 6 m/s | The shove is a bump's (water takes some of it). The orca then strikes at once (`strikes_when_bumped`) |
| Humpback body | 12 m long, 1.5 m thick; 2.0 s dazed, shoved off at 7 m/s | Not the penguin it's guarding |
| Humpback scoop | 2.5 s dazed | Thrown up at 7 m/s and out at 4 m/s, and a fish comes back up |
| The same whale again | Not within 1 s | |

## Plateau (movement toy)

The iceberg in the movement toy has a plateau on top (`levels/movement_toy/ice_plateau.gd`; every value is editable in the Inspector).

| Value | Start | Notes |
|---|---|---|
| Plateau height | 2.0 m | Above the main ice (which is 1.0 m above the water) |
| Top | 16 × 12 m | |
| South chute | 18°, 6 m wide | Long and gentle |
| West chute | 28°, 5 m wide | Short and steep |
| East steps | 4 × 0.4 m, 1.2 m deep | Anyone can hop these |
| North steps | 2 × 0.67 m, 1.4 m deep | Thin penguins only |
| Everywhere else | 2.0 m sheer drop | |

**Check, who can climb which steps:** hop height is 0.9 m × (1 − 0.45 × fatness), and a hop needs 5 cm to spare. Full (100): 0.50 m, clears the 0.4 m east steps. ✓ The 0.67 m north steps need energy **45 or less**, so you start the round just too heavy for them and get light enough after a trip or two. ✓

**Check, chute speeds:** slope gravity is 9.8 × sin(angle), minus 0.45 slide friction. The south chute (18°, 6.5 m long) adds 2.6 m/s²: walking in at 1.8 m/s you leave the bottom at ~6.1 m/s, and flopping in at 7.5 m/s you leave at ~9.5 m/s. That glides ~100 m, and the berg's edge is 26 m away: the south chute shoots you into the sea unless you dig in. ✓ The west chute (28°, 4.3 m long) adds 4.2 m/s² and leaves you at ~9.6 m/s from a flop.

**Check, a chute is a bump booster:** a 9.5 m/s slide off the south chute is a hard bump (≥ 4 m/s) on anyone at the bottom, with knockback capped at 6 m/s.

## Berg field (movement toy)

Each berg is a script in `levels/bergs/` (the base class is `levels/bergs/ice_berg.gd`), and every value is editable in the Inspector. The berg rebuilds itself as you change them. They sit round the home floe (the original berg, 60 m across and 1 m high) in a field about 200 m across.

| Berg | Kind (draft) | Top | Above water | Keel | Way up | Also |
|---|---|---|---|---|---|---|
| Mesa | Tabular (5 ×) | 32 × 22 m | 3 m | 15 m | The ice foot: an 11° ramp, 3 m wide, along one long side | A swim tunnel through the keel. Colony of 6 |
| Wedge | Wedge (5 ×) | about 30 × 16 m | 4 m at the crest | 20 m | Its 12° slope, from 1 m under the water to the crest | A 6 m crest, then a cliff. A swim tunnel under the crest. Colony of 4 |
| Drydock | Drydock (1 ×) | two towers 5 × 20 m, 6 m apart | 2.5 m | 2.5 m | Up the lagoon, onto a 10° shelf at the back, then 0.4 m steps up the back wall | The lagoon is 1.3 m deep. A bridge 2.5 m wide spans the mouth |
| Pinnacle | Pinnacle (2 ×) | a 26 m shelf; tiers 10, 7 and 4 m across | shelf 1 m; tiers 3, 4.4 and 6 m | 12 m | Launch onto the shelf anywhere, or an 11° ramp on the west | Spiral steps up the spire, a 28° chute down from the lookout, a cave. Colony of 5 |
| Dome | Dome (4 ×) | 28 m across at the water, 8 m on top | 4 m | 16 m | A stair of 0.4 m ledges up the east side | About 22° everywhere else: one big chute |
| Home floe | Floe | 60 m across | 1 m | – | Launch anywhere, or the ramp | The plateau. Colony of 10 |

| Spire flight | Steps | Who can hop it |
|---|---|---|
| Shelf to tier 1 (east) | 5 × 0.4 m | Anyone |
| Tier 1 to tier 2 (north ledge) | 2 × 0.7 m | Energy about 50 or less |
| Tier 2 to the lookout (west ledge) | 2 × 0.8 m | Energy about 25 or less |

The two higher flights run along the 1.5 m ledges round the spire, so you walk the ledge and hop each step as you come to it.

| Tunnel | Size | Where |
|---|---|---|
| Mesa swim tunnel | 2.2 m wide × 1.8 m high, 35 m end to end | Through the keel along its length, 3 m down |
| Wedge swim tunnel | 2.2 × 1.8 m, about 16 m | Through the keel across the berg under the crest, 2.5 m down |
| Pinnacle cave | 2.4 × 1.8 m, 10 m | Through the spire's first tier from north to south, at shelf level |
| Drydock lagoon | 6 m wide, 1.3 m deep | From the mouth to the shelf |

| Pack ice | Gaps (in order from the home floe) | Floes |
|---|---|---|
| East chain, to the wedge | about 0.6 off the home floe, then 0.5, 0.9, 1.2, 0.6, 1.4, 0.8, 1.0, 0.7 m | 9 floes about 6 m across, 0.4–0.8 m high |
| West chain, to the pinnacle | about 0.6 off the home floe, then 0.6, 1.0, 0.5, 1.3, 0.8, 1.1, 0.6, 1.4, 0.9 m | 10 floes about 5 m across, 0.4–0.8 m high |

Each floe is 2 m deep and tips when an orca rams it, like the original three floes.

**Check, true to real bergs:** the smoke test measures each berg's height above water and its keel: tabular 1:5.0, wedge 1:5.0, pinnacle 1:2.0, dome 1:4.0, drydock 1:1.0, and none taller than 6 m. ✓

**Check, a way out of the water onto every berg:** a boost lifts you about 1.7 m, so the mesa (3 m), the wedge's crest (4 m), the dome (4 m) and the drydock (2.5 m) need their ramp, slope, stair or shelf; the home floe and the pinnacle's shelf (1 m) take a launch anywhere. The smoke test gets a penguin out of the water by each berg's way up (6 ways). ✓

**Check, who reaches the lookout:** hop height is 0.9 m × (1 − 0.45 × fatness), and you need a hop at least as tall as the step. The smoke test walks penguins up the spiral: at energy 10 you reach the lookout, at 37 you get to tier 2 and no higher, and at 80 only tier 1. ✓

**Check, tunnels sort the predators:** a tunnel 1.8 m high fits a leopard seal (1.2 m across) but not an orca (2 m), and the lagoon's 1.3 m of water is too shallow for an orca. The smoke test sends a seal and an orca after a penguin through the mesa tunnel (the seal gets through, the orca doesn't get 2 m in) and both into the lagoon (the seal swims 5–7 m in; the orca's middle gets no farther than the mouth). ✓

**Check, air in the long tunnel:** 35 m at the 4 m/s cruise takes about 9 s of your 25 s of air. In the smoke test a penguin comes out with 17 s left. Boosting through is quicker, but no use with a seal behind you. ✓

**Check, pack ice is a thin penguin's route:** a thin penguin (1.5 m hops) crosses the whole east chain. At the starting 50 energy (1.05 m) you stop at the 1.2 m gap; stuffed (0.6 m) you get two floes out and stop at the 0.9 m gap, dry. The smoke test checks the thin and stuffed cases. ✓

## Air

| Value | Start |
|---|---|
| Time underwater | 25 s |
| Time to refill at the surface | 2 s |

## Fish

Each species is a resource in `tuning/fish/` (the class is `tuning/fish_species.gd`). Edit them in the Inspector, then copy the values that work back here. A fish is pulled only by fish of its own species, so schools never mix.

| Value | Silverfish | Lanternfish | Icefish | Notes |
|---|---|---|---|---|
| Spawn weight (abundance) | 3 | 2 | 1 | Relative chance a school or loose fish is this species |
| School size | 8–14 | 8–12 | 4–6 | |
| Spawn depth | 1–6 m | 4–8 m | 2–8 m | Below the surface |
| Model size | ×1.0 | ×0.8 | ×1.4 | Looks only: the eat radius (0.6 m) is the same for all |
| Cruise speed | 0.6 m/s | 0.8 m/s | 0.5 m/s | Each fish ±15%. A cruising penguin does 4 m/s, so anyone can catch any fish |
| Max steering | 1.5 m/s² | 1.8 m/s² | 1.2 m/s² | |
| Wander | 0.4 m/s² | 0.5 m/s² | 0.3 m/s² | A slowly turning random nudge |
| School range (swarm pull reach) | 6 m | 6 m | 6 m | School mates closer than this pull together; farther apart they ignore each other |
| Cohesion | 0.6 | 0.5 | 0.35 | Pull toward the middle of school mates in range, m/s² per metre |
| Alignment | 1.0 /s | 1.2 /s | 0.8 /s | How hard a fish matches its school mates' heading |
| Personal space | 0.5 m | 0.5 m | 0.9 m | Fish push apart inside this |
| Separation | 3.0 | 3.0 | 3.0 | Push at zero distance, m/s² |
| School mates followed | 7 | 7 | 7 | Nearest ones only, like real schooling fish |
| Roam radius | 4 m | 4 m | 4 m | From the home spot before being pulled back |
| Home pull | 0.3 | 0.3 | 0.3 | m/s² per metre past the roam radius |
| Home merge rate | 0.1 /s | 0.1 /s | 0.1 /s | School mates slowly share one home spot, so a school that forms stays formed |
| Fish value | +10 | +10 | +10 | Same for every species for now (GDD §11) |
| Respawn after being eaten | 8 s | 8 s | 8 s | Comes back beside its school |

**Movement toy spawning** (`levels/movement_toy/movement_toy.gd`): 28 schools (was 20) round the bergs of the field, more round the bigger ones (every species gets at least one, the rest by abundance), 6–18 m off a berg's edge; 36 loose fish (was 24) 6–40 m off. About 300 fish in all. 10% of them are sick (`sick_fish_share`). Plus 8 krill swarms 4–20 m off a berg's edge and 6 squid 8–30 m off (see below).

**Sick fish** (`Fish.sick`): 10% of the toy's fish. Sickly yellow-green, bloated (×1.15 wide, ×1.3 deep), three dark blotches, listing 65° on their side and rocking, swimming at 0.55 × their species' speed with a twitch about every 1.7 s. Eating one: queasy (see Queasy). NPC penguins choose healthy fish (`Fish.nearest_in_school(..., healthy_only)`); predators don't care.

**Check, do schools hold together?** Measured headless over 2 minutes: schools keep their size, the nearest school mate sits ~0.52 m away (personal space 0.5 m), and school mates swim almost exactly the same way (polarisation 0.99). The smoke test measures the widest fish of a 6-fish school **0.7 m** from its middle after 15 s. ✓

**Check, is there food within reach?** Measured from points all around the ice edge, 2 m down. Underwater fog hides things past ~20–25 m.

| Layout | Fish | Nearest fish (average) | Nearest fish (worst spot) | Fish within 25 m |
|---|---|---|---|---|
| Before schooling: 4 schools, 40 loose | 64 | 11 m | 23 m | 6 |
| First schooling: 8 schools anywhere, 12 loose | 72 | 20 m | 47 m | 7 |
| Now: 12 schools spread around the edge, 16 loose | 131 | 13 m | 22 m | 21 |

The first schooling layout clumped the same food into fewer, farther spots, so some stretches of the edge had nothing in sight. Now every side of the berg has a school a short swim away, and three times as many fish are in reach. ✓ Fish value stays at +10 (DECISIONS, 2026-10-01).

**Check, do schools form and stay?** About 90% of the toy's fish (117 of 131) start in a school, up from about 40% (24 of 64) before schooling, and loose fish keep joining (122 after 2 minutes). A lone silverfish 4.5 m from a silverfish school joins it within 15 s, and its home spot ends up 1.3 m from the school's (smoke test). A lanternfish the same distance away never joins. Two schools of the same kind that wander within range merge. ✓

**Check, fish stay out of the ice:** a fish can roam up to ~8 m from its home while it joins a school, so homes start 36 m out from the middle of the 30 m berg. The closest a fish came in shallow water (above the berg's 3 m draft) was ~31 m. ✓

**Check, cost:** a schooling fish near the camera costs ~8 µs per physics frame on a desktop CPU. Fish more than 40 m from the camera (lost in the fog) take a step every 4th frame and look for school mates 4× less often, which cuts them to ~3–4 µs. With ~80% of the toy's fish that far away, 131 fish cost ~0.6 ms per frame, about what 72 cost before. ⚠ Check on a phone.

## Krill

`tuning/krill.tres` (the class is `tuning/krill_tuning.gd`).

| Value | Start | Notes |
|---|---|---|
| Krill in a swarm | 80, in a ball 2.2 m across (radius), flattened | Pink |
| Depth | 0.6–3 m | Near the surface, easy to reach |
| Eating | 12 a second while your beak's in the cloud, 0.75 energy each | 9 energy a second; a whole swarm is 60 (six fish) and takes about 7 s |
| Drifts | 0.35 m/s, within 6 m of where it formed | |
| Eaten out | Forms again within 6 m after 40 s | |

## Squid

`tuning/squid.tres` (the class is `tuning/squid_tuning.gd`).

| Value | Start | Notes |
|---|---|---|
| Energy | 25 | Two and a half fish |
| Cruises | 1.5 m/s within 8 m of home, 2–8 m deep | |
| Jets away | From a penguin in the water within 4.5 m: 9 m/s for 0.5 s (~4.5 m), squirting ink | About as fast as a boost |
| Between jets | 1.4 s | |
| Spent | After 3 jets in a row, none for 6 s | So a cruising penguin that keeps after it catches it; a boost does it sooner |
| Eaten | Another turns up at its home after 30 s | |

**Check (smoke test):** a cruising thin penguin chasing a squid sets it jetting at 9 m/s, and catches it once it's spent, after 3 jets: +25 energy. ✓

## NPC penguins

The live values are in `tuning/npc_default.tres` (the class is `tuning/npc_tuning.gd`). Each NPC is an ordinary penguin driven by `PenguinBrain` (`actors/penguin/penguin_brain.gd`), so it moves by exactly the player's rules (the same speeds, hops, boosts and fatness). The movement toy has 25: 10 on the home floe, 6 on the mesa, 5 on the pinnacle and 4 on the wedge, starting with 40–80 energy. They have their own body tint (`npc_tint` on the level), so you can tell them from the player.

**Huddle**

| Value | Start | Notes |
|---|---|---|
| Counts as a neighbour | Within 1.1 m | |
| Fully sheltered | 4 neighbours | Plus shelter from whoever's upwind |
| Warmth | Drops 0.05 /s fully exposed, rises 0.04 /s fully sheltered | From 0 (frozen) to 1 |
| Peels off | Warmth under 0.35, on the windward edge | Walks round the outside to the lee side |
| Stops pushing in | Warmth over 0.75 | Then gives way upwind at 15% of a walk, but no farther than the windward edge |
| Drain huddled | ×0.2 sheltered to ×0.6 exposed | Of the base drain (1.5 /s) |
| Drain out of the huddle | ×0.5 | Fishing, or walking home |
| Wind | Toward +x, a little toward +z | |

**Fishing**

| Value | Start | Notes |
|---|---|---|
| Hungry below | 35 | Then it waits at the edge facing the nearest school (within 70 m) |
| Party | 3 | Goes in once 3 are waiting, or 20 s after the first got there, with whoever's there |
| Swims at | 1.2 m down | Comes up for air with 8 s left |
| Heads home | At 70 energy, or after 50 s out | Or when a predator hunts it, or when there are no fish within 45 m |

**Coming home**

| Value | Start | Notes |
|---|---|---|
| Way out | The quickest: swim time, plus the walk from there to the huddle | A ramp or slope, or a launch spot on a low edge (only if it can afford the boost) |
| Launch | From 6.5 m off the edge, 2.5 m down, pitched up 52° | The same launch the smoke test checks for the player |
| Flees | A predator hunting it within 8 m | Boosts away if it can afford to, and heads home |

**Check, the huddle:** in the smoke test, 8 NPCs with endless energy stay on average 1.0 m from the middle of their huddle, and the middle stays within about 1.7 m of the floe's waddle spot. Over 90 s, 7 or 8 of the 8 take turns on the windward edge, every one of them gets in among the others, and they drain at ×0.33–0.37 on average. ✓

**Check, a fishing party:** 4 NPCs at energy 25 go in within 0.5 s of each other, all 4 get past 50 energy, and they're home in about 50 s. One knocked in off the east side swims back, climbs out and rejoins the huddle (smoke test). ✓

**Check, how a colony spends its time:** home at 70, an NPC drains to 35 in about a minute in the huddle (at ×0.3–0.5), and a trip takes 30–50 s. In a 3-minute headless run of the whole field, a colony had about half its penguins huddled at any time, with no NPC stuck anywhere. ⚠ Playtest whether that feels like a busy colony or an empty one.

## Screen effects

`tuning/screen_fx.tres` (the class is `tuning/screen_fx_tuning.gd`). Feel numbers, not balance. The player's Screen effects setting scales them: Full ×1, Reduced ×0.5 (no swimming picture when queasy), Off. A black-out is on at Full and Reduced.

| Value | Start | Notes |
|---|---|---|
| Senses a predator within | 25 m | In sight or not. Closer is stronger (0 at 25 m, 1 on top of you) |
| One hunting you | at least 0.85 | Locked on, lining up a lunge, lunging, getting its breath back. A pod's attack on you: 0.95 |
| Sated predator / out of the water | × 0.35 / × 0.5 | A hunt always counts in full |
| Anxiety comes on / fades | 0.4 / 0.25 a second | So 2.5 s to full, 4 s to clear |
| At full anxiety | Edges 60% dark, reaching 30% in | Plus a heartbeat throb (up to +15%, 96 a minute) at its worst |
| Boost | Edges 30% dark, reaching 25% in; in 0.12 s, out 0.45 s | |
| A hit closes it to | 92% dark, reaching 60% in, × its strength | Dazed 0.9 (opens back up over the daze), stunned 0.75 (1.2 s), a lunge at you from within 8 m 0.45 (0.6 s), a hard bump 0.35 (0.6 s) |
| Caught | Black for 0.35 s, back over 0.9 s | |
| Queasy | A green tint, the picture swimming (0.8% of the screen) and doubled | Only while queasy: it reads the screen back, which costs a little every frame |

**Check (smoke test):** with a hunting seal 10 m off, anxiety is 0.20 after 0.5 s and 0.97 after 3 s; a second after it's gone it's still 0.72, and 4 s later clear. Reduced shows a hit at half the darkness (0.40 to 0.81); Off shows nothing. ✓

## Food pulses (multiplayer)

Fish counts scale with the number of players.

| Pulse | Time | Distance from the waddle | Fish per player | Stays for |
|---|---|---|---|---|
| 1 | 0:00 | Near (≈10 m) | 2 | 25 s |
| 2 | 0:50 | Middle (≈25 m) | 3 | 25 s |
| 3, last meal | 1:40 | Far (≈40 m) | 4.5 | 20 s |

- Warning before a pulse forms: **5 s** (seabirds gather).
- **Check, scarcity:** 6 players need about 1,000 energy in total over a round, but only ~870 is available (57 fish plus starting energy). Food is meant to be scarce, so players compete for it.

## Predators

| Value | Start | Notes |
|---|---|---|
| Targeting score | 0.5·size + 0.3·noise + 0.2·closeness | Each part runs from 0 to 1 |
| Target switch threshold | ×1.25 | The new target must score at least 25% higher |
| Sated time after chum | 4 s | |
| Sated time after eating a penguin | 8 s | |
| Leopard seal lunge range | 5 m | Was 4 m (DECISIONS, 2026-10-02) |
| Leopard seal lunge warning | 0.6 s | |
| Leopard seal lunge cooldown | 2 s | Was 3 s |
| Orca wave warning (fins lining up) | 2.0 s | Built in the movement toy (see Orca pod below) |
| Orca wave reach (from the ice edge inward) | 3 m | Built in the movement toy |
| Orca ram tilt (4 m floe / the berg) | 25° / about 1.2° | Built in the movement toy (see Orca pod below) |
| Leopard seal ambush warning | 0.4 s | Built in the movement toy (see Edge ambush below) |
| Orca cut-off and carousel warnings | 5.0 s each | Built in the movement toy (see Orca pod below) |

### Leopard seal (in the movement toy)

The live values are in `tuning/predators/leopard_seal.tres` (the class is `tuning/predator_tuning.gd`). The movement toy has two seals.

| Value | Start | Notes |
|---|---|---|
| Patrol speed | 3.5 m/s | |
| Chase speed | 6.5 m/s | Well above a cruising penguin (4.0 thin, 4.6 stuffed), below a boost (9–11) |
| Sated speed | 1.5 m/s | |
| Speed after a lunge | 2.0 m/s | Until the lunge cooldown ends |
| Acceleration | 8 m/s² | Up to chase speed in under half a second |
| Turn rate | 85 °/s | A thin penguin (120 °/s) out-turns it; a stuffed one (66 °/s) can't |
| Patrol loop | 4 m off the ice edge, 1.5–3.5 m deep | 40% of legs swing past a school within 30 m. Each leg is 17–30 m round the berg |
| Roams | 25% of patrol legs | In a berg field it patrols round one berg; now and then it heads off to one of the 3 nearest others instead |
| Sees penguins in the water | 24 m (was 20) | Underwater fog hides things past ~20–25 m |
| Hears a noisy penguin | up to 35 m | Its noise (a splash going in or bursting out sets it to 0.8, a bump up to 1; it fades over 2 s) stretches how far off it notices you, from 24 m toward 35 m |
| Sees penguins out of the water | 6 m | The edge ambush. Never through ice; never up on the plateau |
| Gives up a chase | Beyond 30 m, or after 15 s | Was 25 m and 12 s. Then ignores that penguin for 4 s |
| Lunge warning | 0.6 s | Ring flashes; the strike line shows where the lunge will go. Starts 5 m out; during it the seal stops closing in and matches its target's speed |
| Lunge | 12 m/s for 0.5 s (~6 m) | Straight along the strike line, then 2 s before the next |
| Catch reach | 1.3 m from the jaws | The jaws are 1 m ahead of the body; the lunge can rear 0.6 m out of the water |
| Hunger | +0.6 /s (was +1), starts at 10–40 | Out of 100. So it starts starving about 50–100 s in, and then every 50 s or so |
| Starving at | 70 | Goes to the nearest school (within 80 m) and eats fish, unless a penguin in the water is within 10 m: then it chases that instead (`feeding_break_range`) |
| Fed at | 40 | Each fish takes 8 off. About 4 fish |
| Sated after eating a penguin | 8 s | Hunger drops to 0 |

**Check, does it give a good chase?** Headless trials: a seal starts 10 m behind a swimming penguin and gets 12 s, 5 runs each at energy 10, 50 and 100 (15 per row). The penguin reacts to each lunge warning the same way every time.

| What the penguin does at each warning | Old seal (5.5 m/s, lunge every 3 s) | Now |
|---|---|---|
| Nothing | caught 10/15 in 8–10 s; stuffed ones got away | caught 15/15 in ~5 s |
| Turns, 0.2 s into the warning | caught 0/15 | caught 13/15, in ~9 s |
| Turns, 0.4 s in | caught 8/15 | caught 14/15 |
| Boosts | caught 0/15 | caught 0/15, but about 4 boosts (~32 energy) |

So a seal now runs you down fast, and dodging lunges only buys time: to get away for good you need the ice, boosts (which cost fish) or a tight turning fight a thin penguin can win. ✓

**Check, is each lunge still fair?** The same trials, stopping after the first lunge (6 runs per size, 18 per row):

| Reaction (into the 0.6 s warning) | Do nothing | Turn | Boost |
|---|---|---|---|
| 0.2 s | caught 18/18 | escaped 18/18 | escaped 17/18 |
| 0.4 s | – | caught 9/18 | escaped 18/18 |

Spot the warning early and a turn gets you off the line for free; spot it late and it's a coin flip unless you boost. ✓ The smoke test checks that a 0.2 s turn dodges. This only holds because the seal stops closing in during the warning; when it kept closing (the first version), a faster seal made turns useless.

**Check, does it come for you?** (After the playtest, DECISIONS 2026-10-08.) Headless trials: the player's penguin is put on the ice at the edge nearest a seal (wherever it is at a random moment) and jumps off toward it. Before: 12 of 16 times a seal locked on and lined up a lunge; the misses were a seal lying in wait elsewhere (it ignored anyone more than 6 m off), a feeding seal, and seals out of sight. Now: 15 of 16, including one 23 m away that heard the splash. Dropped into open water 6–12 m from a seal: 13 of 16. The smoke test checks hearing a splash at 28 m (and not a quiet swimmer there), an ambush breaking for a penguin going in 10 m along the edge, and a starving seal breaking off for a penguin 8 m off. ✓

**Check, the ice edge:** the lunge reaches about 1 m onto the ice. A penguin standing at the edge gets grabbed; 4 m in, the seal may lunge at you but can't reach (smoke test). ✓

**Check, how often a seal goes off to feed:** with no catches, a seal starts starving 30–60 s into the toy and then about every 30 s, and one school (about 4 fish) feeds it. In a 2-minute headless run, each of the two seals went feeding three times, and they ate 25 fish between them, out of ~130. ✓

#### Edge ambush

In `tuning/predators/leopard_seal.tres` too (the Ambush group). The orca has it switched off (`ambush_chance = 0`).

| Value | Start | Notes |
|---|---|---|
| When | Half the time at the end of a patrol leg | Also right after losing a penguin that climbed out onto the ice |
| Waits for | A penguin on the ice within 10 m of an edge, and within 45 m of the seal | The most tempting one. Not up on the plateau. Two seals never wait at the same spot |
| Where | 1.6 m out from the edge nearest that penguin, 1.2 m down | Holds still, facing the ice: a dark shadow just past the edge. Shallow enough to peek over it |
| Follows | Moves to a new spot when the penguin's nearest edge has moved 6 m | |
| Gives up | After waiting 15 s at one spot, or when nobody's near that edge | Moving to a new spot starts the 15 s again |
| Strikes | Anyone in the water within 6 m (about as far as a lunge carries), or out of the water within reach of its jaws | |
| Breaks cover | For anyone in the water within 14 m | It gives up the ambush and chases (`ambush_break_range`). Farther off, it lets them come |
| Warning | 0.4 s | Instead of the usual 0.6 s: it's already lined up |

**Check, can you see it?** Within 3 m of the surface every predator casts a dark shadow on the water (darkest down to 1.5 m). From the ice, a seal lying in wait shows as a shadow just past the edge. (A screenshot from the movement toy's ice camera.) ✓

**Check, going in where it waits:** the smoke test drops a penguin into the water at the edge by a waiting seal: it lunges 0.1–0.2 s later, after a 0.42 s warning, and catches it. Going in 20 m along the edge gives you a head start: no lunge, and the seal has to chase. ✓

**Check, coming home past it:** headless trials, a penguin swims in from 12 m out toward the edge where a seal waits:

| How it comes in | Straight at the seal | 4 m to the side | 6–12 m to the side |
|---|---|---|---|
| Cruising | caught 3/3 | – | not struck 4/4 |
| Boost and launch from 4–5 m out | caught 4 of 5 | gets out | gets out |
| Boost and launch from 6–7 m out | gets out 12/12 | – | – |
| Boost and launch from 8–9 m out | falls short into the water | – | – |

So you beat an ambush by coming in somewhere else, or by launching from just outside its reach (6–7 m out, before you're within 6 m of it). ✓ The smoke test checks the 6.5 m launch. Walking along the edge doesn't shake it (it swims 3.5 m/s to your 1.8), but a belly-slide across the berg leaves it a long swim round. ⚠ Playtest how often seals lie in wait: in a 4-minute headless run they did about once every 25 s between them.

### Orca (in the movement toy)

Each orca is a predator like the seal, with its own values in `tuning/predators/orca.tres` (same class, `tuning/predator_tuning.gd`). Anything not listed is the same as the seal.

| Value | Start | Notes |
|---|---|---|
| Patrol speed | 4.0 m/s | |
| Chase speed | 7.5 m/s | Faster than a seal, but it rarely chases |
| Acceleration | 5 m/s² | Big and heavy |
| Turn rate | 55 °/s | Any penguin out-turns it |
| Patrol loop | 12 m off the ice edge, 3–6 m deep | 25% of legs swing past a school within 40 m |
| Roams | 35% of patrol legs | The pod follows its leader to another berg |
| Sees penguins in the water | 12 m (was 8); hears a noisy one up to 20 m | Orcas don't chase from far off in open water (GDD §5.3) |
| Sees penguins out of the water | – | Never: on the ice, the wave is its attack |
| Gives up a chase | Beyond 18 m, or after 8 s | Was 14 m and 6 s |
| Lunge | from 8 m, 13 m/s for 0.6 s | Was from 6 m for 0.5 s. A 0.7 s warning (the seal's is 0.6) and the strike line; every 2.5 s |
| Aims | where you'll be when the jaws get there (`lunge_lead` 1) | If you keep going the way you are, straight or round the turn you're making. Was: at where you are |
| Catch reach | 1.2 m from the jaws, 2.4 m ahead of the body | Was 1.8 m: aiming ahead, it doesn't need the slack |
| Body | 6 m long, 0.9 m thick | Touch it and you're dazed (Dazed, above), and it lunges at once |
| Humpbacks | Shy of them | Won't hunt a penguin within 10 m of one (see Humpback) |
| Hunger | +0.5 /s; each fish takes 4 off | Starving and fed at 70 and 40, like the seal |
| Sated after eating a penguin | 12 s | |

### Orca pod (in the movement toy)

The pod's values are in `tuning/predators/orca_pod.tres` (`tuning/pod_tuning.gd`), and each attack it knows has its own file: `orca_wave.tres` (`tuning/wave_attack_tuning.gd`), `orca_ram.tres` (`tuning/ram_attack_tuning.gd`), `orca_cut_off.tres` (`tuning/cut_off_attack_tuning.gd`) and `orca_carousel.tres` (`tuning/carousel_attack_tuning.gd`). The attack classes all extend `tuning/pod_attack_tuning.gd`, which holds the steps every attack shares. The movement toy has one pod of 3.

| Value | Start | Notes |
|---|---|---|
| Formation spacing | 4 m | A V behind the leader. Followers lagging behind swim up to 0.8 m/s faster per metre they're off |
| Attacks | On the ice: the wave and the ram. In the water: the cut-off (4–10 m from the ice) and the carousel (farther out) | When more than one has a target, one is picked at random by weight: ram 1.5, the others 1 |
| Traps | Wave or ram → cut-off → carousel | Right after a strike, the pod tries the attacks it leads into (`chains_into`), with no cooldown. At most 4 in a row |
| First attack | No sooner than 6 s in | Was 10 s |
| Relay strikes | Up to 3 in a row | When an orca's lunge misses (or it gives up, or a penguin bumps one that's out of breath), the nearest other orca within 16 m that can strike goes in straight away. Each keeps the hunt after an attack going 2 s longer; they start again after 8 s without one. Not while an attack is lining up or under way |
| Shadowing a hunt | 10 m off the penguin, 110° round either side | While one orca hunts, the free ones keep this close, ready to take over |

**Check, what each lunge does (orcas).** Headless trials (`tests/trials/whale_trials.gd`): one orca, 9–12 m away on a random side, strikes once at a thin bot penguin out in open water, 24–30 runs per row. The bot either swims straight on or circles (0.4–1 rad/s), and at the warning does nothing, turns square off the line at its real turn rate after a delay, or ("smart") boosts across the line if it was heading into it and turns away and boosts otherwise.

| At the warning | Swimming straight | Circling |
|---|---|---|
| Nothing | caught 81% | caught 75% |
| Turns away after 0.2 s | 19% | 38% |
| Turns away after 0.4 s | 43% | – |
| Boosts (smart), after 0.3 s | 10% | 13% |

Before this change (aimed at where you are, 1.8 m reach), a penguin just swimming in a circle was caught by 2 lunges in 10. Now doing nothing gets you eaten; reacting early, and boosting, gets you off the line. A turn alone helps less when you're already circling: the orca reads the curve, so turn the other way or boost. ✓

**Check, a whole hunt (orcas).** The same bot, 9–14 m from the pod, swimming about for 14 s after one orca goes for it, with relays, 24 runs per row:

| At each warning | Caught | Lunges per run | Relay strikes per run |
|---|---|---|---|
| Nothing | 96% | 1.9 | 1.0 |
| Turns away after 0.2 s | 92% | 2.7 | 1.5 |
| Boosts (smart) | 50% | 3.6 | 2.3 |
| Boosts, with a humpback 25 m off | 30% | 2.4 | 1.2 |

After the playtest changes (DECISIONS, 2026-10-08: orcas notice you from 12 m and hear a splash from 20 m) the same trials give: nothing 100%, turning after 0.2 s 96%, boosting 71% (54% re-measured on the whale build with the same runs, so roughly +15%). Open water near a pod is deadly now unless you boost (and boosts cost fish), get to the ice, or reach a humpback. The bot never heads for the ice; a player would. ⚠ Playtest whether a hunt lasts too long: `chase_give_up_seconds` and `relay_max` are the levers.

**Check, the carousel.** Holding still in the middle: caught 24/24. Swimming round inside it: 88% caught doing nothing, 50% boosting at each warning. Keeping to the ring's edge and turning: 79%. Leave before the bubbles go up. ✓

Every attack runs the same steps: pick a target, line up, warn, charge, strike, then hunt the water. These are the shared values, the same for every attack unless the attack's table says otherwise:

| Value | Start | Notes |
|---|---|---|
| Targets | Penguins within 40 m of the leader | The most tempting one (GDD §5.1); each attack adds where they must be |
| Line-up | Gives up waiting for stragglers after 8 s | |
| Warning, once lined up | 2.0 s | The danger zone shows from 40% of the way through |
| Charge speed | 8 m/s | |
| Hunt after the strike | 6 s | The orcas hold near the ice and go after anyone in the water within 8 m |
| Between traps | 12 s (6 s if an attack was called off) | Was 20 s. Counted from the end of the whole trap |
| Needs | At least 2 free orcas | A starving or hunting orca drops out; with too few left, the attack is called off |

#### The wave (`orca_wave.tres`)

| Value | Start | Notes |
|---|---|---|
| Targets | Standing within 3 m of the edge that faces the pod | |
| Line-up | Side by side, 14 m out from the edge, at 0.5 m depth (fins showing) | |
| Warning | 2.0 s | The swell rises from the start |
| Charge | 8 m/s, the wave breaks 3.5 m from the edge | About 2 s |
| Wave zone | 12 m along the edge × 3 m in | Penguins up to 0.4 m outside it are caught too (about a body width) |
| Wave shove | 8 m/s toward the water | On your feet you take half (grip), on your belly all of it |
| Washes ice up to | 1.5 m above the water | Higher tops (the mesa's 3 m, the wedge's crest) are out of reach |

**Check, can you get out of the way?** In the smoke test the wave hits 4–5 s after the pod lines up (2 s of fins and swell, then the charge), on top of however long the line-up takes. Walking (1.8 m/s) gets you out of a 3 m zone in under 2 s, and the zone is on screen for at least 3 s. ✓

**Check, what the wave does:** on your feet, half the 8 m/s shove is 4 m/s, and skid friction (2.5 m/s²) carries you about 3.2 m: anyone in the zone ends up teetering at the edge, and can still scramble back for 4 energy. On your belly you take the full 8 m/s, and tumble friction (2 m/s²) carries you about 16 m, straight into the sea. The smoke test sees a penguin standing 1.5 m from the edge go in, and one 6 m in left alone. ✓

#### The ram (`orca_ram.tres`)

Only ice marked as tippable (`TippableIce`, `levels/tippable_ice.gd`) can be rammed. The movement toy marks the berg (with its plateau and ramp) and the three floes.

| Value | Start | Notes |
|---|---|---|
| Targets | Standing on tippable ice within 8 m of the edge that faces the pod | Anywhere on a small floe |
| Line-up | Side by side, 6 m out from the edge, 4 m down (dark shadows under the ice) | |
| Warning | 1.5 s | The water bulges by the edge from the start |
| Charge | 9 m/s up to 2 m from the edge, rising to 0.8 m deep, then the ram | About 1.2 s |
| Danger zone | The whole floe, if it's no wider than 8 m; on bigger ice an 8 m deep × 16 m strip by the rammed edge | |
| Tilt | 200 ÷ radius^1.5 degrees, at most 30° | A 4 m floe tips 25° (its rim goes under); the 30 m berg rocks about 1.2° (its rim drops about 0.6 m) |
| Tip timing | Over in 0.35 s, held 2 s, righted over 1.2 s | |
| Jolt | 5 m/s toward the pod, for everyone in the danger zone | On your feet you take half (grip) |

**Check, can you get out of the way?** In the smoke test the ram hits 2.8 s after the pod has gathered, and the danger zone is up for about 2 s. On a floe that isn't enough to walk off from the middle (2+ s to the edge), and the water is where the orcas are, so the answer is to dig in. Leaving early works too: gathering takes a few seconds, and the HUD's F1 line shows it. ✓

**Check, what the ram does to a floe:** 25° is far steeper than you can stand on (14°), so you slip onto your belly and slide off the low side. The smoke test sees a penguin standing in the middle of the 4 m floe end up in the water about a second after the ram. Pulling back holds (the brake grips on slopes up to 25°), and the smoke test sees a penguin digging in stay on until the floe rights itself. ✓

**Check, what the ram does to the berg:** 1.2° is gentle, so only the jolt matters: on your feet you skid about 1.3 m (2.5 m/s at 2.5 m/s²), so only someone right at the edge goes in; on your belly you slide about 6 m. The smoke test sees a penguin 5 m in stay on the ice, and the berg, plateau and all, settle back exactly where they were. ✓

#### The cut-off (`orca_cut_off.tres`)

| Value | Start | Notes |
|---|---|---|
| Targets | In the water 4–10 m from the nearest ice, within 30 m of the leader | Closer than 4 m you're as good as home; farther out is the carousel's job |
| Line-up | A wall across your way home: side by side, 4 m apart, 0.5 m down (fins showing), 7 m from you | Never closer than 1.5 m to the ice. It follows you as you swim |
| Warning | 5.0 s | The wall closes in from 7 m to 4.5 m. The line you mustn't cross shows on the water from 30% of the way through |
| Snap | Swim toward the ice within 4 m of an orca in its place in the wall (or come within 2.4 m of one anyway) | That orca lunges, with the usual 0.6 s warning. Orcas still swimming round to their places don't snap |
| Pushed out | 10 m from the ice | The wall's done: the trap moves on to the carousel |
| End of the warning, still near the ice | The nearest orca lunges | |
| Gets away | Within 2 m of the ice (close enough to launch out), or past the wall | |
| Hunt after the strike | 4 s | |

**Check, the wall:** the smoke test floats a penguin 8 m off the south edge. The wall forms between it and the ice, with every orca 2+ m closer to the ice than it and fins up. It closes in for the full 5.0 s without lunging at a penguin that holds still, then the nearest orca goes for it. A penguin that races home as soon as the pod starts lining up gets back to the ice first and the attack is called off. ✓

**Check, can you get round it?** The wall swims up to 7.5 m/s, faster than you cruise (4) and slower than a boost (9), and it's 8 m wide plus 4 m of snap range at each end: going round the end takes a boost. Diving more than about 4 m below the fins gets you under it. ⚠ Playtest whether pushing you out to sea (and into the carousel) feels like a trap you could have seen coming.

#### The carousel (`orca_carousel.tres`)

| Value | Start | Notes |
|---|---|---|
| Targets | In the water 10 m or more from the nearest ice, within 30 m of the leader | |
| Line-up | A ring round you, 10 m radius, 2 m down, circling at 5 m/s | No tighter than 70% of an orca's 55 °/s turn. While they get into place (up to 8 s) the ring's middle follows you at 2.5 m/s |
| Warning | 5.0 s | The bubble wall goes up and the ring squeezes to 4.5 m (its middle follows you at 0.5 m/s). The slap zone shows from 60% of the way through |
| Bubble wall | 1 m thick | Swimming out through it, you're slowed 25 m/s² (on top of being swept in as it closes): a cruising penguin (4 m/s) stops within 0.3 m, a boost (9 m/s) needs 1.6 m and breaks through |
| Lift | Inside the ring, deeper than 1 m, you're pushed up (20 m/s²) to rise at 1 m/s | No diving out under it |
| Tail slap | One orca rises to the middle at 8 m/s and slaps it | Anyone within 3.5 m of the middle and no deeper than 2 m is stunned for 1.2 s and shoved 3 m/s out (the water takes 65% of that) |
| Then | The orca closest to you that didn't slap lunges | The usual 0.6 s warning and strike line |
| Bubbles linger | 1.5 s after the slap | |
| Hunt after the strike | 4 s | |

**Check, can you get out?** The smoke test: swimming straight out once the bubbles are up, a penguin never gets past the ring (0.0 m), and one diving at 40° stays within 1.2 m of the surface. A boost straight out early on breaks through and the carousel is called off. ✓ Leaving before the bubbles go up is easy: the ring follows you at 2.5 m/s, and you cruise at 4.

**Check, the slap:** the slap zone is on the water for 3.5–4.4 s before the slap (smoke test). A penguin floating in the middle is stunned, can't boost, and the next orca lunges at it. In headless trials a penguin swimming at the ring's edge (4 m from the middle) was outside the slap zone and wasn't stunned, so it keeps its boost for dodging the lunge. ✓

**Check, the trap:** a penguin the cut-off pushes out to sea goes straight into the carousel (the same frame, trap step 2). A penguin a wave washed in that swims 6 m off the edge is cut off 1.6 s after the wave hit, with no cooldown (smoke test). ✓

**Check, a pod stays a pod:** on patrol the followers keep about 6–7 m from the leader. ✓

## Humpback (in the movement toy)

The values are in `tuning/humpback.tres` (the class is `tuning/humpback_tuning.gd`, which extends `tuning/swimmer_tuning.gd`). The movement toy has two (`MovementToy.humpback_count`).

| Value | Start | Notes |
|---|---|---|
| Body | 12 m long, 1.5 m thick | Twice an orca. Touch it and you're dazed 2 s (Dazed, above) |
| Cruises | 2.5 m/s, 3–7 m deep | Slower than a penguin, so you can keep up. Loops round the ice 14–45 m off its edge |
| Steering | 45 °/s, 2.5 m/s² | |
| Breathes | Every 25–40 s | Rolls along the top 6 s (its middle 0.7 m down: back and fin out), blows 3 times 1.8 s apart, then dives nose down at 50°, flukes up, for 2.5 s |
| Feeds | Every 50–80 s, on a school within 45 m | The school must be in open water: no ice within 12 m. Gives up getting there after 25 s |
| Bubble net | Circles 8 m down, one turn in 8 s, the ring closing from 7 m to 3.5 m | Fish within 10 m of the middle are herded into a ball at the surface. The water boils in the middle for the last 1.5 s and while it lines up (1 s) |
| Lunge | Straight up through the middle at 8 m/s, at least 75° steep, until its head is 2.5 m out | Swallows every fish within 4 m; that school is gone for 45 s (a penguin's eaten fish come back in 8) |
| Scoop | A penguin in the water within 4.5 m of the middle | Thrown up at 7 m/s and out at 4 m/s, dazed 2.5 s, a fish comes back up. Never eaten |
| Afterwards | Falls back in (1.5 s), rests at the surface 8 s | |
| Driving off orcas | Notices orcas hunting a penguin within 35 m | A pod's attack, or an orca chasing or lining up a lunge. Swims there at 4 m/s (gives up after 20 s), blowing |
| Shelter | Any penguin within 10 m of its body | Orcas won't hunt it, a pod attacking it calls the attack off, and an orca sent at it refuses. Leopard seals don't care |
| Guards | 10 s, keeping 4.5 m off the penguin's side | Its body doesn't daze the penguin it's guarding |

**Check, a bubble net (smoke test).** A 10-fish school in open water: all 10 herded into the ball, all 10 swallowed, none back 10 s later; a penguin held in the middle is scooped up (thrown up at more than 3 m/s), dazed, loses a fish and isn't eaten. In a 2-minute headless run one humpback breathed every 25–40 s and fed once, on a school of 11. ✓

**Check, does it come to help?** Trials (`--humpback=D`): a humpback starts D m from the bot when the orcas strike.

| Humpback starts | Drove the orcas off | How soon |
|---|---|---|
| 25 m off (a hunt) | 12 of 20 | 4.4 s |
| 40 m off (a hunt) | 9 of 20 | 5.7 s (it wanders into range) |
| 30 m off (a carousel) | 20 of 20 | 5.4 s, before the slap |

A carousel is slow (8–13 s before the slap), so a humpback anywhere near always breaks it up; a quick hunt it only sometimes reaches. With two humpbacks roaming the toy, most hunts get no help. ⚠ Playtest: `mob_range` and `shelter_radius` are the levers if they're too much of a safety net.

## Multiplayer round

| Value | Start |
|---|---|
| Starting iceberg size | ≈60 m across |
| Kill-screen floe size | ≈8 m across |
| Crack widths as the ice breaks up | 0.5, 1.0 and 1.4 m |
| Kill screen starts | 2:00 |
| Lunge warning | 1.0 s |
| Time between lunges | Shrinks from 6 s to 2 s over the first 60 s of the kill screen |
| Double lunges begin | 3:30 |
| Hard cap | 5:00. If more than one penguin is left, the one with the most energy wins. [Proposed] |

## Single-player campaign

| Value | Start |
|---|---|
| Level length | 5–10 min |
| Target trips per level | 4–8 |
| Energy lost when caught | 60 |
| Caught below this energy = level failed | 30 |
| Pod hunger meter | 100 |
| Hunger filled by each chum | +10 |
| Hunger filled over time | +1 /s (about 100 s to survive without using chum) |
