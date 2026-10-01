# Fat Penguin — Roadmap

Last updated: 2026-10-01

Each prototype answers one question. Don't move on until the current one's answer is "yes," or until you've changed the design and written down why in [DECISIONS.md](DECISIONS.md).

---

## Prototype 0: Movement toy (1–2 weeks)

**Status: in progress.** A placeholder version is playable (`levels/movement_toy`), with every verb below working and covered by the headless smoke test. Next steps: playtest on a phone, tune the feel, and swap in a real penguin model.

**Question:** is swimming, boosting and launching onto the ice fun with no goals at all?

**In scope**

- One penguin, a 3D water volume, an iceberg with edges
- Swimming with one-thumb steering (plus a mouse/keyboard fallback for desktop testing)
- Porpoising at speed
- Bubble boost and launching out of the water onto the ice
- On ice: walk and belly-slide
- Eating fish (static fish, no AI) and body size changing with energy
- Fat vs. thin handling (turn rate, acceleration, launch height)
- Air meter
- **Added with the bumping decision (not built yet):** a few dummy penguins of different sizes to slide into, to feel out mass, feet vs. belly, and teetering at the edge

**Out of scope:** predators, food pulses, the waddle, multiplayer, menus, art polish.

**Success signals**

- Testers keep playing without being asked, just to launch and slide around
- They try to chain moves (boost → launch → slide → dive)
- They can feel the fat/thin difference without being told
- They knock the dummies off the ice just to watch them go

## Prototype 1: Energy loop + leopard seal

**Question:** does deciding when to leave the waddle create real tension?

**In scope**

- Energy drain, the overfill drain, and slower drain in the waddle
- Food pulses, with their warning signs and schedule
- The waddle as a safe zone (center vs. edge)
- One leopard seal: ambushes at edges and holes, targeting rule, visible lock-on, sated state
- Chum drop
- A short level built around a single-player goal (Journey or Feast)

**Success signals**

- Players leave the waddle **at least twice** per session without being prompted
- Players hesitate at the edge and watch the seal before diving
- Players tell near-miss stories without being asked
- Nobody wins by eating everything early and then hiding

## Prototype 2: Shrinking ice + orcas + kill screen + coop

**Question:** does the kill screen feel fair and exciting, and does coop make people laugh?

**In scope**

- The ice breaking up on a schedule, new breathing holes, gaps to hop, the shrinking waddle
- Orca pod: waves that wash penguins off the ice, kill-screen lunges with warnings, hunger meter
- The last-meal pulse
- 2–4 player coop (local or online), with bumping (friendly bumps on)
- A coop win condition (to be decided)

**Success signals**

- Deaths in the kill screen feel like "I misjudged it," not random
- Players argue about whether to go for the last meal
- People laugh at bumps

## Prototype 3: Free-for-all PvP

**Question:** do bumping rivals and luring predators onto them make PvP that's fun and feels fair?

**In scope**

- 4–6 player free-for-all with AI predators, last standing wins
- Full round arc (~2.5 minutes typical, 5:00 cap)
- Bumping tuned for PvP: fish spills from overfed penguins, bump noise, "bumped into the jaws" credit in the kill feed
- Bubble trail, hiding behind someone, fish spilling from eaten penguins
- An answer to the elimination question (requeue vs. coming back as a seal)

**Success signals**

- Players deliberately bump and lure predators onto opponents
- Getting bumped into a predator feels like "I should have stood my ground," not cheap
- Thin players rob overfed leaders with hard bumps, and the kill screen isn't just the fattest penguin pushing everyone off
- Players who fell behind early still win a reasonable share of rounds
- Average player session is about 2 minutes, and players requeue right away

## Later

- Asymmetric mode (humans as predators)
- Meta loop and progression (possibly species unlocks)
- Launch metrics: D1/D7 retention, session length, coop assists, deaths by predator type, bump-assisted eliminations, how often players who fell behind still win
