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

### Comments

- Use `##` for public API documentation
- Use `# NOTE:` for important implementation details
- Assertions for preconditions: `assert(category != "", "invalid argument: missing category")`
- Each comment line should use the full line length when possible, but not exceed it; the exception is a URL on the last line.
- Avoid using words like "we", "you", and "I"; comments should use a passive voice that scientifically describes the code

### Linting

When necessary, use inline directives to suppress expected warnings:

```gdscript
# gdlint:ignore=max-public-methods
return OK  # gdlint:ignore=max-returns
```

## Testing

Tests use GUT framework. Test files end in `_test.gd`. Test cases are named like `test_<subject>_<scenario>_<expectation>` (e.g. `test_config_set_float_updates_value`).

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
