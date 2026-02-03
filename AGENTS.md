# AGENTS.md

Godot 4+ plugin providing a standard library of reusable GDScript utilities for game development.

## Commands

```bash
# Format check (line length 88)
gdformat -l 88 --check **/*.gd

# Lint
gdlint **/*.gd

# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit

# Install Godot version
gdenv i
```

## Code Style

Follows GDScript style guide. Key project-specific conventions:

### File Structure

Organize files in this section order with visual separators (separators are omitted if section is empty):

```gdscript
##
## std/module/file.gd
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

Lines are limited to 88 characters (including comments).

### Naming

- Class names: `Std` prefix for exported classes (e.g., `StdConfigSchema`)
- Private members: underscore prefix (`_data`, `_mutex`)
- StringNames: use `&` prefix for literals (`&"category"`, `&"key"`)

### Comments

- Use `##` for public API documentation
- Use `# NOTE:` for important implementation details
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`

### Linter Suppressions

When necessary, use inline directives:

```gdscript
#gdlint:ignore=max-public-methods
return OK  # gdlint:ignore=max-returns
```

## Testing

Tests use GUT framework. Test files end in `_test.gd`.

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
