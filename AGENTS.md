# AGENTS.md

Godot 4+ plugin providing a standard library of reusable GDScript utilities for game development.

## Commands

```bash
# Format check (settings in `.gdformatrc`)
gdformat --check .

# Lint (settings in `.gdlintrc`)
gdlint .

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Check project files for problems a normal load does not surface. From the `godot`
# agent plugin, so on Claude's PATH only.
godot-check
```

## Code Style

Follows GDScript style guide. Key project-specific conventions:

### File Structure

- Lines are limited to 88 characters.
- Overridden methods (whether private or engine) go in the `<PRIVATE|ENGINE> METHODS (OVERRIDES)` section.
- Alphabetize methods within their sections.
- Organize files in this section order with visual separators (separators are omitted if section is empty):

  ```gdscript
  ##
  ## std/path/to/file.gd
  ##
  ## Brief description of the file's purpose.
  ##

  extends RefCounted

  # -- SIGNALS ------------------------------------------------------------------------- #
  # -- DEPENDENCIES -------------------------------------------------------------------- #
  # -- DEFINITIONS --------------------------------------------------------------------- #
  # -- CONFIGURATION ------------------------------------------------------------------- #
  # -- INITIALIZATION ------------------------------------------------------------------ #
  # -- PUBLIC METHODS ------------------------------------------------------------------ #
  # -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #
  # -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #
  # -- PRIVATE METHODS ----------------------------------------------------------------- #
  # -- SIGNAL HANDLERS ----------------------------------------------------------------- #
  # -- SETTERS/GETTERS ----------------------------------------------------------------- #
  ```

### Naming

- Class names: `Std` prefix for exported classes (e.g., `StdConfigSchema`)
- Private members: underscore prefix (`_data`, `_mutex`)
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`)

### Loading

- Export a scene, or a resource that carries a script, and set it in the scene that ships the script instead of `preload`ing it, since such a preload can deadlock Godot's threaded loader; the checker's `preload` rule enforces this. Preloading a script is fine.
- Name no 3D class in code, whether in `extends`, a type hint, `is`, `as` or a constructor call. A 2D game's export template is often built with `disable_3d`, which drops `Node3D` and its subclasses, most classes named with `3D` (`World3D`, `PhysicsServer3D`), the XR and glTF classes, the primitive meshes and `WorldEnvironment`, and the engine then fails to parse the script and every script depending on it. The editor keeps 3D, so nothing shows until a 2D export boots. Test a node by name with `is_class(&"Node3D")` instead. std ships no 3D-only script, so the checker's `disable-3d` rule checks every script but the tests for these names.

### Comments

- Use `##` for public API documentation
- Use `# NOTE:` for important implementation details
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Each comment line should use the full line length when possible, but not exceed it; the exception is a URL on the last line.
- Avoid using words like "we", "you", and "I"; comments should use a passive voice that scientifically describes the code

### Coroutines

std is never the top level of a game, since a game calls into all of it, so std doesn't `await` outside GUT test methods. An `await` splits a function across frames, which makes its logic hard to follow, and every caller that wants the result has to await it in turn, which lands the `await` in code that never expected to wait. Using it correctly is subtle even where it belongs:

- The engine never awaits a callback such as `_ready`. The node's `ready` signal fires, and the frame moves on, before the rest of the callback runs, so keep `await` out of engine callbacks.
- Code after an `await` runs in a changed world. Its node may have left the tree or been freed while it waited, so check it again before using it.
- A coroutine called without `await` returns at once without waiting. The `missing_await` warning catches only a direct, typed call, never one through a `Callable`.

Report progress with a status getter paired with a signal, as `is_node_ready()` pairs with `ready`, `StdLoader`'s `Result.is_done()` with `done`, and the screen manager's `is_settled()` with `settled`, and let the game check the getter before awaiting the signal, since a signal that already fired won't fire again.

### Linting

When necessary, use inline directives to suppress expected warnings:

```gdscript
# gdlint:ignore=max-public-methods
return OK  # gdlint:ignore=max-returns
```

## Testing

Tests use GUT framework. Test files end in `_test.gd`. Test cases are named like `test_<subject>_<scenario>_<expectation>` (e.g. `test_config_set_float_updates_value`).

A test that needs a click, key or action to reach a control uses `StdTestInput` rather than emitting a signal or calling the handler. It ships in `dist` so a downstream project's tests can use it. Its `mount` awaits, which is allowed because only GUT tests call it.

A test of a scene that uses the screen stack pushes it onto a `StdTestScreenManager`, which ships and awaits on the same terms, rather than copying what the stack does into the scene.

### Test Structure

Use BDD-style Given/When/Then comments:

```gdscript
extends GutTest

func test_config_set_float_updates_value():
    # Given: A new, empty 'Config' instance.
    var config := Config.new()

    # When: A float value is set.
    config.set_float("category", "key", 1.0)

    # Then: The value is present.
    assert_true(config.has_float("category", "key"))
    assert_eq(config.get_float("category", "key", 0.0), 1.0)
```

## Commits

Use Conventional Commits format. Examples:

- `feat(input): add gamepad rumble support`
- `fix(config): prevent race condition in file sync`
- `chore(deps): bump actions/checkout`

Release automation via release-please triggers on merge to main.
