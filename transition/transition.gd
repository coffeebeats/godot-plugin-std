##
## std/transition/transition.gd
##
## StdTransition is a base class for a visual effect that runs as a node enters or
## exits, whether a screen on the stack or a panel inside a running scene. Each kind of
## change has a dedicated virtual method, and the transition controls the timeline via
## explicit methods on the context it's given.
##
## NOTE: A run stores state on the instance, so a caller runs a duplicate of a resource
## and holds it until `finished`; `stop` needs it and it may not stay alive otherwise.
##

class_name StdTransition
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## block_input controls whether input is automatically blocked during transitions. The
## context decides what's blocked, which is the viewport for a screen and otherwise the
## rect of the entering or exiting control.
@export var block_input: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

## _context is the context of the run in progress, or null if there isn't one.
var _context: StdTransitionContext = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## enter begins a transition which only brings in `context.entering`.
func enter(context: StdTransitionContext) -> void:
	_start(context)
	_enter(context)


## exit begins a transition which only removes `context.exiting`.
func exit(context: StdTransitionContext) -> void:
	_start(context)
	_exit(context)


## stop halts the transition, undoes what it applied, and ends its context without
## emitting `finished`.
func stop() -> void:
	_stop()

	if _context:
		_context.abort()

	_context = null


## swap begins a transition which replaces `context.exiting` with `context.entering`.
func swap(context: StdTransitionContext) -> void:
	_start(context)
	_swap(context)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _enter runs when a node enters. Default performs an instant mount.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _enter(context: StdTransitionContext) -> void:
	context.mount()
	context.done()


## _exit runs when a node exits. Default performs an instant unmount.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _exit(context: StdTransitionContext) -> void:
	context.unmount()
	context.done()


## _stop halts the transition and removes anything it left on the nodes it animated, so
## that they look as they would had the transition not run.
##
## NOTE: Override this method for custom transition behavior.
func _stop() -> void:
	pass


## _swap runs when one node replaces another. Default performs an instant swap.
##
## NOTE: Override this method for custom transition behavior. Subclasses *must* call
## `context.done()` when the transition completes.
func _swap(context: StdTransitionContext) -> void:
	context.swap()
	context.done()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _start records the run and arms the input blocker if this transition uses one.
func _start(context: StdTransitionContext) -> void:
	_context = context

	if block_input:
		context._block_input()
