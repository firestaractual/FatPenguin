# Fat Penguin — Decision Log

Newest first. Each entry records what was decided and why. To reverse a decision, add a new entry rather than editing an old one.

---

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
