---
name: steam-input-harness
description: Run std's Steam Input components against a real controller through the Steam client, for the questions the headless suite cannot answer (stick sign, publish-on-change, pointer warps, origins and glyphs, rebinds, hot-plug typing). Claude drives the window and reads the results; a person supplies the controller input.
user-invocable: true
argument-hint: "[app id]"
---

Mount std's Steam joypad monitor, actions and glyph components under a real `StdInputSlot`, in a window, with the Steam client running, and walk a person through scripted controller steps while the harness logs what each component reports. Everything but the controller can be driven from the terminal.

## When to use it

GUT covers the Steam components only where they run without Steam (`input/steam/*_test.gd`, which skip when the `Steam` class is absent, as on Linux CI). The harness answers what Steam actually sends: a stick's `y` sign, whether a held stick reports once, trigger thresholds, `absolute_mouse` warps, origin counts and glyph cycling, `input_configuration_loaded` after a rebind, and the family a pad connected before the slot gets.

## Running it

Needs the Steam client running and logged in on Windows or macOS (the GodotSteam submodule ships no Linux library), a controller whose family is enabled under Steam > Settings > Controller, and nothing else running as the app ID (close Spacewar when using 480).

```sh
printf 480 > steam_appid.txt     # git-ignored; the game's own ID when it has a manifest
godot --path . -s res://.claude/skills/steam-input-harness/run.gd -- --late-slot > /dev/null 2>&1 &
```

Run it in the background and read `results.log` beside the harness. User arguments after `--`: `--appid=N` (default 480); `--late-slot`, which mounts the slot only after Steam connected a pad so the monitor's broadcast path is exercised; `--from=<step>` to jump to a step; and `--all` to run the steps the `CONFIRMED` list in `harness.gd` marks as confirmed on hardware, which a default run skips so it covers only what is still open. The first lines say whether `steamInitEx` succeeded and `current steam set handle=N (Harness=M)`; `Harness=0` means Steam loaded another manifest. The window must keep focus, since Steam applies a layout by foreground window and the keys need it: Enter skips a step, F1 opens Steam's binding panel for the pad, F2 toggles a captured cursor.

In a game, std sits under `addons/std` and the harness finds its scripts from `StdInputSlot`'s path, so `harness.gd` and `run.gd` work from any directory under `res://`.

## The manifest

Steam reads `game_actions_<appid>.vdf` from its own `controller_config` folder ahead of the path given to `setInputActionManifestFilePath`, which returns `false` while such a file exists. The harness writes its manifest beside itself; install it there (the folder is outside the repo, so say what is being replaced). No Steam restart is needed.

```sh
CC="/c/Program Files (x86)/Steam/controller_config"   # macOS: ~/Library/Application Support/Steam/controller_config
cp "$CC/game_actions_480.vdf" "$CC/game_actions_480.bak" 2>/dev/null
cp .claude/skills/steam-input-harness/game_actions_480.vdf "$CC/"
```

To test a game's own manifest instead, `godot --headless -s addons/std/input/steam/write_in_game_actions.gd` writes it beside `project.godot`; install it the same way and swap the harness action set for one of the game's in `_build_action_set`.

## The layout

A manifest binds nothing until the Steam account has a layout for it, so the `bindings` step waits until `jump` has an origin. Steam keeps the layout per account and pad type, so this happens once. Bind it in the panel F1 opens (or Big Picture > the app > Controller settings) and save it privately:

| Control | Mode | Action |
| --- | --- | --- |
| Left stick | Joystick | `move` |
| Cross / A | Button | `jump` |
| Circle / B | Button | `cancel` |
| Right trigger | Analog trigger | `fire` |
| Right stick or trackpad | Mouse | `pointer` |
| Any second button | Button | `jump` (lets the cycling step see two origins) |

Steam autosaves the selected layout as plain VDF at `Steam/steamapps/common/Steam Controller Configs/<account id>/config/<app id>/controller_<type>.vdf` (`Steam/userdata/` lists the account id). A copy of that file, placed at the same path on another account or machine, installs the layout without the panel; keep one under `layouts/` here when a person exports it. If the active layout keeps switching, open `steam://forceinputappid/480` in a browser and `steam://forceinputappid/0` afterwards.

## The steps

Each step ends by itself when its condition is met; Enter skips one. When a step's behaviour is confirmed, add it to `CONFIRMED` so later runs stay short; a change to the component it covers is the reason to run with `--all` again. Steps that expect an activation ask for the other device first (the pointer step says to press Space), and a real mouse moving during the pointer steps counts as motion.

| Step | Confirms |
| --- | --- |
| `connect` | the pad connects with its family; with `--late-slot`, through the monitor's broadcast |
| `rest` | a resting stick and trigger read exactly 0 under the layout's deadzone and never activate the joypad over the keyboard; the stick's four directions carry a deadzone near 0 |
| `stick_up`, `stick_left` | Steam's `+y` is up: `move_up` carries the strength and `get_vector` reads `(0, -1)` |
| `hold_counts`, `hold_release` | publish-on-change: one just-pressed for a 3 s hold, one just-released after it |
| `jump_presses` | digital presses arrive once each; `native joypad events seen` says whether Godot also saw the pad |
| `switch_kbm_while_held`, `reactivate_joypad`, `stick_held_while_typing` | a bound key activates the keyboard while a joypad action is held, the hold never reactivates the joypad, a fresh press does |
| `trigger` | `fire` reads pressed at its first strength above 0, since Steam rescales it from the layout's deadzone |
| `pointer`, `pointer_slow` | `absolute_mouse` warps the pointer, activates the joypad from the keyboard, reveals the cursor, and sub-pixel motion creeps through the warp remainder |
| `reveal_60`, `reveal_240` | the pointer speed at which the cursor reveals is the same at both frame rates |
| `captured` | captured mode delivers motion events at the pointer's position; the button at the origin never hovers |
| `origins` | origin counts, labels, glyph sizes, and the index sequence a cycling glyph draws |
| `rebind` | `action_configuration_changed` once after a change in Steam's panel |
| `disconnect` | a held action releases when its pad disconnects; a reconnect activates it again only because no device was active |

## Traps

- **Handles overlap across kinds.** Steam numbers digital and analog action handles separately, so `jump` and `move` can both be `1`; the components keep a map per kind, and a handle alone names nothing.
- **A legacy or workshop layout bound to the app** gives a connected pad with no actions. `Steam/logs/controller.txt` shows `Failed to create digital binding ...` lines; `controller_ui.txt` says which layout loaded.
- **`Steam.getConnectedControllers()` is empty** until Steam's first frame; the monitor connects a pad from `input_configuration_loaded`, which is what the harness waits on.
- **The keyboard glyph component is a stub** (`NoGlyphs`), since `StdInputDeviceGlyphs` asserts on its unimplemented hooks and a cycling glyph asks it while the keyboard is active.
- **`--check-only` catches most script errors** before a window opens; inner classes of `@tool` bases need the harness to be `@tool` too.

## References

- In-Game Actions file format: https://partner.steamgames.com/doc/features/steam_controller/iga_file
- `ISteamInput` API, with handles, origins, glyphs and the manifest override: https://partner.steamgames.com/doc/api/ISteamInput
- Steam Input for developers, including testing outside Steam: https://partner.steamgames.com/doc/features/steam_controller/getting_started_for_devs
- GodotSteam's Input class, for the function and signal names used here: https://godotsteam.com/classes/input/

## Cleaning up

Close the window, delete `steam_appid.txt`, restore the backed-up manifest if wanted, and reset `steam://forceinputappid/0` if it was set. The harness's `results.log`, `stdout.log` and `game_actions_*.vdf` are git-ignored.
