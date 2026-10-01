# Fat Penguin — Tuning Values

Last updated: 2026-10-01

**Every number here is a starting guess for playtesting.** Change them freely, but keep this file in step with the game.

**The live copy is in Godot:** `tuning/penguin_tuning_default.tres` (the class is `tuning/penguin_tuning.gd`). Edit the values in the Inspector, then copy the ones that work back here.

**In the game so far (Prototype 0):** base and overfill drain, fish value, boost, flop and scramble costs, fat vs. thin, movement, slopes and hops, bumping (except bump noise and credit, which need predators), air, and fish schooling. Waddle drain, the other action costs, food pulses, predators, rounds and campaign values arrive with later prototypes.

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
| Bump noise | 0.4 soft, 1.0 hard | Added to both penguins' noise score; fades over 2 s. Not built yet (no predators) |
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
| School size | 6–10 | 6–9 | 3–5 | |
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

**Movement toy spawning** (`levels/movement_toy/movement_toy.gd`): 8 schools (every species gets at least one, the rest by abundance), 12 loose fish, homes 36–70 m from the middle of the berg.

**Check, do schools hold together?** Measured headless over 2 minutes: schools keep their size, the nearest school mate sits ~0.52 m away (personal space 0.5 m), and school mates swim almost exactly the same way (polarisation 0.99). The smoke test measures the widest fish of a 6-fish school **0.7 m** from its middle after 15 s. ✓

**Check, do schools form and stay?** About 85% of the toy's fish (62 of 72) are in a school, up from about 40% (24 of 64) before schooling. A lone silverfish 4.5 m from a silverfish school joins it within 15 s, and its home spot ends up 1.3 m from the school's (smoke test). A lanternfish the same distance away never joins. Two schools of the same kind that wander within range merge. ✓

**Check, fish stay out of the ice:** a fish can roam up to ~8 m from its home while it joins a school, so homes start 36 m out from the middle of the 30 m berg. The closest a fish came in shallow water (above the berg's 3 m draft) was ~31 m. ✓

**Check, cost:** ~7–8 µs per fish per physics frame on a desktop CPU (about 0.5 ms for 72 fish), against ~2 µs for the old circling fish. ⚠ Check on a phone.

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
| Leopard seal lunge range | 4 m | |
| Leopard seal lunge warning | 0.6 s | |
| Leopard seal lunge cooldown | 3 s | |
| Orca wave warning (fins lining up) | 2.0 s | |
| Orca wave reach (from the ice edge inward) | 3 m | |

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
