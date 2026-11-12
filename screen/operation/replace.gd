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
var _transition: StdTransition

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## create constructs a replace operation.
static func create(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
) -> RefCounted:
	var op = Replace.new()
	op._screen = screen
	op._instance = instance
	op._transition = transition
	return op


func get_screen() -> StdScreen:
	return _screen


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _prepare(manager: StdScreenManager) -> Preparation:
	if _screen in manager._stack and manager._stack[-1] != _screen:
		return null

	return _prepare_screen(manager, _screen, _instance)


func _present(manager: StdScreenManager, done: Callable) -> void:
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
	var scene_prev: Node = manager._scenes.get(screen_prev)

	if scene_prev == null:
		manager._discard_screen(screen_prev)
		manager._update_stack_state()
		done.call()
		return

	if _fail_unloaded(manager, done):
		return

	# Capture the overlay for transfer when both screens own theirs. If
	# the old screen was sharing an overlay, teardown handles cleanup
	# normally so the shared overlay stays with its original owner. A
	# screen kept in the tree owns its overlay for life, so it never
	# hands one over or takes one.
	var overlay_prev: StdScreenOverlay = null
	if (
		screen_prev.block_input_below
		and _screen.block_input_below
		and not manager._cache.is_in_tree(screen_prev)
		and not manager._cache.is_in_tree(_screen)
	):
		overlay_prev = (manager._overlays.get_overlay(screen_prev))

	var result: Array = manager._create_resolver(_screen, _instance, _preparation)
	var resolver: Callable = result[0]
	var sync_scene: Node = result[1]

	screen_prev.exiting.emit(scene_prev)
	manager.screen_exiting.emit(screen_prev, scene_prev)
	manager._play_screen_sound(screen_prev.sound_exit)

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
		&"swap",
		scene_prev,
		sync_scene,
		func(scene: Node) -> void:
			if is_instance_valid(overlay_prev):
				manager._overlays.register(_screen, overlay_prev)
			manager._mount_entering(_screen, scene, _preparation),
		func() -> void:
			manager._stack.pop_back()
			manager._scenes.erase(screen_prev)
			if is_instance_valid(overlay_prev):
				manager._release_focus(screen_prev)
				manager._overlays.erase(screen_prev)
			manager._teardown_scene(screen_prev, scene_prev)
			screen_prev.popped.emit(null),
		func() -> void:
			manager._overlays.free_if_unused(overlay_prev)
			if _screen not in manager._stack:
				manager._update_stack_state()
				if screen_prev not in manager._stack:
					manager._notify_top_uncovered()
				done.call()
				return
			var scene: Node = manager._scenes.get(_screen)
			_emit_entered(manager, _screen, scene)
			done.call(),
		resolver,
	)
