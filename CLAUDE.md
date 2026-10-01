# Fat Penguin: notes for Claude

Mobile 3D game in **Godot 4.7.2, GDScript, Mobile renderer**. The design lives in `docs/`; read `docs/GDD.md` before changing gameplay.

## Ground rules

- **Balance numbers live in one place:** `tuning/penguin_tuning.gd` (the class) and `tuning/penguin_tuning_default.tres` (the values), mirrored in `docs/TUNING.md`. Don't hard-code tuning values in gameplay scripts.
- **Design changes get a log entry:** add a dated entry at the top of `docs/DECISIONS.md`, and update the status tags in `docs/GDD.md` (`[Locked]` / `[Proposed]` / `[Open]`).
- **Naming:** "waddle" means the safe group of penguins on the ice. The slow on-ice gait is called **walk** in code (`State.WALK`, `walk_speed`) so the two don't get confused.
- **Water line:** the water surface is `y = 0` (`Penguin.WATER_LEVEL`). Anything below is water.
- **Penguin body:** a sphere collider that never rotates. Only the `Model` node turns and changes width, so physics stays simple and art can be swapped freely.
- **Input:** gameplay reads only the input actions (`move_*`, `action`). Touch controls feed those same actions through `Input.action_press`, so don't read touch events directly in gameplay code.
- **Typing:** use static typing throughout (`var x := ...`, typed function signatures).

## Before finishing a change

Run the headless smoke test and make sure it passes:

```
godot --headless --fixed-fps 60 --path . --script res://tests/movement_smoke_test.gd
```

When you add a new movement verb, add a check for it to that test.
