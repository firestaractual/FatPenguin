# Fat Penguin — Game Design Document

Last updated: 2026-10-05 · Status: pre-production

Status tags used below:

- **[Locked]**: decided. Change only with a new entry in [DECISIONS.md](DECISIONS.md).
- **[Proposed]**: current best idea, to be validated in prototypes.
- **[Open]**: not decided yet.

All numbers are in [TUNING.md](TUNING.md). This doc describes rules, not values.

---

## 1. Pitch

A cartoony mobile game based on real ecology. Penguins dive for fish on a shrinking iceberg. Food is energy, and every fish makes you fatter, clumsier and more tempting to the orcas and leopard seals hunting you. There's no shooting. You survive by swimming well, reading predators and timing when to leave the safety of the waddle, and you fight with your belly: slide into rivals like bumper cars to knock them off the food or into a predator's path.

**Platform:** mobile first (touch, one thumb). **Engine:** Godot 4, 3D.

**Title screen** [Proposed]: the logo comes to life. Each tap feeds the penguin a fish, and it swells until the ice cracks and it drops through; the splash starts the game. Thin ice exists only here. In play, ice never breaks under a penguin's weight [Locked] (see DECISIONS, 2026-10-01). Built in the movement toy with the placeholder penguin (DECISIONS, 2026-10-07).

## 2. Pillars

1. **Swimming feel:** clumsy on ice, fast and agile in water. The movement itself should be fun with no goals at all.
2. **Greed:** food is energy, but more food makes you clumsier. This applies to penguins *and* predators.
3. **Evasion:** predators you can read, based on real behavior. Every death should feel like "I misjudged that."
4. **Timing:** the main strategic decision is *when* to leave the waddle.
5. **Bumper cars:** your body is your only weapon. Weight and speed decide who goes flying, and what kills is the predator you knocked them toward.

## 3. Core loop

| Scale | Loop |
|---|---|
| **Moment** (seconds) | Steer, boost, porpoise, dodge, launch onto the ice, belly-slide, hop, bump. |
| **Trip** (20–40 s) | Leave the waddle → dive to a food pulse → eat (get fatter) → escape predators → launch back onto the ice → return to the waddle. Rivals can bump you at every step: off the bait ball, back into the water as you climb out, off the edge of the waddle. |
| **Round** (MP ~2.5 min, SP 5–10 min) | Several trips as energy drains and the ice shrinks. Multiplayer ends in the kill screen. |
| **Meta** | [Open] Campaign progress; possibly unlockable species (see §11). |

## 4. Mechanics

### 4.1 Food is energy [Locked]

- Eating fish fills energy. Energy pays for boosting, launching onto ice, dodging, flops (the belly-slides you bump with, §4.5) and chum drops.
- More energy means a fatter penguin: more fuel, but clumsier (see §4.4).
- **Energy is shown as body size, with no meter.** Everyone can read who's fat, including the predators.
- Running out of energy doesn't kill you, but you can't boost or dodge well. Predators do all the killing.

### 4.2 Energy runs out [Proposed]

This exists to prevent the "eat everything early, then hide" strategy (see DECISIONS, 2026-10-01).

- Energy drains all the time from the cold. A full belly lasts well under a round, so **every player must refuel at least once**, usually twice.
- **Overfill decays fast:** above the overfill threshold, the drain multiplies while you digest. Stuffing yourself only pays off right before you need the energy. Overfill can also be knocked loose by a hard bump (§4.5).
- Being in the waddle slows the drain but doesn't stop it.
- **Energy floor** (a stand-in): the cold can't drain you below the floor, and if you spend below it you get your breath back up to it within a few seconds. An empty penguin is thin and weak, but it can always flop or boost again soon, so it's never stranded. A real exhausted state will replace this (§11).

### 4.3 Food pulses [Proposed]

- Food arrives in **timed, clearly signaled pulses** at different spots, instead of being spread across the map at the start.
- Signals: seabirds diving, a shimmering bait ball, a change in the music.
- Predators are drawn to pulses too.
- The pulses get bigger, farther and more dangerous over a round. The final pulse is the **last meal**, just before the kill screen.
- Each pulse is a choice: go early before the predators arrive, go late after they've eaten, or skip it.

### 4.4 Fat vs. thin [Proposed]

| | Fat (high energy) | Thin (low energy) |
|---|---|---|
| Fuel | Many boosts and dodges | One or two boosts |
| Straight line | Higher top speed, keeps momentum | Lower top speed |
| Turning and starting | Wide turns, slow to get going | Sharp turns, quick starts |
| Getting onto ice | Lower launch, struggles to climb out | High launch |
| Hopping (ledges and cracks) | Low, short hop; stopped by tall steps and wide cracks | Clears every step and crack |
| Bumping | Heavy: hits hard, hard to move, slow to get up | Light: knocked far, but quick to get out of the way |
| Predator interest | Targeted first | Usually ignored if anyone fatter is around |

Fat wins in a straight line and in a collision; thin wins in tight spaces and over ledges and gaps. Neither one is "winning."

A full belly makes you a bad jumper, but it never breaks the ice. Every fat/thin difference scales smoothly with body size, so there's no hidden threshold to learn.

### 4.5 Bumping: bumper-car PvP [Locked as intent, Proposed in detail]

PvP is physical. There's no attack button: you hit rivals by sliding (or boosting) into them, and, as with bumper cars, weight and speed decide who goes flying. A bump never kills anyone directly. It moves rivals toward the things that do: off the food, off the ice, onto a lunge line, into a predator's lock-on. **Predators still do all the killing.**

#### How a bump works

- Every penguin is a physics body whose **mass grows with body size**. Fat penguins are heavy.
- Two penguins meeting faster than the **bump speed** is a bump. Slower than that, they just push each other, the way a crowd does.
- **Momentum decides.** Both penguins are pushed apart, and the lighter, slower one goes farther.
  - Fat sliding into thin: thin goes flying, and fat barely slows.
  - Thin sliding into a standing fat penguin: thin bounces off, and fat barely rocks. Thin can't move fat, but it can rob it (see fish spill below).
  - Same size: they trade speed like billiard balls.
- **Angle matters.**
  - Head-on: both bounce back.
  - From the side: a hard hit spins the victim out, with no steering or dodging for a moment.
  - From behind: pushes the victim faster in the direction it was already going. Good for shoving someone off the edge they're walking along, or, in coop, for helping a teammate home.
  - Glancing: a small deflection.
- **Chains:** a penguin knocked into another passes part of the hit along, like billiards.

#### Feet vs. belly (the defense)

- **On your feet** (walking, standing, dodging) you have grip. You take much less knockback, skid to a stop quickly, and **teeter** at the ice edge before falling in, which gives you a moment to scramble back for a little energy.
- **On your belly** (sliding, or tumbling after a hit) you're a puck: full knockback, a long glide, and straight off the edge with no teeter.
- So the slide is both the attack and the risk. A flop commits you. If you connect, the hit soaks up your speed and you stop. If you miss, you sail on across the slick ice until you dig in (pull the stick back) to brake, and getting back on your feet takes a moment (longer when you're fat). On the small kill-screen floe, a miss means braking hard or swimming.
- **In water**, drag soaks up knockback, so a bump is a short shove. Boost-ramming is the water version. Water bumps are for crowding someone off a bait ball or blocking a fish; the ice is the arena.

#### What a bump does

| Effect | When | Why it matters |
|---|---|---|
| **Knockback** | Every bump | Moves a rival off food, off the waddle's edge, into the water, onto a lunge line or toward a predator |
| **Spin-out** | Hard hits from the side | The victim can't steer or dodge for a moment. Time it with a lunge warning or a seal's lock-on |
| **Fish spill** | Hard bumps on an overfed penguin (above the overfill threshold) | One fish pops out and lands nearby. Anyone can grab it, and the hitter is usually still sliding past. Only the greedy get robbed |
| **Noise** | Every bump, more for hard ones | Raises both penguins' noise score (§5.1). A brawl at the ice edge draws the seal |

#### Limits

- **Flopping costs energy**, a small amount. The bump itself is free. Slide-spamming drains the energy you need for boosts and dodges. Landing on your belly after a launch is free, since you already paid for the boost.
- **Knockback immunity:** right after a bump, a penguin can't be bumped again for a moment (ruffled feathers show it). No juggling.
- **Crowds are heavy:** a hit on a penguin that's touching others is shared across the whole cluster. You can peel penguins off the edge of the waddle, but you can't knock anyone out of the middle. Getting to the center is a shoving match, not a bump (§4.6).
- **Bumps never kill.** Getting knocked into the water costs you a launch (a boost's worth of energy) or a swim to a low exit (§4.10). The danger is whatever is waiting in that water.

#### Where it plays out

- **The ice edge (the doorway):** penguins climbing out of the water land low and slow, fat ones especially (§4.4). A rival waiting at the edge can bump them straight back in, right where the leopard seal waits. The counter is a fast launch: you come out on your belly at speed, so a doorman standing in the way gets bumped instead. Or you launch somewhere else.
- **Pulses:** shove rivals off the bait ball, block them from a fish, or knock fish loose from whoever ate first.
- **Predators:** knock a rival toward a predator's lock-on, or spin them out just as a seal lunges. A fat rival knocked toward a predator becomes the most tempting target nearby.
- **Orca waves and rams:** waves push everyone across the ice and rams tip it (§5.3); a bump during either stacks with it.
- **Orca traps in the water:** bump a rival out past the cut-off's wall, or into the middle of a carousel (§5.3).
- **Slopes and drops:** a slide down a chute (§4.10) arrives fast enough for a hard bump, and a plateau's sheer edges are ring-outs onto the ice below: a fall and a long way round, not a swim.
- **The waddle:** the edge is where bumps happen; the middle is a shoving match.
- **Kill screen:** sumo on a shrinking floe. A short shove is enough to put someone on a lunge line during its 1-second warning, but a slide that misses has to brake hard or it ends in the water.

#### Feel and readability [Proposed]

- A soft bump is a boop. A hard bump gets a honk, a feather puff, a few frames of hit-stop and a small camera nudge. A ring-out gets a splash.
- Belly vs. feet must read at a glance, since it decides how far someone will fly.
- **Credit:** if a predator catches a penguin soon after it was bumped, the bumper gets a "bumped into the jaws" callout in the kill feed. It doesn't change the win condition; it's for bragging rights and metrics.

#### Controls

Bumping uses the controls already in the prototype (DECISIONS, 2026-10-01, Godot entry), with no new button:

- On ice, tap to flop into a belly-slide, steer it with the stick, and tap again mid-slide for a flipper push to speed into a hit. Pull the stick back to dig in and brake. You stand back up when the slide slows down.
- In water, boost into someone.
- [Open] Whether steering is precise enough to aim bumps on a phone (§11).

#### Balance checks

- **Fat bullying:** fat penguins already get more fuel and top speed, and weight adds a third edge. Watch that the kill screen doesn't become "whoever ate the last meal pushes everyone off." Thin counters: knocking fish loose, side hits, and being targeted last.
- **Braking:** digging in stops a full-speed slide in about 4 m. Watch that it doesn't make sliding risk-free; if it does, make it slower or cost energy.
- **Griefing:** a player who does nothing but bump should run low on energy and draw predators well before they win.
- **Comebacks:** thin players should be able to rob overfed leaders often enough to matter (§4.8).

### 4.6 The waddle [Proposed]

The waddle is the group of penguins on the ice and the only real safety. It's safe, but it costs you.

- Based on real emperor-penguin huddles, which constantly rotate: penguins on the cold edge push inward, and those in the middle get squeezed out.
- **Center:** safe from predators, with a slow energy drain.
- **Edge:** a faster drain, exposed to orca waves, and easy to bump off.
- In multiplayer, players shove for the center. Because a hit on a crowd is shared across it (§4.5), getting in is a walking push, not a bump.
- The waddle shrinks as the ice breaks up.
- **Computer penguins huddle this way (built in the movement toy):** each berg's colony gathers in the middle of its berg. A cold penguin on the windward edge peels off and walks round to the sheltered lee side; a warm one in the middle stops pushing and gets moved toward the wind. So the huddle keeps turning over and everyone takes a turn on the cold edge, but it stays in the middle of its berg rather than creeping off. Sheltered, an NPC burns energy at 0.2 × the base rate; exposed, 0.6 × (TUNING, NPC penguins). The player's waddle drain isn't built yet.

### 4.7 Leaving the waddle: the core decision [Locked as intent, Proposed in detail]

Every departure weighs:

- **My energy:** how long until I'm empty?
- **The next pulse:** where is it forming, and how far is it?
- **The predators:** where are they, and did one just eat (so it's sated)?
- **Other penguins:** is someone fatter than me heading out? Predators go for them first.
- **The way back:** is anyone waiting at the ice edge to bump me back in?

The answer is one of: go now, wait, or go with someone else as bait.

### 4.8 Being thin isn't losing [Proposed]

- The targeting rule (§5.1) favors hungry players: predators chase the fattest penguin, so thin players get the safest feeding windows.
- Two kinds of spilled fish give hungry players a way to catch up: fish from eaten penguins, and fish knocked loose from overfed ones by hard bumps (§4.5).
- A bad first trip should mean a different plan, not a lost round. *Balance check:* players who fell behind early should still win a reasonable share of rounds.

### 4.9 Movement [Proposed]

- **On ice:** walk (a slow waddle) or belly-slide (fast, momentum-based, hard to steer). Tap to flop onto your belly, tap mid-slide for a flipper push, and pull the stick back to dig in and brake. The ice is slick: an unbraked flop glides further than the iceberg is wide. Sliding is also how you bump (§4.5).
- **Slopes:** anything steeper than you can stand on is a chute. Step onto one and you slip onto your belly. Gravity speeds a slide downhill and slows it uphill, so chutes are fast ways down, and you can't walk back up them.
- **Hop:** walk into a ledge or a crack and you hop it automatically, if you can clear it. Hops get lower and shorter as you get fatter; at a ledge that's too tall you try and fall short. On your feet you stop at a gap you can't clear; on your belly you can't stop, so you slide in. (Gap hops are built: the pack ice in the movement toy, §4.10.)
- **In water:** one-thumb steering, plus porpoising (leaping in and out) at speed.
- **Bubble boost:** a burst of speed that costs energy and leaves a trail of bubbles predators can follow. Boosting toward an ice edge launches you out of the water onto the ice. Fat penguins launch lower (§4.4).
- **Air:** a separate breath meter, used only underwater. It forces you to surface, and breathing holes and ice edges are where leopard seals wait.

### 4.10 Ice [Proposed]

- **The iceberg is a 3D plateau, not a flat disc.** Raised tiers are joined by **chutes** (the way down: you slide) and **ledges** (the way up: you hop). Small steps let anyone climb; tall steps are shortcuts only thin penguins can hop. Everywhere else a tier ends in a sheer drop. Height is something to spend: from the top you can launch down a chute toward the food or a rival, but getting back up is slow, and slower when you're fat.
- The iceberg breaks up on a schedule. Cracks open new breathing holes and **gaps** between pieces of ice, and chunks breaking off reshape the route home.
- Thin penguins hop the gaps. Fat ones go the long way around, or swim across past whatever is in the water. Gap routes are the thin penguins' shortcuts.
- The ice shrinks down to the **kill-screen floe** (multiplayer, and late campaign levels).
- **Low exits:** every map needs at least one ramp or low shelf where a penguin can climb out without boosting. Otherwise a penguin with no energy is stuck in the water. Low exits are predictable, so they're also where leopard seals wait (Prototype 1).

#### Bergs [Proposed]

Maps are fields of bergs, and each berg is a platforming puzzle: a way up, routes across, and places only thin penguins reach. The puzzles use only the moves you already have (walk, hop, slide, launch, swim). The bergs are true to real ice (§10):

- **Real shapes and drafts.** Each berg is one of the shapes ice services classify, and sits as deep as that kind does: draft about 5 × its height above water for tabular and wedge bergs, 4 × for domes, 2 × for pinnacles, 1 × for drydocks. Keels run deep, so the water round a berg is open sea, not shallows.
- **Penguin-scale.** 1–6 m above the water, the size of bergy bits and small bergs. A boost launches you about 1.7 m up, so anything taller needs a ramp, a slope or steps.
- **Each kind plays differently:**
  - **Tabular:** flat on top and sheer all round. The only way up is the ice foot, a ramp along one side. A safe top to huddle on, too high for waves.
  - **Wedge:** one long slope to walk up out of the water, to a crest that ends in a cliff.
  - **Drydock:** a U with a sheltered lagoon too shallow for an orca. A seal can still get in.
  - **Pinnacle:** a spire on a low shelf. Steps spiral round it, harder at each tier, up to a lookout, and a chute shoots you back down.
  - **Dome:** too steep to stand on anywhere, so it's one big chute, apart from a worn stair up one side.
- **Tunnels:** caves you walk through, and swim tunnels through keels. A swim tunnel is too narrow for an orca but not for a leopard seal, and it costs air. So it's a way to lose an orca, and a gamble with a seal behind you.
- **Pack ice:** chains of small floes with gaps between them. Thin penguins hop across; fat ones swim.
- **Every berg with a colony has a low exit** (a ramp, a slope or a shelf you can launch onto), per the rule above.
- Built in the movement toy: the home floe plus one berg of each kind, with two chains of pack ice (TUNING, Berg field). Not yet: bergs that drift, roll over or calve, and breathing holes.

### 4.11 Fish and schools [Proposed]

Fish come in species, all based on real Antarctic forage fish. For now every species is worth the same energy (TUNING, Energy); they differ in look, size, speed, how tight they school and how deep they swim.

| Species | Look | Schools | Depth |
|---|---|---|---|
| **Antarctic silverfish** | Silver; the common one | Big, tight schools | Shallow to mid |
| **Lanternfish** | Small and dark, with a faint blue glow | Big, quick schools | Deep |
| **Mackerel icefish** | Big and pale | Small, loose groups | Mid to deep |

- **Fish school with their own kind.** A fish is pulled toward fish of its own species within school range, keeps a little personal space and matches its school mates' heading. It ignores other species, so schools never mix, even when two kinds swim through each other.
- **Schools stay together.** School mates share a home spot they roam around. A lone fish that drifts into range of its own kind joins up and stays, two schools of the same kind that meet merge into one, and an eaten fish comes back beside its school.
- **Most fish spawn in schools,** with a few loose fish in between. Schools are spread around the iceberg, close to its edge, so every side has food within reach.
- Schools are the building block for food pulses (§4.3): a pulse is a school, or several, rising into reach, and a bait ball is a school at its tightest.
- **Sick fish** [Proposed]: about one fish in ten is diseased or full of parasites, and looks it: sickly yellow-green, bloated, blotchy, listing on its side and swimming lamely behind its school. Eat one and you're **queasy** for a few seconds: no boost, no belly-slide, slow and wobbly, the screen swims, and you throw it back up, worth nothing. Grabbing fish in a pass now has a cost: look before you gulp. NPC penguins can tell.
- **Krill swarms** [Proposed]: pink clouds of krill near the surface, what Adélie penguins really live on. Keep your beak in one and you eat steadily: a whole swarm is worth several fish if you stay, which is time spent sitting still near the surface. Eaten out, it forms again nearby later.
- **Squid** [Proposed]: a big meal (two and a half fish) that won't sit still: get close and it jets away squirting ink. It can only jet so often, and runs out after a few, so you chase it down or time a boost (which costs energy).
- [Open] Should species be worth different amounts (a big icefish worth more than a lanternfish)? Should schools react to penguins and predators by scattering or balling up? (§11)

## 5. Predators

### 5.1 Targeting rule [Proposed]

- Predators chase the **most tempting prey nearby**, scored on body size + noise + distance. Bumps count as noise (§4.5), and so does a splash going into the water: a noisy penguin is noticed from farther off than a quiet one [Proposed].
- The lock-on is clearly visible: the predator's shadow and eye turn toward the target, and a ring pulses around it.
- To avoid flickering between targets, a predator only switches when the new target is clearly more tempting.
- Predators only go after what they can see: penguins in the water within sight range, penguins out of the water only right at the edge, and never through ice.
- Lying in ambush and trapping use the same rule. A seal picks where to wait by the most tempting penguin standing near an edge, and an orca pod picks whom to trap the same way.
- Core idea: **you only need to outswim the other penguin, not the predator.**

### 5.2 Predator greed [Locked]

- A predator that eats (a penguin or chum) is **sated and sluggish** for a short time.
- **Hunger** [Proposed]: predators get hungrier over time. A predator hunts penguins and ignores fish until it's **starving**; then it goes to the nearest school and eats fish until it's fed, though it still breaks off to chase a penguin that comes within about 10 m [Proposed]. A starving predator busy at a school is a window to slip past, at a distance.
- In multiplayer, that gives survivors a breather after each elimination, plus a risky chance to grab the fish the eaten penguin spilled.

### 5.3 Roster

| Predator | Behavior | Warning signs |
|---|---|---|
| **Leopard seal** [Proposed] | Patrols the ice edges and the schools. Chases faster than a cruising penguin but slower than a boost, and turns wider than a thin one. Short, fast lunges along a marked line; a lunge reaches a little way onto the ice. **Edge ambush:** lies in wait under the ice edge nearest a penguin standing by it, exactly where it would go in or come back out (and at breathing holes, once there are any). It holds still and lets swimmers come to it, and strikes anyone who comes close in the water with a quicker lunge; a swimmer a little farther off (within about 14 m) brings it out of hiding after them. Go in well away from it, or launch out fast. In the movement toy since Prototype 0. | Shadow under the ice edge, a trail of bubbles, then the lock-on ring; before a lunge the ring flashes and a **strike line** shows where it will go. From an ambush the strike line comes quicker, so the shadow is the warning that counts |
| **Orca pod** [Proposed] | Doesn't chase: it **traps**. It swims in formation, and an orca on its own only goes after a penguin that comes right up to it. Its group attacks play by where you are, and chain into one trap with no rest in between. On the ice: the **wave** (lines up side by side off an ice edge where a penguin stands, charges, and breaks a wave that washes penguins near the edge into the water) and the **ram** (gathers deep under the ice and rams it from below, so the ice tips toward the pod: a small floe tips steeply and everyone on it slides off the low side unless they dig in; the big berg only rocks, but the jolt shoves penguins near the rammed edge toward the water). In the water near the ice: the **cut-off** (a wall of fins forms between you and home and pushes you out to sea; slip through it and you're lunged at). Out in open water: the **carousel** (the pod circles you, blows a wall of bubbles that keeps you in and up at the surface, squeezes the ring, tail-slaps the middle to stun you, and lunges through it). So a wave knocks you in, the cut-off keeps you from getting back, and the carousel finishes you. **Pressing the attack** [Proposed]: an orca aims each lunge where you're going (straight or round the turn you're making), so only a change of course or a boost gets you off its line; when one misses, the next orca of the pod strikes straight away from another side (**relay strikes**, up to three in a row), and while one hunts the others shadow it so one is always close. Its body is a hazard too: touch an orca and you're shoved off it and **dazed** (no boost, slow, your heading drifting, about 2 s), and it strikes at once. Shy of humpbacks (§5.5). Lunges across the floe in the kill screen (not built yet). In the movement toy since Prototype 0. | Wave: fins lining up, the water swelling, then the **danger zone** marked on the ice. Ram: dark shadows gathering under the ice edge, the water bulging, then the danger zone (the whole floe, or a strip of the berg's edge). Cut-off: fins racing to get between you and the ice, then the line you mustn't cross marked on the water. Carousel: dark shapes spreading round you, the **bubble wall**, then the slap zone marked on the water |

### 5.4 Kill screen [Locked]

- The ice shrinks to one small floe, and predators can lunge across it. Nowhere is safe.
- Every lunge gets a clear ~1-second warning (the water bulges, a shadow appears, a line marks the ice).
- Lunges get more frequent until the round ends.
- Dodging costs energy. Penguins who ate the last meal have dodges to spare, but they're fat, slow to turn and targeted first.

### 5.5 Humpback whales [Proposed]

Not a predator: a gentle giant that shares the water, and the one animal orcas back off from. Real humpbacks do both: they feed by blowing bubble nets round fish and lunging up through them, and they're known to break up orca hunts, even for seals and other animals.

- **Looks like an orca from afar.** At the surface, a humpback is a dark back, a fin and a dark shadow, like an orca. Up close it's twice the size, with a little fin far back on a hump, long white flippers, and a slow pace. Its bushy blow when it comes up to breathe (every 25–40 s) and its flukes rising as it dives are its calling cards. Telling the two apart in time is a skill.
- **Never eats penguins.** Its body is still a whale's: swim into it and you're shoved off and dazed, like an orca's (§5.3).
- **Bubble net.** About once a minute it feeds on a fish school in open water: it circles deep under it, blowing a ring of bubbles that closes in over 8 s and herds the fish into a ball at the surface; the water boils in the middle; then it lunges straight up through it and swallows the whole school, which stays gone for 45 s. A penguin in the ring when it comes up is **scooped up and thrown out**: dazed, and a fish comes back up. Never eaten. The ring of bubbles is the warning (white foam, not the danger colour: it isn't an attack), and a prompt tells a penguin inside it to swim clear. It competes with you for schools.
- **Drives orcas off.** When orcas hunt a penguin within 35 m of it (a pod's attack, or an orca after one), it comes over, blowing, and once it's within 10 m of that penguin the orcas give up: a pod calls its attack off. It stays by the penguin for 10 s. Any penguin that close to a humpback is off limits to orcas, so a hunted penguin can swim to one for **refuge**. Leopard seals don't care.
- **Why:** a refuge that moves, and that's easy to mistake for the threat, gives open-water escapes a decision ("is that an orca or a humpback?"), and the bubble net makes schools contested by something other than predators. Both come straight from real whale behaviour.

### 5.6 Feeling the danger [Proposed]

The screen tells you how much trouble you're in, without a meter (ART_DIRECTION, Readability).

- **Anxiety:** with a predator near (you sense it within about 25 m, in sight or not), the edges of the screen slowly darken, closing in from the sides. Closer is darker; one hunting you takes it near full, with a heartbeat throb at its worst. It creeps in and fades slowly, so a dark screen means "something's near, look around", not "dodge now" (the lunge warning is still the strike line).
- **Tunnel vision** while boosting, mild.
- **Hits close the screen in:** a whale's body, a tail slap, a lunge from close by, a hard bump; getting caught blacks it out.
- A **Screen effects** setting turns them down or off.

## 6. Modes

| Mode | Players | Win condition | Status |
|---|---|---|---|
| **Free-for-all** (main multiplayer) | 4–6 penguins, AI predators | Last penguin standing | [Locked] |
| **Single-player campaign** | 1, plus computer-controlled penguins | Depends on the level (§8) | [Locked] length, [Proposed] details |
| **Coop** | 2–4 | [Open] Could reuse campaign level goals | [Proposed] |
| **Asymmetric** (humans as predators) | 1 pod vs. penguins | [Open] | Later |

## 7. Multiplayer round arc [Proposed]

Rounds last under 5 minutes, with an average of about 2 minutes [Locked].

1. **0:00–0:50:** big iceberg, a small pulse near the ice, one leopard seal.
2. **0:50–1:40:** the ice starts breaking up, a medium pulse appears farther out, orcas arrive.
3. **1:40–2:00:** the **last meal**, the biggest and riskiest pulse.
4. **2:00+, kill screen:** one small floe, lunges more and more often, until one penguin is left. Hard cap at 5:00.

Eliminated players leave early, so the average player session is shorter than the round. Requeueing must be instant.

[Open] Does an eaten penguin requeue, or come back as a seal for the rest of the round?

## 8. Single-player campaign [Proposed]

Levels last 5–10 minutes [Locked]. Only the later levels have a kill screen [Locked].

- **Structure:** chapters follow a penguin's year (arrival → raising a chick → fledging → ice breakup). Each chapter introduces one new mechanic or predator, and later chapters end in a kill-screen finale. The campaign doubles as the multiplayer tutorial.
- **Pacing:** with perishable energy, a level is a rhythm of about 4–8 trips. Each level has its own pulse schedule.
- **Computer-controlled penguins** leave the waddle in groups. Going with them is safer (the seal has more targets) but you share the food. Going alone is riskier, but the food is all yours. Built in the movement toy: a hungry NPC waits at the edge facing the nearest school until three are ready (or 20 s have passed), and they go in together, eat, and swim home to their berg (TUNING, NPC penguins).
- **Bumping:** computer-controlled penguins crowd the ice edge and jostle until one goes in (§10), and they bump you too. An early chapter teaches bumping this way.
- **Level goals:**
  - **Journey:** reach a destination through predator territory.
  - **Feast:** fatten up past a target before the ice closes.
  - **Feed the chick:** carry fish home to the chick.
  - **Hold out:** survive until the predators move on.
  - **Breakup:** kill-screen finale. The pod has a visible **hunger meter** that works like a boss's health bar. Survive the lunges and feed the pod chum to fill it; when it's full, the pod leaves. Chum costs the energy you need for dodging.
- **Getting caught:** costs most of your energy instead of ending the level. Being caught while thin ends it, so fat works as armor. Checkpoints on floes are the backup. [Open: energy cost vs. instant fail]
- **Mobile:** instant pause/resume, and an autosave when the app goes to the background. (The pause is built: the pause menu opens by itself when the app goes to the background. No autosave yet.)

## 9. PvP tools [Proposed]

Bumping (§4.5) is the main way to fight. The other tools point predators at rivals.

| Tool | What it does | Cost |
|---|---|---|
| **Bump** | Slide into a rival to knock them off food, off the ice, onto a lunge line or toward a predator. Hard bumps knock fish loose from overfed penguins. | The flop that starts the slide |
| **Chum drop** | Spit up a fish to make a scent cloud that pulls predators. Lure one onto an enemy, or break a chase. | One fish's worth of energy |
| **Bubble trail** | Boost bubbles mark a trail predators follow. Boosting past an enemy leads the predator to them. | Part of the boost |
| **Hiding behind someone** | Stay close to a fatter penguin; predators target them first. | Free |

In coop, the same tools work with the intent reversed: lure predators away from a teammate, drop chum to save one, or bump a teammate out of a lunge's path. [Proposed] Friendly bumps stay fully on, since that's where coop's laughs come from.

## 10. Real-world basis

| Mechanic | Real behavior |
|---|---|
| Bubble boost and launching onto ice | Emperor penguins release air from their feathers to speed up and launch out of the water onto ice |
| Leopard-seal ambush | Leopard seals patrol and lie in wait at ice edges where penguins get in and out of the water |
| Orca waves | Antarctic orcas swim side by side to make waves that wash seals off floating ice |
| Orca carousel | Norwegian orcas herd herring into a tight ball near the surface by circling it, blowing bubbles and flashing their white bellies, then stun the fish with tail slaps |
| Orca cut-off | Orcas hunt as a team, cutting off their prey's escape and herding it away from safety |
| Kill-screen lunges | Orcas in Patagonia deliberately beach themselves to grab sea lions, and leopard seals lunge at ice edges |
| Bumping | Adélie penguins bunch up at the ice edge until one goes in or gets jostled in, and penguins settle fights by shoving and beating each other with their flippers |
| Hopping ledges and gaps | Penguins hop up rocks and ice ledges and across cracks; rockhopper penguins are named for it |
| Food pulses | Krill rise toward the surface at night and sink by day, and diving seabirds mark where fish are |
| Fish schooling by species | Forage fish school with others of their own kind and size. A fish that looks different from its school mates is the easiest one for a predator to pick out (the oddity effect), so mixed schools sort themselves out. Antarctic silverfish and lanternfish are staple penguin food |
| Waddle rotation | Emperor-penguin huddles rotate, with penguins moving from the edge to the center and back. The cold penguins on the windward edge peel off and walk round to the sheltered lee side, so everyone takes turns in the wind, and the huddle slowly travels downwind |
| Berg shapes and drafts | Icebergs are classed by shape (tabular, wedge, dome, pinnacle, drydock, blocky) and by size (growlers under 1 m above water, bergy bits 1–5 m, then small to very large bergs). Most of a berg is under water: the draft is about 1 × the height above water for a drydock, 2 × for a pinnacle, 4 × for a dome and 5 × for tabular and wedge bergs |
| Ice caves and tunnels | Waves and melt carve caves, arches and notches into bergs. (Swim tunnels right through a keel are a game liberty built on this) |
| NPC fishing parties | Adélie penguins crowd at the ice edge before going in, and once one goes, the rest follow, so they go to sea in groups |
| Belly-slide | Penguins slide on their bellies, which is called tobogganing |
| Knocking fish loose | Adélie penguins steal nest pebbles from each other |

## 11. Open questions

1. **Multiplayer elimination:** does an eaten penguin requeue, or come back as a seal?
2. **Single-player catch:** does it cost energy or end the level? (In the movement toy, a catch means you're eaten and respawn; DECISIONS, 2026-10-01.)
3. **Coop win condition.**
4. **Meta loop for D7 retention:** campaign progress alone probably isn't enough. One candidate is **species as unlocks with different stats**, all based on real penguins: Adélie (feisty, balanced), Gentoo (the fastest swimmer), Emperor (big belly, slow turns), Chinstrap, and so on.
5. **Hero species / art look:** which penguin is on the logo and is the default character?
6. **Kill-screen tuning:** should it be nearly impossible to survive without eating the last meal? (Weight now helps fat penguins here too; see the balance checks in §4.5.)
7. **Bump aiming:** is steering a slide with the stick precise enough to aim bumps on a phone, or does a flop need a short aim line?
8. **Bump credit:** should knocking someone into a predator count for anything beyond the kill-feed callout?
9. **Plateau layouts:** how many tiers does a real map want, and do chutes and ledges change as the ice breaks up?
10. **Exhaustion:** what should running empty feel like? Playtesting showed a hard zero is fun but too punishing (you can't slide or boost, so you crawl and get stuck in the water), so the energy floor (§4.2) stands in for now. Candidates: an exhausted state that's slow and low in the water and can't boost, but recovers with rest or a fish. It should also bring back the pressure on campers that the floor takes away (see TUNING).
11. **Fish:** should species be worth different amounts of energy, and should schools react to penguins and predators (scatter, ball up)? See §4.11.

## 12. Glossary

| Term | Meaning |
|---|---|
| **Waddle** | The group of penguins on the ice; the safe zone |
| **Trip** | One departure from the waddle to feed and return |
| **Pulse** | A timed food event at one location |
| **School** | A group of fish of one species swimming together; fish never school with another species |
| **Last meal** | The final and biggest pulse, just before the kill screen |
| **Kill screen** | The final phase: one small floe, predators lunging across it |
| **Chum** | A fish spat up to lure or distract a predator |
| **Sated** | A predator's slow, harmless state right after eating |
| **Lock-on** | A predator's visible choice of target |
| **Strike line** | The line that marks exactly where a predator's lunge will go, shown during the lunge warning |
| **Starving** | A predator hungry enough to eat fish from a school instead of hunting penguins |
| **Pod** | A group of predators that swim and attack together (orcas) |
| **Wave** | An orca pod's attack: it charges an ice edge and washes penguins near it into the water |
| **Ram** | An orca pod's attack: it rams the ice from below and tips it, so penguins slide off a floe or get jolted off the berg's edge |
| **Cut-off** | An orca pod's attack: a wall of fins between a swimming penguin and the ice, pushing it out to sea |
| **Carousel** | An orca pod's attack: it rings a penguin in open water, squeezes, tail-slaps and lunges |
| **Bubble wall** | The ring of bubbles in a carousel: it stops you swimming out (a boost breaks through) and lifts you to the surface |
| **Trap** | A pod's attacks played one after another with no rest: wave or ram, then cut-off, then carousel |
| **Ambush** | A leopard seal lying in wait under the ice edge where a penguin would go in or come out |
| **Stunned** | Hit by an orca's tail slap: no boost, slow turns and slow swimming for a moment |
| **Danger zone** | The ice or water a coming attack will hit, marked in the danger colour |
| **Bump** | Sliding or boosting into another penguin fast enough to knock it back |
| **Hard bump** | A bump fast enough to spin a penguin out or knock a fish loose |
| **Flop** | Diving onto your belly to start a slide; costs a little energy |
| **Teeter** | The moment a penguin on its feet wobbles at the ice edge before falling in |
| **Gap** | A crack between pieces of ice; thin penguins can hop it, fat ones may not |
| **Chute** | A slope too steep to stand on: the way down from a plateau tier |
| **Ledge** | A step up between tiers: hop it if your belly lets you |
| **Berg field** | A map of several bergs, each a climbing puzzle, linked by pack ice and open water |
| **Keel** | The part of a berg under the water, several times deeper than the berg is tall |
| **Ice foot** | A ramp of ice along a berg's side, from the water up to its top |
| **Swim tunnel** | A passage through a berg's keel: room for a penguin or a seal, not an orca |
| **Lagoon** | Sheltered water inside a drydock berg, too shallow for an orca |
| **Pack ice** | A chain of small floes with gaps to hop |
| **Colony** | The NPC penguins that live on one berg and huddle there |
| **Fishing party** | NPC penguins that go into the water together to feed |
