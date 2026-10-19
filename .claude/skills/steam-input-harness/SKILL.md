---
name: steam-input-harness
description: Run std's Steam Input components against a real controller through the Steam client, for the questions the headless suite cannot answer (stick sign, publish-on-change, pointer warps, origins and glyphs, rebinds). Claude drives the window and reads the results; a person supplies the controller input.
user-invocable: true
argument-hint: "[app id]"
---

Mount std's Steam joypad monitor, actions and glyph components under a real `StdInputSlot`, in a window, with the Steam client running, and walk a person through scripted controller steps while the harness logs what each component reports. Everything but pressing the controller can be driven from the terminal.

## When to use it

GUT covers the Steam components only where they can be exercised without Steam (`input/steam/*_test.gd`, which skip when the `Steam` class is absent, as it is on Linux CI since the submodule ships Windows and macOS binaries only). Reach for the harness when the question is what Steam actually sends: a stick's `y` sign, whether a held stick reports once, trigger thresholds, `absolute_mouse` warps, origin counts and glyph cycling, or `input_configuration_loaded` after a rebind.

## Prerequisites

- The Steam client is running and logged in, on the host OS the GodotSteam submodule has a library for (`addons/godotsteam/win64` or `osx`).
- A controller is connected and its family is enabled under Steam > Settings > Controller (PlayStation support for a DualShock, and so on).
- Nothing else is running as the app ID. Spacewar (480) open in Steam is harmless to init but confusing in the logs; close it.

## Steps

1. **App ID.** Put the ID in `steam_appid.txt` beside `project.godot` (`480`, Valve's test app, unless the game has its own). Both this file and `zz_harness/` are git-ignored in std; in a game, ignore them there too.

   ```sh
   printf 480 > steam_appid.txt
   ```

2. **Copy the harness** from this skill's directory into `zz_harness/` at the project root. The scene references `res://zz_harness/harness.gd`, and the script finds std's input directory from `StdInputSlot`'s script path, so it runs in std itself and in a game with std at `addons/std`.

   ```sh
   mkdir -p zz_harness && cp .claude/skills/steam-input-harness/harness.* zz_harness/
   godot --headless --path . --check-only -s res://zz_harness/harness.gd
   ```

3. **Run it in the background** and read `zz_harness/results.log`. It writes `zz_harness/game_actions_<appid>.vdf` from the harness action set, starts Steam, then mounts the components.

   ```sh
   godot --path . res://zz_harness/harness.tscn > zz_harness/stdout.log 2>&1
   ```

   The first lines say whether `steamInitEx` succeeded and whether Steam knows the set: `current steam set handle=N (Harness=M)`. `Harness=0` means Steam loaded some other manifest, which is the next step.

4. **Install the manifest where Steam reads it.** Steam takes `game_actions_<appid>.vdf` from its own `controller_config` folder before anything else, and `setInputActionManifestFilePath` returns `false` whenever a file is there, so the in-code override cannot win. Back up whatever is in the folder (it is outside the repo, so say what is being replaced), copy the harness manifest in, and relaunch; the Steam client does not need a restart.

   ```sh
   CC="/c/Program Files (x86)/Steam/controller_config"   # ~/Library/Application Support/Steam/controller_config on macOS
   cp "$CC/game_actions_480.vdf" "$CC/game_actions_480.bak" 2>/dev/null
   cp zz_harness/game_actions_480.vdf "$CC/game_actions_480.vdf"
   ```

5. **Bind a layout once.** A manifest alone binds nothing; the `bindings` step waits until `jump` has an origin. The person presses F1 in the harness window (it calls `showBindingPanel` for the pad) or opens Big Picture > the app > Controller settings, binds the Harness set and saves the layout privately:

   | Control | Mode | Action |
   | --- | --- | --- |
   | Left stick | Joystick | `move` |
   | Cross / A | Button | `jump` |
   | Circle / B | Button | `cancel` |
   | Right trigger | Analog trigger | `fire` |
   | Right stick or trackpad | Mouse | `pointer` |
   | Any second button | Button | `jump` (lets the cycling step see two origins) |

   Steam picks the active config from the foreground window, so the harness window must have focus while testing. If the config keeps switching, open `steam://forceinputappid/480` in a browser and `steam://forceinputappid/0` afterwards.

6. **Follow the on-screen steps.** Each step ends by itself when its condition is met; Enter skips one, F2 toggles a captured cursor. After the window closes, read `zz_harness/results.log`.

   | Step | Confirms |
   | --- | --- |
   | `stick_up`, `stick_left` | Steam's `+y` is up: `move_up` carries the strength and `get_vector` reads `(0, -1)` |
   | `hold_counts`, `hold_release` | publish-on-change: one just-pressed for a 3 s hold, one just-released after it |
   | `jump_presses` | digital presses arrive once each; `native joypad events seen` says whether Godot also saw the pad |
   | `switch_kbm_while_held`, `reactivate_joypad`, `stick_held_while_typing` | a bound key activates the keyboard while a joypad action is held, and the hold never reactivates the joypad; a fresh press does |
   | `trigger` | the strength at which `fire` reads pressed is the InputMap deadzone |
   | `pointer`, `pointer_slow` | `absolute_mouse` warps the pointer, activates the joypad, reveals the cursor, and sub-pixel motion creeps through the warp remainder |
   | `captured` | captured mode delivers motion events at the pointer's position; the button at the origin never hovers |
   | `origins` | origin counts, labels, glyph sizes, and the index sequence a cycling glyph draws |
   | `rebind` | `action_configuration_changed` after a change in Steam's panel |
   | `disconnect` | a held action releases when its pad disconnects; the hot-plug does not change the active device |

7. **Clean up.** Close the window, restore the backed-up manifest if the person wants it, reset `steam://forceinputappid/0` if it was set, and delete `zz_harness/` and `steam_appid.txt`.

## Testing a game's own manifest

Replace step 2 to 4 with the game's manifest: `godot --headless -s addons/std/input/steam/write_in_game_actions.gd` writes `game_actions_<appid>.vdf` beside `project.godot`, and copying it into `controller_config` as above lets the Steam client use it for that app ID. The harness action set can then be swapped for one of the game's sets in `_build_action_set`.

## Traps

- **`setInputActionManifestFilePath` returns false** while `controller_config/game_actions_<appid>.vdf` exists, whatever the path; the folder wins. Valve's docs call the override the path for running outside Steam, but say nothing about the return value.
- **A legacy or workshop config bound to the app** gives a connected pad with no actions: Steam's `logs/controller.txt` shows `Failed to create digital binding ...` lines. Build a private layout for the manifest's set and select it.
- **`Steam.getConnectedControllers()` is empty** until `RunFrame` has run; the monitor connects the pad from `input_configuration_loaded`, which is what the harness waits on.
- **The keyboard glyph component is a stub** (`NoGlyphs`), since `StdInputDeviceGlyphs` asserts on its unimplemented hooks and a cycling glyph asks it while the keyboard is active.
- **The window must be focused** for keys and for Steam to apply the app's config. A headless run cannot do any of this.
- **`--check-only` catches most script errors** before a window is opened; inner classes of `@tool` bases need the harness to be `@tool` too.
