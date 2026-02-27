##
## screen/transition.gd
##
## StdScreenTransition is a base class for visual transition effects during screen
## changes. Each screen stack operation type has a dedicated virtual method; the
## transition controls the timeline via explicit context methods.
##

class_name StdScreenTransition
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## block_input controls whether input is automatically blocked during transitions.
@export var block_input: bool = true

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push begins the push transition. Called by the push operation. Delegates to the
## virtual `_push` method.
func push(context: StdScreenTransitionContext) -> void:
	_push(context)


## pop begins the pop transition. Called by the pop operation. Delegates to the virtual
## `_pop` method.
func pop(context: StdScreenTransitionContext) -> void:
	_pop(context)


## replace begins the replace transition. Called by the replace operation. Delegates to
## the virtual `_replace` method.
func replace(context: StdScreenTransitionContext) -> void:
	_replace(context)


## stop halts the transition; called only during force-stop (`_exit_tree` teardown).
func stop() -> void:
	_stop()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _push runs when a screen is pushed. Default performs an instant mount.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _push(context: StdScreenTransitionContext) -> void:
	context.mount()
	context.done()


## _pop runs when a screen is popped. Default performs an instant unmount.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _pop(context: StdScreenTransitionContext) -> void:
	context.unmount()
	context.done()


## _replace runs when a screen is replaced. Default performs an instant swap.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _replace(context: StdScreenTransitionContext) -> void:
	context.swap()
	context.done()


## _stop halts the transition while leaving visual state unchanged.
##
## NOTE: Override this method for custom transition behavior.
func _stop() -> void:
	pass
