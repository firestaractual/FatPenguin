# Fat Penguin: notes for Claude

Mobile 3D game in **Godot 4.7.2, GDScript, Mobile renderer**. The design lives in `docs/`; read `docs/GDD.md` before changing gameplay.

## Ground rules

- **Balance numbers live in one place:** `tuning/penguin_tuning.gd` (the class) and `tuning/penguin_tuning_default.tres` (the values), mirrored in `docs/TUNING.md`. Fish species work the same way: `tuning/fish_species.gd` (the class) and `tuning/fish/*.tres` (one per species), and so do predators: `tuning/predator_tuning.gd`, `tuning/pod_tuning.gd`, `tuning/pod_attack_tuning.gd` (+ one subclass per attack) and `tuning/predators/*.tres`. Don't hard-code tuning values in gameplay scripts.
- **Predators are built from shared parts; add new kinds the same way.** Every predator is `actors/predators/predator.gd` (`Predator`: swimming, sight, targeting, hunger, feeding, the lunge and its warnings); a kind is a `PredatorTuning` resource plus a scene with a `Model` node. Pods (`PredatorPod`) keep formation and run group attacks; an attack is a `PodAttack` subclass (on the ice `EdgeAttack`: `WaveAttack`, `RamAttack`; in the water `CutOffAttack`, `CarouselAttack`) plus a `PodAttackTuning` resource listed in the pod's `PodTuning.attacks`, and attacks chain into traps with `chains_into`. Pods give orders with `Predator.order_move()` and `order_strike()`. Ice that attacks can tip is marked with `TippableIce` (`levels/tippable_ice.gd`); questions about where the ice ends go through `IceEdges` (`levels/ice_edges.gd`). Levels spawn predators from `PredatorSpawn` entries through a `PredatorSpawner`. Shoves from outside (waves, jolts) go through `Penguin.push()`, currents (bubbles) through `Penguin.drift()`, and stuns through `Penguin.stun()`.
- **Design changes get a log entry:** add a dated entry at the top of `docs/DECISIONS.md`, and update the status tags in `docs/GDD.md` (`[Locked]` / `[Proposed]` / `[Open]`).
- **Naming:** "waddle" means the safe group of penguins on the ice. The slow on-ice gait is called **walk** in code (`State.WALK`, `walk_speed`) so the two don't get confused.
- **Water line:** the water surface is `y = 0` (`Penguin.WATER_LEVEL`). Anything below is water.
- **Penguin body:** a sphere collider that never rotates. Only the `Model` node turns and changes width, so physics stays simple and art can be swapped freely.
- **Physics layers:** layer 1 is the world (ice, seafloor), layer 2 is penguins (`Penguin.WORLD_LAYER`, `Penguin.PENGUIN_LAYER`), layer 3 is predators (`Predator.PREDATOR_LAYER`). Ground and ledge probes ray-cast against the world layer only, so penguins never mistake each other for ice. Predators collide with the world only; their catches are by distance, not collision.
- **Bumps:** penguin-on-penguin hits are resolved by hand in `Penguin._bump()` after every `move_and_slide` (call `_move()`, not `move_and_slide()`, in movement states). Dummies are ordinary penguins with `player_controlled = false`.
- **Input:** gameplay reads only the input actions (`move_*`, `action`). Touch controls feed those same actions through `Input.action_press`, so don't read touch events directly in gameplay code.
- **Typing:** use static typing throughout (`var x := ...`, typed function signatures).

## Before finishing a change

Run the headless smoke test and make sure it passes:

```
godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd
```

When you add a new movement verb, add a check for it to that test.
