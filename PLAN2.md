# Screen Module Implementation Plan

## Context

The current `router/` module (~3300 lines) uses a web-router pattern that no game
framework uses. The universal standard is a **pushdown automaton** (scene stack). The
existing `Modal` already implements this: a static stack managing z-ordering, focus, and
focus save/restore.

The screen module **generalizes the Modal's pattern** into a unified stack for both
full-screen views and overlays. Bottom = base scene, everything above = overlay. Position
determines role.

## Architecture

```
screen/
  transition.gd    StdScreenTransition (Resource)   ~60 lines
  loader.gd        StdScreenLoader (Node)          ~200 lines
  screen.gd        StdScreen (Resource)             ~65 lines
  manager.gd       StdScreenManager (Node)         ~400 lines
```

4 files, ~725 lines total.

## Stack Model

```
Stack: [base, overlay1, overlay2, ...]
         ^                          ^
       bottom                     top (focused)
```

**Operations:**
- `push(screen, instance?)` — add on top, focus immediately
- `pop()` — remove top, focus returns to new top
- `replace(screen, instance?)` — exit old top (await if blocking), free, add new
- `reset(screen, instance?)` — clear entire stack, free all, add as new base
- `pop_to(screen)` — pop until screen is on top (only last exit animates)
- `pop_to_depth(depth)` — pop until stack reaches target depth
- `push_all(screens)` — push multiple in sequence (only last enter animates)

`reset` differs from `replace`: replace swaps the TOP only
(`[A,B,C] → replace(X) → [A,B,X]`), reset clears ALL
(`[A,B,C] → reset(X) → [X]`).

## Scene Instantiation

Navigation methods accept an optional pre-built Node. This supports three usage
patterns without requiring a `.tscn` file for every screen:

1. **File-based** — `scene_path` on StdScreen loads from disk (major screens):
   ```gdscript
   manager.push(gameplay_screen)
   ```

2. **Template + configuration** — load a template `.tscn`, configure, push:
   ```gdscript
   var dialog := preload("res://ui/confirm.tscn").instantiate()
   dialog.title = "Delete save?"
   dialog.on_confirm = func(): save.delete()
   manager.push(confirm_screen, dialog)
   ```

3. **Fully code-built** — no file at all:
   ```gdscript
   var popup := PopupMenu.new()
   popup.add_item("Resume")
   popup.add_item("Quit")
   manager.push(menu_screen, popup)
   ```

When `instance` is provided, the loader is skipped entirely and `scene_path` is
ignored. This mirrors how most game frameworks work — XNA, LibGDX, and Cocos2d all
define screens as code objects, not files. Godot's `.tscn` approach is the exception.

**Pre-instantiated scenes still receive meta**: The manager sets
`set_meta(&"std_screen", screen)` on the instance before adding it to the tree,
so `_ready` can connect to lifecycle signals regardless of how the scene was created.

## Transition Mechanics

**Blocking flag on StdScreenTransition**: `@export var blocking: bool = false`

- `blocking = false` (default): Fire-and-forget. State commits immediately,
  animation plays asynchronously. Scene freed when animation completes.
- `blocking = true`: Manager awaits `completed` before proceeding.
  The old scene must finish animating before the next step runs.

| Operation | Exit | Enter | Notes |
|-----------|------|-------|-------|
| push | None | On new | Respects `blocking` on enter transition |
| pop | On old | None | Respects `blocking` on exit transition |
| replace | On old | On new | Each respects its own `blocking` flag |
| reset | None | On new | Instant clear, enter respects `blocking` |

**No transition = instant.** Leave transition null on StdScreen.

**Interrupts**: Manager tracks `_active_transition`. New navigation cancels it via
`cancel()`. Cancelled scenes are freed immediately (no memory leak from orphaned
fire-and-forget transitions).

## Process Mode Management

`@export var pause_when_covered: bool = true` on StdScreen.

After any stack change, the manager updates process modes:
- Top scene: `PROCESS_MODE_INHERIT` (active)
- Covered scenes with `pause_when_covered`: `PROCESS_MODE_DISABLED`
  (stops processing/input but still renders — game world visible but frozen)
- Covered scenes without the flag: unchanged (keep processing)

## Lifecycle Signals

**On StdScreen Resource** (per-screen, scene connects in `_ready`):

| Signal | When | Use case |
|--------|------|----------|
| `entering(scene: Node)` | After mount, before enter transition | Load data, setup |
| `entered(scene: Node)` | After enter transition completes | Start gameplay |
| `exiting(scene: Node)` | Before exit transition starts | Save data, cleanup |
| `exited(scene: Node)` | After exit transition, before free | Final cleanup |
| `covered(scene: Node)` | Another scene pushed on top | Pause, dim music |
| `uncovered(scene: Node)` | Covering scene popped | Resume, restore |

**On StdScreenManager** (global, same signals with screen arg added):
- `screen_entering(screen, scene)`, `screen_entered(screen, scene)`, etc.
- For external observers (analytics, audio, logging).

**Scene connects via meta**:
```gdscript
func _ready():
    var screen: StdScreen = get_meta(&"std_screen")
    screen.entering.connect(_on_entering)
    screen.covered.connect(_on_covered)
```

The manager sets `set_meta(&"std_screen", screen)` before `add_child`. By `_ready`,
the meta is available and signals can be connected. The manager emits `entering` AFTER
`add_child` (so `_ready` has run), ensuring the scene receives it.

**Dual-connection safety**: When popping a scene, the manager disconnects the scene from
the screen's lifecycle signals after emitting `exited`. This prevents stale connections
if the same StdScreen is pushed while an old instance is still in a fire-and-forget exit.

## Stack Querying

On StdScreenManager:
- `get_current() -> StdScreen` — topmost screen
- `get_scene() -> Node` — topmost scene instance
- `get_depth() -> int` — stack depth
- `get_at(index: int) -> StdScreen` — screen at index (0 = bottom)
- `get_index_of(screen: StdScreen) -> int` — -1 if not in stack
- `is_current(screen: StdScreen) -> bool`

## Components

### StdScreen (`screen/screen.gd`) — Resource, ~65 lines

```gdscript
class_name StdScreen
extends Resource

signal entering(scene: Node)
signal entered(scene: Node)
signal exiting(scene: Node)
signal exited(scene: Node)
signal covered(scene: Node)
signal uncovered(scene: Node)

@export_file("*.tscn,*.scn") var scene_path: String = ""
@export var enter_transition: StdScreenTransition
@export var exit_transition: StdScreenTransition
@export var preload_scenes: PackedStringArray = []
@export var pause_when_covered: bool = true
```

`scene_path` is optional. When empty, the caller must provide a pre-built instance
to `push`/`replace`/`reset`. This allows lightweight screen definitions for
parameterized dialogs and code-built popups without requiring `.tscn` files.

### StdScreenManager (`screen/manager.gd`) — Node, ~400 lines

**Signals** (global lifecycle — mirror of StdScreen signals with screen arg):
- `screen_entering(screen: StdScreen, scene: Node)` (+ entered, exiting, etc.)
- `screen_pushed(screen: StdScreen)` — after push completes
- `screen_popped(screen: StdScreen)` — after pop completes
- `screen_replaced(old: StdScreen, new: StdScreen)`

**Exports:**
- `initial: StdScreen` — pushed on `_ready`

**Navigation methods:**
- `push(screen, instance?)`, `pop()`, `replace(screen, instance?)`,
  `reset(screen, instance?)`
- `pop_to(screen)`, `pop_to_depth(depth)`, `push_all(screens)`
- `get_current()`, `get_scene()`, `get_depth()`, `get_at(index)`
- `get_index_of(screen)`, `is_current(screen)`

**Push flow:**
1. `_cancel_active()`
2. If instance provided, use it. Else load via loader (await if not cached).
3. Set meta, `add_child(scene)`
4. Save focus for old top, `set_focus_root(scene)`
5. Push to stack, `_update_process_modes()`
6. Emit `entering` on screen + manager
7. If enter transition: start. If `blocking`: await. Else: track.
8. Emit `entered`, emit `covered` on previous top, preload, emit `screen_pushed`

**Pop flow:**
1. `_cancel_active()`, assert depth > 1
2. Emit `exiting` on top screen
3. Pop from stack, `_update_process_modes()`
4. `set_focus_root(new_top)`, restore focus
5. Emit `uncovered` on new top
6. If exit transition: start. If `blocking`: await, free, emit `exited`.
   Else: defer free to `completed`, disconnect lifecycle signals.
7. Emit `screen_popped`

**pop_to / pop_to_depth**: Loop calling `pop()`. Each `pop()` cancels the previous
one's active transition — only the final pop's exit transition plays.

### StdScreenTransition (`screen/transition.gd`) — Resource, ~60 lines

Ported from `router/transition.gd` (self-contained copy). One addition:

```gdscript
@export var blocking: bool = false
```

- `blocking = false`: fire-and-forget (state commits, animation plays async)
- `blocking = true`: manager awaits `completed` before proceeding

Rest unchanged: `completed` signal, `start(scene, is_entering)`, `cancel()`,
virtual `_start()`, `_cancel()`, `_done()`.

### StdScreenLoader (`screen/loader.gd`) — Node, ~200 lines

Ported from `router/loader.gd` (self-contained copy). Changes:
- Rename to `StdScreenLoader`
- `load_all(paths: PackedStringArray)` replaces `load_all(deps: StdRouteDependencies)`
- Remove all router-specific types/imports
- Update logger tag

## What Happens to Modal?

The unified stack makes Modal's stack management redundant. Modal becomes a pure UI
component: scrim, close buttons, close reasons. These are scene-internal concerns — the
game scene handles its own presentation. `push(dialog)` / `pop()` replaces
`dialog.visible = true/false`.

Simple popups and dialogs don't need their own `.tscn` files — they can be
instantiated from a template or built in code, then pushed with a pre-built instance.

## Code Porting (self-contained — no router dependencies)

The screen module is fully self-contained. All code is ported (copied and adapted),
not imported. The `router/` module will be deleted in a follow-up PR.

| New file | Ported from | Key changes |
|---|---|---|
| `screen/transition.gd` | `router/transition.gd` | Port + add `blocking` export |
| `screen/loader.gd` | `router/loader.gd` | Port, rename, simplify `load_all` |
| Focus in manager | `router/stage.gd:258-373` | Port save/restore/find logic |
| Stack in manager | `modal.gd:85,272-298` | Port focus root pattern |

## Implementation Order

1. `screen/transition.gd` — rename + add `blocking`
2. `screen/loader.gd` — rename + simplify `load_all`
3. `screen/screen.gd` — new Resource with lifecycle signals
4. `screen/manager.gd` — core coordinator
5. Tests: `screen/manager_test.gd`
6. Format + lint

## NOT in Scope

- Deleting `router/` or `scene/` (separate PR)
- Concrete transition effects (fade, slide — future work)
- Controller abstraction (extract if crossfade needed)
- Per-screen lifecycle hooks that can block/delay transitions (future)
- Save/restore screen identity for Steam dynamic saves

## Verification

1. **Unit tests**: `godot --headless -s addons/gut/gut_cmdln.gd -gdir="res://" -ginclude_subdirs -gprefix="" -gsuffix="_test.gd" -gexit`
2. **Format**: `gdformat -l 88 --check screen/**/*.gd`
3. **Lint**: `gdlint screen/**/*.gd`
4. **Existing tests unaffected**: router/scene tests still pass
