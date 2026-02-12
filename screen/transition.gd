##
## screen/transition.gd
##
## StdScreenTransition is a base class for visual transition effects during screen
## changes. This class should be extended to provide custom transition behavior.
##

class_name StdScreenTransition
extends Resource

# -- INITIALIZATION ------------------------------------------------------------------ #

## reset_on_interrupt controls whether the manager resets visual state when interrupting
## this transition. When true (default), visual state is restored to its pre-transition
## value. Set to false for transitions (like fades) where the next transition should
## pick up from the current visual state.
var reset_on_interrupt: bool = true

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## start begins the screen transition effect on the given scene. The `is_entering`
## parameter indicates whether the scene is entering (true) or exiting (false) view.
func start(
	context: StdScreenTransitionContext,
	scene: Node,
	is_entering: bool,
) -> void:
	_start(context, scene, is_entering)


## stop halts the transition. Visual state is left as-is so the next transition can pick
## up from the current position.
func stop() -> void:
	_stop()


## reset stops the transition and restores visual state to its pre-transition value.
## Used for aborting a transition cleanly.
func reset() -> void:
	_reset()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _start is a virtual method that begins the transition effect on the given scene.
## Subclasses *must* call `context.done()` when the transition completes (immediately or
## deferred).
##
## NOTE: Override this method to implement custom transition behavior.
func _start(
	context: StdScreenTransitionContext,
	_scene: Node,
	_is_entering: bool,
) -> void:
	context.done()


## _stop halts the transition while leaving visual state unchanged.
##
## NOTE: Override this method to implement custom transition behavior.
func _stop() -> void:
	pass


## _reset halts the transition and restores visual state. Default calls `_stop()`.
##
## NOTE: Override this method to implement custom transition behavior.
func _reset() -> void:
	_stop()
