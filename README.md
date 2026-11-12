# godot-plugin-std

A Godot 4.7+ plugin providing standard GDScript functions and components.

## Usage

### Add as a dependency

Add this repository's `dist` branch as a submodule of a Godot project, typically under the `addons` directory:

```sh
git submodule add -b dist https://github.com/coffeebeats/godot-plugin-std addons/std
```

Each release is a commit on `dist`, tagged `dist/vX.Y.Z`. Versions follow semantic versioning independently of Godot; raising the minimum Godot version is a major release.

### Plugin API

#### **`config`**

The [config](./config) directory contains replacement classes for `ConfigFile`, [which shouldn't be used due to security issues](https://github.com/godotengine/godot/issues/80562). The [`Config`](./config/config.gd) class is an in-memory, typed, categorized key-value store. To synchronize the configuration data to the file system, use [`ConfigWithFileSync`](./config/file.gd) instead.

#### **`fsm`**

The [fsm](./fsm) directory contains an implementation of a hierarchical [`StateMachine`](./fsm/state_machine.gd) suited for most applications. State machines are constructed as a scene with the node hierarchy used to define the level of state nesting. Each state should utilize a custom script to implement its behavior, and users can input events into the state machine to trigger transitions or update states.

Additionally, the [`StateMachine`](./fsm/state_machine.gd) implementation provides a "compaction" process which is enabled by default. The state machine extracts the scripts of all child [`State`](./fsm/state.gd) nodes and stores those objects internally without adding children to the scene tree. This improves performance, especially for state machines which are instantiated often.

#### **`input`**

> [!NOTE]  
> [GodotSteam](https://github.com/GodotSteam/GodotSteam) is a peer-dependency for Steam-backed implementations of certain classes (e.g. `JoypadMonitor` and multiple `StdInputDevice` components). The `GodotSteam` addon must be installed alongside this one, from the `dist` branch of [coffeebeats/GodotSteam](https://github.com/coffeebeats/GodotSteam).

The [input](./input) directory contains types for setting up an action set-based input system, along with abstractions for device and player slot APIs. When used, both Steam and Godot-backed implementations can be easily switched between.

An [action set](./input/action_set.gd) is a mode of play, and loading one unbinds everything else. A [layer](./input/action_set_layer.gd) adds to the set named by its required `parent`, and keeps every binding below it that it doesn't override. UI that takes over input loads a set and lists a layer under it for what stays live; overriding a binding doesn't turn an action off. A layer several sets enable is one file per set, and every set and layer has its own name.

Every connected device stays accepted at all times. The active device only picks which glyphs are shown. It changes on a key, button, or stick (past its deadzone) bound to a loaded action, or on a reveal-button click while `cursor_click_activates_kbm` is on. Mouse motion never changes it, following Valve's [Steam Deck guidance](https://partner.steamgames.com/doc/steamhardware/recommendations). The cursor is tracked separately. A reveal-button click or mouse motion past a threshold reveals it, and the hide actions hide it.

Off Steam, the [Godot glyph provider](./input/godot/device_glyphs.gd) draws origins from its `glyph_sets` and names them from its `origin_names`, a list of [`StdInputOriginNames`](./input/godot/origin_names.gd) that map joypad buttons, each direction of a joypad axis, mouse buttons and keys to translation keys. Both lists are searched in order among the entries whose `device_types` match the device, so a specific resource placed first overrides a general one, and a joypad type that nothing matches uses the `GENERIC` entries. std ships no names, so without an entry a key is named by its label in the player's keyboard layout, and a joypad or mouse origin has no name. Each resource's `translation_context` is the context its keys are translated in, so two names sharing English text, such as two platforms' Share buttons, can be translated apart. A translation key with no translation asserts in debug builds and counts as no entry in release builds. Steam names the origins it drives itself.

#### **`iter`**

The [iter](./iter) directory contains helpful functions for interacting with sequences and collections of various types.

#### **`load`**

The [load](./load) directory contains [`StdLoader`](./load/loader.gd), which runs the process's threaded resource loads one at a time. `request` returns a `Result` that reports through `done` once its load ends, from the loader's per-frame step and never inside the caller's stack; check `is_done` first, since a cached resource is done at once. `load_now` is the one blocking load: it returns a cached resource at once, waits only for the load it names, and warns when a load is slow.

Godot 4.6 to 4.8 deadlock when a script compiling on one thread waits in the loader for a resource another thread is loading, and a `preload` of a scene or a custom resource is the usual way in. Export the `PackedScene` or `Resource` and set it in the scene instead; godot-infra's `preload` checker rule reports the rest.

#### **`scene`**

The [scene](./scene) directory contains an implementation of a [`StateMachine`](./fsm/state_machine.gd) specialized for declaratively managing scene transitions. See the [examples folder](./scene/example/) for a sample main scene.

#### **`screen`**

The [screen](./screen) directory contains [`StdScreenManager`](./screen/manager/manager.gd), a stack of [`StdScreen`](./screen/screen.gd)s where each screen covers the one below it.

Operations run one at a time, in call order. One opening a screen whose scenes aren't loaded changes nothing until [`StdLoader`](./load/loader.gd) has loaded them, the screen's own scene first, with input blocked and later calls queued behind it, so mounting never loads. `load_screen` starts those loads in the background and returns a preparation which keeps them loaded while held. `is_settled` and `settled` report when no operation is left, and `screen_load_failed` when a screen couldn't open, leaving the stack as it was. A call that arrives while a transition runs completes that operation first, skipping the rest of its animation.

A screen's `cache_mode` keeps its scene between uses: `DETACHED` out of the tree, or `IN_TREE` parked in its own hidden overlay, built with the first screen listing it under `dependency_screens`, so opening it, with no transition, only shows it.

A [`StdPanel`](./screen/panel.gd) instead opens UI, such as a build or context menu, over a running scene that a screen would cover. It runs its control's transition, closes on its close actions and on a press outside the control, and follows the control's visibility.

#### **`test`**

The [test](./test) directory contains helpers for a project's GUT tests. [`StdTestInput`](./test/input.gd) mounts a scene at the root viewport under `--headless` and sends it real mouse motion, clicks, keys and actions through `Input`, so a test covers picking, focus and polled state.

A scene run on its own, by F6 or in a test, has no [`StdScreenManager`](./screen/manager/manager.gd) among its ancestors, so it has no stack to push onto. [`StdTestScreenManager`](./test/screen_manager.gd) is a manager whose `push_and_wait` waits for the manager to settle and returns the scene. A test that also clicks through what the scene pushes mounts the manager with `StdTestInput` before pushing.

## **Development**

### Setup

The following instructions outline how to get the project set up for local development:

1. Clone this repository using the `--recurse-submodules` flag, ensuring all submodules are initialized. Alternatively, run `git submodule sync` to update all submodules to latest.
2. [Follow the instructions](https://github.com/coffeebeats/gdenv/blob/main/docs/installation.md) to install `gdenv`. Then, install the [pinned version of Godot](./.godot-version) with `gdenv i`.
3. [Install `uv`](https://docs.astral.sh/uv/getting-started/installation/), then run `uv sync`. That installs the Python tooling from [`uv.lock`](./uv.lock), and downloads the interpreter named by [`.python-version`](./.python-version) if the machine has none. Invoke each tool as `uv run <tool>`.
4. The edit checks and `godot-check` come from the `godot` agent plugin, declared in [`.claude/settings.json`](./.claude/settings.json) for Claude Code and [`.codex/config.toml`](./.codex/config.toml) for Codex. Claude Code installs it once per machine with `claude plugin install godot@godot-infra --scope project`. Codex installs it itself once the folder is trusted, then asks you to trust the edit hook in `/hooks`, and asks again whenever that hook changes — until you do, it silently does nothing. If the hook or `godot-check` goes missing, see the "Agent plugin" section of [godot-infra's README](https://github.com/coffeebeats/godot-infra#agent-plugin).

### Code submission

When submitting code for review, ensure the following requirements are met:

1. The project adheres as closely as possible to the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).

2. The project is correctly formatted using [gdformat](https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter):

    ```sh
    uv run gdformat --check .
    ```

3. All [gdlint](https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter) linter warnings are addressed:

    ```sh
    uv run gdlint .
    ```

4. All [Gut](https://github.com/bitwes/Gut) unit tests pass:

    ```sh
    godot \
        --headless \
        -s addons/gut/gut_cmdln.gd \
        -gdir="res://" \
        -ginclude_subdirs \
        -gprefix="" \
        -gsuffix="_test.gd" \
        -gexit
    ```

## **Releasing**

[Semantic Versioning](http://semver.org/) is used for versioning and [Conventional Commits](https://www.conventionalcommits.org/) is used for commit messages. A [release-please](https://github.com/googleapis/release-please) integration via [GitHub Actions](https://github.com/googleapis/release-please-action) automates releases.

## **Version history**

See [CHANGELOG.md](https://github.com/coffeebeats/godot-plugin-std/blob/main/CHANGELOG.md).

## **License**

[MIT License](https://github.com/coffeebeats/godot-plugin-std/blob/main/LICENSE)
