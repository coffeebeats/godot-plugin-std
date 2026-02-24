##
## screen/transition.gd
##
## StdScreenTransition is a base class for visual transition effects during screen
## changes. One transition handles the full visual lifecycle of one operation. The
## transition controls the timeline via explicit context methods.
##

class_name StdScreenTransition
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Input")

## block_input_enter controls whether input is automatically blocked during `_enter()`.
@export var block_input_enter: bool = true

## block_input_exit controls whether input is automatically blocked during `_exit()`.
@export var block_input_exit: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

## reset_on_interrupt controls whether the manager resets visual state when interrupting
## this transition. When true (default), visual state is restored to its pre-transition
## value. Set to false for transitions (like fades) where the next transition should
## pick up from the current visual state.
var reset_on_interrupt: bool = true

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## enter begins the enter transition. Called by the manager for push and replace
## operations. Delegates to the virtual _enter method.
func enter(context: StdScreenTransitionContext) -> void:
	_enter(context)


## exit begins the exit transition. Called by the manager for pop operations.
## Delegates to the virtual _exit method.
func exit(context: StdScreenTransitionContext) -> void:
	_exit(context)


## stop halts the transition. Visual state is left as-is so the next transition can pick
## up from the current position.
func stop() -> void:
	_stop()


## reset stops the transition and restores visual state to its pre-transition value.
## Used for aborting a transition cleanly.
func reset() -> void:
	_reset()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _enter runs when this screen arrives (push or replace). The context provides full
## lifecycle control: loading, mounting, unmounting, and scene access. Default performs
## an instant swap.
##
## NOTE: Override this method to implement custom transition behavior. Subclasses *must*
## call `context.done()` when the transition completes.
func _enter(context: StdScreenTransitionContext) -> void:
	context.swap()
	context.done()


## _exit runs when this screen departs (pop). The context provides unmounting and scene
## access. Default performs an instant unmount.
##
## NOTE: Override this method to implement custom transition behavior. Subclasses *must*
## call `context.done()` when the transition completes.
func _exit(context: StdScreenTransitionContext) -> void:
	context.unmount()
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
