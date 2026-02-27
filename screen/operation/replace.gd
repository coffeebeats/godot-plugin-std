##
## screen/operation/replace.gd
##
## Implements the replace operation for the screen manager.
##

extends "operation.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Replace := preload("replace.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _instance: Node
var _screen: StdScreen
var _transition: StdScreenTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a replace operation.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdScreenTransition = null,
) -> RefCounted:
	var op = Replace.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _execute(manager: StdScreenManager, done: Callable) -> void:
	# Reject duplicate (non-self) replace.
	if _screen in manager._stack and manager._stack[-1] != _screen:
		(
			_logger
			. warn(
				"Ignored; screen already in stack.",
				{&"op": &"replace"},
			)
		)
		done.call()
		return

	var screen_prev: StdScreen = manager._stack[-1]
	var scene_prev: Node = manager._scenes[screen_prev]

	# Capture the overlay for transfer when both screens own theirs. If
	# the old screen was sharing an overlay, teardown handles cleanup
	# normally so the shared overlay stays with its original owner.
	var overlay_prev: StdScreenOverlay = null
	if screen_prev.block_input_below and _screen.block_input_below:
		overlay_prev = (manager._overlays.get_overlay(screen_prev))

	_resolve_and_load(
		manager,
		_screen,
		_instance,
		(
			_do_replace
			. bind(
				manager,
				screen_prev,
				scene_prev,
				overlay_prev,
				done,
			)
		),
	)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _do_replace(
	scene: Node,
	manager: StdScreenManager,
	screen_prev: StdScreen,
	scene_prev: Node,
	overlay_prev: StdScreenOverlay,
	done: Callable,
) -> void:
	screen_prev.exiting.emit(scene_prev)
	manager.screen_exiting.emit(screen_prev, scene_prev)

	var transition := (
		manager
		. _resolve_transition(
			_screen,
			_transition,
			&"push",
		)
	)

	_run_transition(
		manager,
		transition,
		&"replace",
		scene_prev,
		scene,
		func() -> void:
			if is_instance_valid(overlay_prev):
				manager._overlays.register(_screen, overlay_prev)
			manager._mount_scene(_screen, scene),
		func() -> void:
			manager._stack.pop_back()
			manager._scenes.erase(screen_prev)
			if is_instance_valid(overlay_prev):
				manager._overlays.erase(screen_prev)
			manager._teardown_scene(screen_prev, scene_prev),
		func() -> void:
			manager._overlays.free_if_unused(overlay_prev)
			_emit_entered(manager, _screen, scene)
			done.call(),
	)
