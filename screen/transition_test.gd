##
## screen/transition_test.gd
##
## Tests pertaining to screen transitions.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## MockTransition records which lifecycle methods were called and exposes helpers for
## driving the transition from test code.
class MockTransition:
	extends "transition.gd"

	var push_started := false
	var pop_started := false
	var replace_started := false
	var stopped := false

	var _ctx: StdScreenTransitionContext

	func _push(context: StdScreenTransitionContext) -> void:
		_ctx = context
		push_started = true

	func _pop(context: StdScreenTransitionContext) -> void:
		_ctx = context
		pop_started = true

	func _replace(context: StdScreenTransitionContext) -> void:
		_ctx = context
		replace_started = true

	func _stop() -> void:
		stopped = true

	## complete triggers transition completion from tests.
	func complete() -> void:
		_ctx.done()

	## do_mount calls mount on the context.
	func do_mount() -> void:
		_ctx.mount()

	## do_swap calls swap on the context (for testing lifecycle).
	func do_swap() -> void:
		_ctx.swap()

	## do_unmount calls unmount on the context.
	func do_unmount() -> void:
		_ctx.unmount()
