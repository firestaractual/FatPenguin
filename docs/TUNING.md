# Fat Penguin — Tuning Values

Last updated: 2026-10-04

**Every number here is a starting guess for playtesting.** Change them freely, but keep this file in step with the game.

**The live copy is in Godot:** `tuning/penguin_tuning_default.tres` (the class is `tuning/penguin_tuning.gd`). Edit the values in the Inspector, then copy the ones that work back here.

**In the game so far (Prototype 0, plus the leopard seal from Prototype 1):** base and overfill drain, fish value, boost, flop and scramble costs, fat vs. thin, movement, slopes and hops, bumping (except bump credit), bump noise, air, fish schooling, the leopard seal, and the orca pod with its wave and ram (from Prototype 2). Waddle drain, the other action costs, food pulses, the orcas' kill-screen lunges, rounds and campaign values arrive with later prototypes.

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
| Hop distance (across gaps; not built yet) | ×1.00 | ×0.40 |
| Get-up time (belly to feet) | ×1.00 | ×2.00 |

Nothing has a hard threshold: ice never breaks under a penguin's weight (see DECISIONS, 2026-10-01).

**Check, hops across gaps** (crack widths are under Multiplayer round): a thin penguin hops 1.5 m and clears every crack. At the starting 50 energy it hops 1.05 m, clearing up to the 1.0 m cracks. At the overfill threshold (70) it's 0.87 m, and when full it's 0.6 m, so an overfed penguin only clears the narrowest cracks. ✓

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
| Hop distance | 1.5 m | Across cracks. Not built yet (gaps come with ice breakup) |
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
| Bounciness | 0.8 | 1.0 would be perfect billiard balls |
| Grip on your feet | ×0.5 knockback | Penguins on their belly take ×1.0 |
| Tumble friction (knocked onto your belly) | 2.0 m/s² | Higher than a normal slide (0.45), so one hit can't send someone across the whole iceberg |
| Max knockback speed | 6.0 m/s | |
| Knockback in water | ×0.35 | Drag soaks it up; water bumps are short shoves |
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
| Thin → thin | ~2.3 m | ~9 m (capped) |
| Fat → thin | ~4.1 m | ~9 m (capped) |
| Thin → fat | ~1.0 m | ~5 m |
| Fat → fat | ~2.3 m | ~9 m (capped) |

At the old 5 m/s flop these were 1.0, 1.8, 0.5 and 1.0 m on feet. The ×1.5 land speed (DECISIONS, 2026-10-01) roughly doubles how far a full-speed hit knocks a standing penguin.

The smoke test launches its hitters at a fixed 5 m/s (from 3 m away, so they arrive a little slower) and measures thin → thin on its feet **0.9 m**, fat → thin on its belly **8.7 m**, thin → fat on its feet **0.4 m**. ✓

- The kill-screen floe is ≈8 m across, so its edge is ~4 m from the middle. ⚠ At 7.5 m/s a fat penguin's full-speed hit skids a standing thin one ~4 m, about the whole radius, so standing is a weaker defense than intended. Before the kill screen is built, pick one: a bigger floe, more skid friction on feet, or a lower knockback cap. A penguin on its belly goes in from anywhere either way.
- A lunge line only needs a ~1 m shove, which any full-speed hit gives. ✓
- A thin penguin moves a standing fat one ~1 m. Its main tool against fat is still the fish spill. ✓

**Check, sliding on the kill-screen floe:** a missed 7.5 m/s slide glides ~62 m if you let it, so on the 8 m floe a miss ends in the water unless you dig in: the brake stops it in ~4.4 m (the smoke test measures 4.3). A hit soaks up the hitter's speed instead. After a full-speed hit the hitter is left with ~0.75 m/s (thin on thin, fat on fat) or bounces back (thin on fat), and stops almost at once. Fat on thin is the exception: the fat penguin keeps sliding at 3 m/s for about another 9 m, so it has to dig in too. ✓ A miss means braking hard or swimming.

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

**Movement toy spawning** (`levels/movement_toy/movement_toy.gd`): 12 schools, one in each slice of the ring around the berg (every species gets at least one, the rest by abundance), with homes 36–50 m from the middle of the berg, 6–20 m off the ice edge. 16 loose fish anywhere 36–70 m out. About 130 fish in all.

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
| Patrol loop | 4 m off the ice edge, 1.5–3.5 m deep | 40% of legs swing past a school within 30 m |
| Sees penguins in the water | 20 m | Underwater fog hides things past ~20–25 m |
| Sees penguins out of the water | 6 m | The edge ambush. Never through ice; never up on the plateau |
| Gives up a chase | Beyond 25 m, or after 12 s | Then ignores that penguin for 4 s |
| Lunge warning | 0.6 s | Ring flashes; the strike line shows where the lunge will go. Starts 5 m out; during it the seal stops closing in and matches its target's speed |
| Lunge | 12 m/s for 0.5 s (~6 m) | Straight along the strike line, then 2 s before the next |
| Catch reach | 1.3 m from the jaws | The jaws are 1 m ahead of the body; the lunge can rear 0.6 m out of the water |
| Hunger | +1 /s, starts at 10–40 | Out of 100 |
| Starving at | 70 | Goes to the nearest school (within 80 m) and eats fish |
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

**Check, the ice edge:** the lunge reaches about 1 m onto the ice. A penguin standing at the edge gets grabbed; 4 m in, the seal may lunge at you but can't reach (smoke test). ✓

**Check, how often a seal goes off to feed:** with no catches, a seal starts starving 30–60 s into the toy and then about every 30 s, and one school (about 4 fish) feeds it. In a 2-minute headless run, each of the two seals went feeding three times, and they ate 25 fish between them, out of ~130. ✓

### Orca (in the movement toy)

Each orca is a predator like the seal, with its own values in `tuning/predators/orca.tres` (same class, `tuning/predator_tuning.gd`). Anything not listed is the same as the seal.

| Value | Start | Notes |
|---|---|---|
| Patrol speed | 4.0 m/s | |
| Chase speed | 7.5 m/s | Faster than a seal, but it rarely chases |
| Acceleration | 5 m/s² | Big and heavy |
| Turn rate | 55 °/s | Any penguin out-turns it |
| Patrol loop | 12 m off the ice edge, 3–6 m deep | 25% of legs swing past a school within 40 m |
| Sees penguins in the water | 8 m | Orcas don't chase in open water (GDD §5.3) |
| Sees penguins out of the water | – | Never: on the ice, the wave is its attack |
| Gives up a chase | Beyond 14 m, or after 6 s | |
| Lunge | from 6 m, 13 m/s for 0.5 s | Same 0.6 s warning and strike line as the seal; every 2.5 s |
| Catch reach | 1.8 m from the jaws, 2.4 m ahead of the body | A big mouth |
| Hunger | +0.5 /s; each fish takes 4 off | Starving and fed at 70 and 40, like the seal |
| Sated after eating a penguin | 12 s | |

### Orca pod (in the movement toy)

The pod's values are in `tuning/predators/orca_pod.tres` (`tuning/pod_tuning.gd`), and each attack it knows has its own file: `orca_wave.tres` (`tuning/wave_attack_tuning.gd`) and `orca_ram.tres` (`tuning/ram_attack_tuning.gd`). Both attack classes extend `tuning/pod_attack_tuning.gd`, which holds the steps every attack shares. The movement toy has one pod of 3.

| Value | Start | Notes |
|---|---|---|
| Formation spacing | 4 m | A V behind the leader. Followers lagging behind swim up to 0.8 m/s faster per metre they're off |
| Attacks | The wave and the ram | When both have a target, one is picked at random by weight: ram 1.5, wave 1 |
| First attack | No sooner than 10 s in | |

Every attack runs the same steps: pick a target, line up, warn, charge, strike, then hunt the water. These are the shared values, the same for both attacks unless the attack's table says otherwise:

| Value | Start | Notes |
|---|---|---|
| Targets | Penguins on the ice within 40 m of the leader | The most tempting one (GDD §5.1); each attack adds where they must stand |
| Line-up | Gives up waiting for stragglers after 8 s | |
| Warning, once lined up | 2.0 s | The danger zone shows from 40% of the way through |
| Charge speed | 8 m/s | |
| Hunt after the strike | 6 s | The orcas hold near the ice and go after anyone in the water within 8 m |
| Between attacks | 20 s (10 s if one was called off) | |
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

**Check, a pod stays a pod:** on patrol the followers keep about 6–7 m from the leader. ✓

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
