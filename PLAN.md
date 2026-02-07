# PLAN.md - StdRouter Scene Management System

## Overview

A handle-driven scene management system for Godot 4+ that provides declarative
routing, overlay/modal support, and seamless integration with focus management.
Routes are defined as nodes in the scene tree, while hooks, transitions, and
guards are attached as resources. Navigation is exclusively through
`StdRouteHandle` resources, enabling type-safe navigation with full
serialization support.

## Goals

1. **Handle-driven navigation** - `StdRouteHandle` is the only way to navigate
2. **Type-safe params** - Typed handles with inner `Params` class for call-site safety
3. **Zero-boilerplate serialization** - `StdRouteParams` extends `StdConfigItem`
4. **Node-based route definitions** - Routes as nodes enable editor composition
5. **Resource-based configuration** - Hooks, transitions, guards as resources
6. **Overlay support** - Single active modal with input blocking and focus

## Constraints

- `initial_route` must be a `StdRouteView`, not a redirect
- Handle→route mapping is 1:1 (same handle cannot be used by multiple routes)
- Multiple `StdRouteNestedView` nodes of same `ViewType` in one scene = assertion error
- Merged `params` key conflicts in `StdRouteContext` = assertion error + reject navigation
- Circular redirects are detected and rejected (visited route set during resolution)
- Multiple sibling routes with `is_index = true` = assertion error
- Route with children but no child has `is_index = true`, navigated to directly = assertion error

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              StdRouter (Node)                               │
│  - Registers descendant StdRoute nodes                                      │
│  - Maintains handle -> route mapping                                        │
│  - Manages navigation history stack                                         │
│  - Coordinates focus root with StdInputCursor                               │
│  - Executes global hooks                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Route Tree (children of StdRouter):                                        │
│                                                                             │
│  ├── StdRouteView (home_handle)                                             │
│  │                                                                          │
│  ├── StdRouteView (game_handle)                                             │
│  │   └── StdRouteView (hud_handle)       ← Nested in parent's NestedView   │
│  │       └── StdRouteView (minimap)      ← Nested in hud's NestedView      │
│  │                                                                          │
│  ├── StdRouteModal (pause_handle)        ← Top-level modal (sibling)       │
│  │                                                                          │
│  ├── StdRouteModal (settings_handle)     ← Top-level modal                 │
│  │   └── StdRouteView (audio_handle)     ← Nested in settings' NestedView  │
│  │                                                                          │
│  └── StdRouteRedirect (legacy_handle)    ← Redirects to another route      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Scene Tree (at runtime)                              │
│                                                                             │
│  Root                                                                       │
│  ├── StdRouter                                                              │
│  │   └── [Route definitions - not rendered content]                         │
│  │                                                                          │
│  ├── ContentRoot (configured via export)                                    │
│  │   └── [game scene instance]                                              │
│  │       └── StdRouteNestedView (CONTENT)                                   │
│  │           └── [hud scene instance]                                       │
│  │               └── StdRouteNestedView (CONTENT)                           │
│  │                   └── [minimap scene instance]                           │
│  │                                                                          │
│  └── OverlayRoot (configured via export)                                    │
│      └── [pause modal scene - rendered as sibling after content]            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Class Hierarchy

```text
StdRoute (base, @tool script)
│   - handle, is_index, guards, hooks, dependencies, dependency_mode
│
├── StdRouteRenderable (intermediate, has scene)
│   │   - scene, enter_transition, exit_transition
│   │   - allow_interrupt, load_child_dependencies
│   │
│   ├── StdRouteView
│   │       - Renders in content_root or parent's NestedView (CONTENT)
│   │
│   └── StdRouteModal
│           - Renders in overlay_root or parent's NestedView (MODAL)
│           - scrim_color, close_on_backdrop, close_on_cancel
│
└── StdRouteRedirect
        - to: StdRouteHandle
        - preserve_params: bool
        - No scene, immediate redirect (guards still apply)
```

## Key Concepts

### Handle-Based Navigation

Navigation is exclusively through `StdRouteHandle` resources:

```gdscript
# Preload handle (resource caching ensures single instance)
const GameLevel := preload("res://routes/game_level.tres")

# Navigate with type-safe params via typed handle
GameLevel.push(GameLevel.Params.create(level_id, difficulty))

# Routes without params use base handle directly
const MainMenu := preload("res://routes/main_menu.tres")
MainMenu.push()

# Pop returns to previous route in history
router.pop()
```

### Nested Routes and StdRouteNestedView

Nested routes render inside their parent's scene via `StdRouteNestedView`:

```gdscript
# Parent scene contains a NestedView node
# game_scene.tscn:
#   GameRoot
#   ├── GameWorld
#   └── StdRouteNestedView (view_type: CONTENT)  ← Child routes render here

# When navigating to /game/hud:
# 1. game scene instantiated in content_root
# 2. hud scene instantiated in game's NestedView
```

**Render location rules:**

| Route Type      | Level     | Renders In                              |
| --------------- | --------- | --------------------------------------- |
| `StdRouteView`  | Top-level | `content_root`                          |
| `StdRouteView`  | Nested    | Parent's `StdRouteNestedView` (CONTENT) |
| `StdRouteModal` | Top-level | `overlay_root` (sibling after content)  |
| `StdRouteModal` | Nested    | Parent's `StdRouteNestedView` (MODAL)   |

**Constraint:** If a nested route's parent scene lacks a `StdRouteNestedView`
with the appropriate type, the navigation is rejected with an error.

### History Model

```text
Initial state: history = [], current = initial_route

push(A):    history = [initial], current = A
push(B):    history = [initial, A], current = B
replace(C): history = [], current = C          ← Clears history
push(D):    history = [C], current = D
pop():      history = [], current = C
pop():      ERROR - empty history stack
```

**Key behaviors:**

- `push()` - Adds current route to history, navigates to new route
- `replace()` - Clears entire history, navigates to new route
- `pop()` - Returns to previous history entry (error if empty)

**Pop with nested routes:** Exits routes up to common ancestor, then activates
down the new path.

### Active Route Constraints

- **One active view route** at a time (plus its ancestors)
- **One active modal** at a time (plus its ancestors if nested)
- History is **unified** between views and modals

**Interaction rules:**

- `pop()` with modal open → closes modal, returns to previous route
- `pop()` with no modal → returns to previous route in history
- `pop()` with empty history → **error**
- `push(view)` with modal open → closes modal (and non-shared ancestors), opens view
- `push(modal)` with modal open → closes current modal, opens new modal

### Focus Management

Focus follows a "top-most active scene" model:

- The **focus root** is always the top-most scene (modal if open, otherwise current view)
- Each scene tracks its **last focused control** when focus changes within it
- When a scene becomes top-most again (e.g., modal closes), focus is restored to its
  last focused control (if still valid and visible)
- Integration with `StdInputCursor` updates the focus root on navigation complete

### Redirect Resolution

When navigating to a `StdRouteRedirect`:

1. Run the redirect route's guards
2. If guards pass, resolve the redirect target
3. Detect circular redirects (track visited routes; error if revisited)
4. Run the target route's guards (full guard chain)
5. Continue with normal navigation to target

### Index Routes

Routes with children can designate one child as the "index" route using
`is_index = true`. Navigating directly to the parent automatically redirects
to the index child.

```gdscript
# If game_route has children [hud, pause] and hud.is_index = true,
# navigating to game_handle actually navigates to game/hud
```

If no child has `is_index = true`, navigation to that route is rejected with error.

## Components

### Nodes

#### StdRouter

Root router node. Registers descendant routes, manages navigation state.

```gdscript
class_name StdRouter
extends Node

signal navigating(context: StdRouteContext)  # Before navigation
signal navigated(context: StdRouteContext)   # After navigation complete
signal navigation_failed(error: Error)       # On rejection

@export var content_root: Node               # Where screen scenes render
@export var overlay_root: Node               # Where modal scenes render
@export var initial_route: StdRoute          # Route to enter on _ready

@export_group("Global Hooks")
@export var hooks: Array[StdRouteHook]       # Applied to all navigations

# Navigation API (generic params)
func push(
    handle: StdRouteHandle,
    params: StdRouteParams = null,
    interrupt: bool = false
) -> Error

func replace(
    handle: StdRouteHandle,
    params: StdRouteParams = null
) -> Error

func pop() -> Error

# State queries
func can_pop() -> bool
func is_transitioning() -> bool
func get_current_route() -> StdRoute
func get_current_modal() -> StdRouteModal
func get_current_path() -> StringName

# Serialization
func serialize() -> String
func deserialize(state: String) -> Error
```

#### StdRoute (Base Class)

Base class for all route types.

```gdscript
@tool
class_name StdRoute
extends Node

@export var handle: StdRouteHandle

## Marks this route as the default child of its parent. When navigating to the
## parent route directly, the router redirects to the child with is_index=true.
## Error if multiple siblings have is_index=true.
@export var is_index: bool = false

@export_group("Guards")
@export var guards: Array[StdRouteGuard]

@export_group("Hooks")
@export var hooks: Array[StdRouteHook]

@export_group("Dependencies")
@export var dependencies: StdRouteDependencies
@export var dependency_mode: DependencyMode = DependencyMode.BLOCK

enum DependencyMode { BLOCK, REJECT }

func get_full_path() -> StringName:
    # Reconstruct path from ancestor handles' segments
    pass
```

#### StdRouteRenderable (Intermediate)

Routes that render a scene. Shared by View and Modal.

```gdscript
@tool
class_name StdRouteRenderable
extends StdRoute

enum ChildDependencyMode { OFF, DIRECT, RECURSIVE }

@export var scene: PackedScene

@export_group("Transitions")
@export var enter_transition: StdRouteTransition
@export var exit_transition: StdRouteTransition

@export_group("Interrupts")
@export var allow_interrupt: bool = true

@export_group("Dependencies")
## Controls whether child route dependencies are loaded when this route enters.
## OFF: Only this route's dependencies. DIRECT: This + direct children's.
## RECURSIVE: This + all descendant dependencies.
@export var load_child_dependencies: ChildDependencyMode = ChildDependencyMode.DIRECT
```

#### StdRouteView

Standard route that renders in content area.

```gdscript
class_name StdRouteView
extends StdRouteRenderable

# Renders in:
# - content_root (if top-level)
# - Parent's StdRouteNestedView with view_type CONTENT (if nested)
```

#### StdRouteModal

Overlay route that renders on top of content.

```gdscript
class_name StdRouteModal
extends StdRouteRenderable

@export var scrim_color: Color = Color(0, 0, 0, 0.5)
@export_flags("Left:1", "Right:2", "Middle:4") var close_on_backdrop: int = 0
@export var close_on_cancel: bool = true

# Renders in:
# - overlay_root (if top-level)
# - Parent's StdRouteNestedView with view_type MODAL (if nested)
```

#### StdRouteRedirect

Route that immediately redirects to another route.

```gdscript
class_name StdRouteRedirect
extends StdRoute

@export var to: StdRouteHandle
@export var preserve_params: bool = false

# No scene - redirects after guards pass
```

#### StdRouteNestedView

Placeholder node for nested route content. Placed in parent scene.

```gdscript
class_name StdRouteNestedView
extends Node  # Or Control for UI

enum ViewType { CONTENT, MODAL }

@export var view_type: ViewType = ViewType.CONTENT

func _enter_tree() -> void:
    var router := _find_ancestor_router()
    if router:
        router._register_nested_view(self)

func _exit_tree() -> void:
    var router := _find_ancestor_router()
    if router:
        router._unregister_nested_view(self)
```

**Registration timing:** The router waits for the parent scene's `_ready()` signal
before looking for `StdRouteNestedView` nodes. This ensures the parent scene is
fully initialized and all NestedViews are registered before child routes attempt
to render into them.

#### StdRouterLoader

Background resource loader for dependencies.

```gdscript
class_name StdRouterLoader
extends Node

signal resource_loaded(path: String, resource: Resource)
signal all_loaded

func queue_resource(path: String) -> void
func queue_dependencies(deps: StdRouteDependencies) -> void
func is_loading() -> bool
func get_progress() -> float
```

### Resources

#### StdRouteHandle

The sole mechanism for navigation. Typed handles define an inner `Params` class
for type-safe navigation. Router reference injected at runtime.

```gdscript
class_name StdRouteHandle
extends Resource

## Path segment for this route (e.g., &"game", &"pause").
@export var segment: StringName = &""

## Injected by StdRoute when registered with router.
var _router: StdRouter

## Push this route onto the history stack.
func push(params: StdRouteParams = null, interrupt: bool = false) -> Error:
    assert(_router, "handle not registered with a router")
    return _router.push(self, params, interrupt)

## Replace current route and clear history.
func replace(params: StdRouteParams = null) -> Error:
    assert(_router, "handle not registered with a router")
    return _router.replace(self, params)
```

**Typed handle pattern:**

Typed handles define an inner `Params` class that extends `StdRouteParams`.
Since `StdRouteParams` extends `StdConfigItem`, serialization is automatic
via property reflection—no manual serialization code needed.

```gdscript
class_name SettingsHandle
extends StdRouteHandle

## Typed params - extends StdRouteParams (which extends StdConfigItem).
## Just declare properties; serialization is automatic.
class Params extends StdRouteParams:
    var tab: int = 0
    var scroll_position: float = 0.0

    ## Typed factory for convenient construction.
    static func create(p_tab: int = 0, p_scroll: float = 0.0) -> Params:
        var p := Params.new()
        p.tab = p_tab
        p.scroll_position = p_scroll
        return p

## Override with typed signature for call-site type checking.
func push(params: Params = null, interrupt: bool = false) -> Error:
    return super.push(params, interrupt)

func replace(params: Params = null) -> Error:
    return super.replace(params)
```

**Usage:**

```gdscript
# Preload handle (resource caching ensures single instance)
const Settings := preload("res://routes/settings.tres")

# Type-safe navigation - editor shows Params signature
Settings.push(Settings.Params.create(1, 0.0))

# Or construct params explicitly
var params := Settings.Params.new()
params.tab = 2
Settings.replace(params)
```

**Routes without params:** Use base `StdRouteHandle` directly—no script needed.
Just create a `.tres` resource with the base class.

#### StdRouteParams

Type-safe, serializable route parameters. Extends `StdConfigItem` to inherit
automatic serialization via property reflection. Properties with
`PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE` are automatically
serialized—no manual `_serialize()` methods needed.

```gdscript
class_name StdRouteParams
extends StdConfigItem

func _get_category() -> StringName:
    return &"route_params"
```

**Note:** Typed params are typically defined as inner classes on typed handles
(see `StdRouteHandle` above). Standalone params classes are also supported for
shared param types used across multiple routes.

#### StdRouteContext

Information about a navigation event. Passed to hooks and guards.

```gdscript
class_name StdRouteContext
extends RefCounted

enum Trigger { PUSH, REPLACE, POP, REDIRECT, INITIAL }

var from_route: StdRoute        # Previous route (null if initial)
var from_params: StdRouteParams
var to_route: StdRoute          # Target route
var to_params: StdRouteParams
var router: StdRouter
var trigger: Trigger            # How this navigation was initiated

## Merged params from all active routes in ancestor chain.
var params: StdConfig
```

#### StdRouteGuard

Condition that determines if navigation is allowed.

```gdscript
class_name StdRouteGuard
extends Resource

func is_allowed(context: StdRouteContext) -> bool:
    return _is_allowed(context)

func _is_allowed(_context: StdRouteContext) -> bool:
    return true
```

#### StdRouteTransition

Defines visual transition effects.

```gdscript
class_name StdRouteTransition
extends Resource

signal completed

@export var duration: float = 0.3

func execute(scene: Node, is_entering: bool) -> void:
    _execute(scene, is_entering)

func _execute(_scene: Node, _is_entering: bool) -> void:
    completed.emit()
```

#### StdRouteHook

Lifecycle callback with ability to block/redirect navigation.

```gdscript
class_name StdRouteHook
extends Resource

enum Action { CONTINUE, BLOCK, REDIRECT }

class Result extends RefCounted:
    var action: Action = Action.CONTINUE
    var redirect_to: StdRouteHandle = null
    var redirect_params: StdRouteParams = null  # Params for redirect target

func before_enter(context: StdRouteContext) -> Result:
    return _before_enter(context)

func after_enter(context: StdRouteContext) -> void:
    _after_enter(context)

func before_exit(context: StdRouteContext) -> Result:
    return _before_exit(context)

func after_exit(context: StdRouteContext) -> void:
    _after_exit(context)

# Override points
func _before_enter(_context: StdRouteContext) -> Result:
    return Result.new()

func _after_enter(_context: StdRouteContext) -> void:
    pass

func _before_exit(_context: StdRouteContext) -> Result:
    return Result.new()

func _after_exit(_context: StdRouteContext) -> void:
    pass
```

**Confirmation pattern:** For async confirmation (e.g., "discard unsaved changes?"),
redirect to a confirmation modal that receives the original destination in its params:

```gdscript
# Confirm modal handle with typed params
class_name ConfirmHandle
extends StdRouteHandle

class Params extends StdRouteParams:
    var original_handle_path: String  # Resource path, not reference
    var original_params: StdRouteParams

    static func create(handle: StdRouteHandle, params: StdRouteParams) -> Params:
        var p := Params.new()
        p.original_handle_path = handle.resource_path
        p.original_params = params
        return p

# Hook redirects to confirm modal with original destination
const Confirm := preload("res://routes/confirm.tres")

func _before_exit(context: StdRouteContext) -> Result:
    if _has_unsaved_changes():
        var result := Result.new()
        result.action = Action.REDIRECT
        result.redirect_to = Confirm
        result.redirect_params = Confirm.Params.create(
            context.to_route.handle,
            context.to_params
        )
        return result
    return Result.new()

# Modal continues or cancels
func _on_confirm() -> void:
    var handle := load(_original_handle_path) as StdRouteHandle
    handle.replace(_original_params)  # Continue navigation

func _on_cancel() -> void:
    router.pop()  # Go back
```

#### StdRouteDependencies

Collection of resources to preload for a route.

```gdscript
class_name StdRouteDependencies
extends Resource

@export var resources: Array[String] = []
```

**Dependency lifecycle:**

- Dependencies load when the route is **entered** (background loading via `StdRouterLoader`)
- References are held while the route is active (keeps resources in Godot's cache)
- References are released on route **exit** (allows Godot to unload if nothing else holds them)
- The `load_child_dependencies` mode on `StdRouteRenderable` controls whether child/descendant
  dependencies are also loaded when the parent route enters

### Integration Hooks

#### StdRouteHookLogger

Debug logging for route transitions.

```gdscript
class_name StdRouteHookLogger
extends StdRouteHook

@export var log_level: StdLogger.Level = StdLogger.Level.DEBUG
```

#### StdRouteHookSaveData

Automatic save data management on route transitions.

```gdscript
class_name StdRouteHookSaveData
extends StdRouteHook

@export var data: StdSaveData
@export var save_on_exit: bool = true
@export var load_on_enter: bool = false
```

#### StdRouteHookActionSet

Manages input action sets per route (Steam Input integration).

```gdscript
class_name StdRouteHookActionSet
extends StdRouteHook

@export var action_set: StdInputActionSet = null
```

## Navigation State Machine

```text
     ┌─────────┐
     │  IDLE   │◄─────────────────────────────────────┐
     └────┬────┘                                      │
          │ push/replace/pop                          │
          ▼                                           │
     ┌─────────────┐                                  │
     │ VALIDATING  │ Guards, check NestedView         │
     └──────┬──────┘                                  │
           │ pass                              reject │
           ▼                                          │
     ┌─────────────┐                                  │
     │   EXITING   │ Exit transitions                 │
     └──────┬──────┘                                  │
            │                                         │
            ▼                                         │
     ┌─────────────┐                                  │
     │   LOADING   │ Scene instantiation + deps       │
     └──────┬──────┘                                  │
            │                                         │
            ▼                                         │
     ┌─────────────┐                                  │
     │  ENTERING   │ Enter transitions                │
     └──────┬──────┘                                  │
            │                                         │
            └─────────────────────────────────────────┘
```

### Interrupt Handling

During non-IDLE states, new navigation requests check interrupt permission:

```text
can_interrupt =
    (exiting_route == null OR exiting_route.allow_interrupt) AND
    (entering_route == null OR entering_route.allow_interrupt) AND
    request.interrupt == true
```

- If `can_interrupt`: Cancel current transition, start new one
- Otherwise: Queue the request until IDLE

When interrupted:

- Current transition is cancelled (animations stopped)
- Partially-entered route is NOT added to history
- New transition starts from last stable state

## Navigation Flow

```text
handle.push(params)
         │
         ▼
    ┌─────────────────┐
    │  Check State    │  If transitioning, queue or interrupt
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Resolve Route   │  Handle -> route mapping
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Build Ancestor  │  Find routes to activate (ancestors first)
    │     Chain       │  Apply is_index redirects
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   Run Guards    │  All guards on all routes must pass
    └────────┬────────┘
             │ reject → return error
             ▼
    ┌─────────────────┐
    │  Check Nested   │  Verify NestedViews exist for nested routes
    │     Views       │
    └────────┬────────┘
             │ missing → return error
             ▼
    ┌─────────────────┐
    │  Global Hooks   │  router.hooks[].before_enter()
    │  before_enter   │  Can BLOCK or REDIRECT
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Route Hooks    │  route.hooks[].before_enter()
    │  before_enter   │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Load Dependencies│  BLOCK waits, REJECT returns error
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Exit Transitions │  Deactivate routes to common ancestor
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Scene Swap     │  Instantiate scenes, place in tree
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │Enter Transitions │  Activate new routes down the path
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Update Focus   │  Set focus root for modals
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  Update History │  Push previous route to stack
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │     Hooks       │  after_enter() on all hooks
    │  after_enter    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Emit navigated  │  Signal navigation complete
    └─────────────────┘
```

## Serialization

Route state is serialized for save/restore:

```gdscript
# Serialization format
{
    "current": {
        "handle": "res://routes/game/hud.tres",
        "params": { "level_id": 5 }
    },
    "modal": {
        "handle": "res://routes/pause.tres",
        "params": {}
    }
    # Note: history is NOT serialized (cleared on replace anyway)
}

# Restore
func deserialize(state: String) -> Error:
    var data := JSON.parse_string(state)
    if data.current:
        var handle := load(data.current.handle) as StdRouteHandle
        var params := _deserialize_params(data.current.params)
        replace(handle, params)  # Clears history
    if data.modal:
        var handle := load(data.modal.handle) as StdRouteHandle
        var params := _deserialize_params(data.modal.params)
        push(handle, params)
```

## File Structure

```text
router/
├── router.gd                 # StdRouter node
├── router_test.gd            # StdRouter tests
├── route.gd                  # StdRoute base class (@tool)
├── renderable.gd             # StdRouteRenderable intermediate (@tool)
├── view.gd                   # StdRouteView node
├── modal.gd                  # StdRouteModal node
├── modal_test.gd             # StdRouteModal tests
├── redirect.gd               # StdRouteRedirect node
├── redirect_test.gd          # StdRouteRedirect tests
├── nested_view.gd            # StdRouteNestedView node
├── loader.gd                 # StdRouterLoader node
├── loader_test.gd            # StdRouterLoader tests
├── handle.gd                 # StdRouteHandle resource
├── params.gd                 # StdRouteParams base (extends StdConfigItem)
├── context.gd                # StdRouteContext refcounted
├── guard.gd                  # StdRouteGuard resource
├── guard_test.gd             # StdRouteGuard tests
├── transition.gd             # StdRouteTransition resource
├── hook.gd                   # StdRouteHook resource
├── hook_test.gd              # StdRouteHook tests
├── dependencies.gd           # StdRouteDependencies resource
├── hooks/
│   ├── logger.gd             # StdRouteHookLogger
│   ├── save_data.gd          # StdRouteHookSaveData
│   └── action_set.gd         # StdRouteHookActionSet
└── transitions/
    ├── fade.gd               # Fade in/out
    └── slide.gd              # Slide in/out
```

## Testing

Tests use the GUT framework following codebase conventions (see `AGENTS.md`).

### Script Templates

All scripts must follow the section structure from the [project script templates](../godot-project-template/script_templates/):

| Component Type | Template |
|----------------|----------|
| Nodes (`StdRouter`, `StdRoute*`, `StdRouteNestedView`) | `Node/node.gd` |
| Resources (`StdRouteHandle`, `StdRouteGuard`, `StdRouteHook`, `StdRouteTransition`, `StdRouteDependencies`) | `Resource/resource.gd` |
| RefCounted (`StdRouteContext`) | `Object/object.gd` |
| Tests (`*_test.gd`) | `Node/test.gd` |

### Requirements

- Each component with router business logic requires a corresponding `*_test.gd` file
- Tests use BDD-style Given/When/Then comments
- Test file naming: `<component>_test.gd` (e.g., `router_test.gd`, `guard_test.gd`)

### Components Requiring Tests

| Component | Test File | Rationale |
|-----------|-----------|-----------|
| `StdRouter` | `router_test.gd` | Core navigation logic, history management |
| `StdRouteModal` | `modal_test.gd` | Scrim behavior, close triggers |
| `StdRouteRedirect` | `redirect_test.gd` | Redirect resolution, circular detection |
| `StdRouterLoader` | `loader_test.gd` | Background loading, dependency modes |
| `StdRouteGuard` | `guard_test.gd` | Guard evaluation, rejection |
| `StdRouteHook` | `hook_test.gd` | Lifecycle callbacks, BLOCK/REDIRECT |

### Components NOT Requiring Tests

- `StdRoute`, `StdRouteRenderable`, `StdRouteView` — declarative config, no logic
- `StdRouteNestedView` — registration only, tested via integration
- `StdRouteHandle`, `StdRouteParams`, `StdRouteContext` — data classes
- `StdRouteDependencies`, `StdRouteTransition` — simple resources

### Test Coverage Areas

**Unit tests** (per-component):

- Guard rejection and acceptance
- Hook lifecycle ordering and result handling
- Redirect resolution and circular detection
- Dependency loading modes (OFF/DIRECT/RECURSIVE)

**Integration tests** (in `router_test.gd`):

- Push/replace/pop navigation flows
- Nested route activation and deactivation
- Modal open/close with focus restoration
- History stack behavior
- Interrupt handling during transitions

## Implementation Phases

### Phase 1: Core Structure

- [ ] `StdRoute` base class with handle, is_index, guards, hooks, dependencies
- [ ] `StdRouteRenderable` with scene, transitions, allow_interrupt, load_child_dependencies
- [ ] `StdRouteView` node
- [ ] `StdRouteHandle` with segment, router injection
- [ ] `StdRouter` with handle->route mapping
- [ ] Basic push/replace/pop navigation (no nesting yet)
- [ ] Unified history stack management
- [ ] Content root scene management

### Phase 2: Nesting & Outlets

- [ ] `StdRouteNestedView` node with view_type
- [ ] Nested route rendering in parent's NestedView
- [ ] Ancestor chain activation on navigation
- [ ] `is_index` validation and redirect behavior
- [ ] Validation for missing NestedViews

### Phase 3: Modals & Focus

- [ ] `StdRouteModal` with scrim, backdrop, cancel handling
- [ ] Overlay root scene management
- [ ] Focus root integration with `StdInputCursor`
- [ ] Single active modal constraint

### Phase 4: Guards, Hooks & Redirects

- [ ] `StdRouteGuard` evaluation
- [ ] `StdRouteHook` lifecycle (Result/Action pattern)
- [ ] Hook result handling (CONTINUE/BLOCK/REDIRECT)
- [ ] Global hooks on `StdRouter`
- [ ] `StdRouteRedirect` node with circular detection

### Phase 5: Transitions & Loading

- [ ] `StdRouteTransition` base with completed signal
- [ ] Navigation state machine (IDLE/VALIDATING/etc.)
- [ ] Interrupt handling with allow_interrupt
- [ ] Request queuing during transitions
- [ ] `StdRouterLoader` for background loading
- [ ] `StdRouteDependencies` with BLOCK/REJECT modes
- [ ] `load_child_dependencies` mode (OFF/DIRECT/RECURSIVE)

### Phase 6: Params & Serialization

- [ ] `StdRouteParams` extending `StdConfigItem`
- [ ] `StdRouteContext` with merged params
- [ ] Path reconstruction from handle segments
- [ ] Serialization/deserialization

### Phase 7: Integration Hooks

- [ ] `StdRouteHookLogger`
- [ ] `StdRouteHookSaveData`
- [ ] `StdRouteHookActionSet`

### Phase 8: Testing & Polish

- [ ] Unit tests for components with business logic (see Testing section)
- [ ] Integration tests for navigation flows in `router_test.gd`
- [ ] Example scenes demonstrating patterns
- [ ] Conditional route inclusion via `StdCondition`
