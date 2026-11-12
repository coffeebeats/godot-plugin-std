##
## std/test/screen_manager.gd
##
## StdTestScreenManager is a `StdScreenManager` for a GUT test, so a scene that reaches
## the stack through its ancestors runs as it does in a game.
##
## A test adds a `StdInputCursor` to the tree, as any manager requires, then this node,
## and awaits `push_and_wait`, which waits for the manager to settle.
##
## NOTE: An empty screen sits under the first one pushed, because a manager won't pop
## its bottom screen, and `get_depth()` counts it.
##

class_name StdTestScreenManager
extends StdScreenManager

# -- DEFINITIONS --------------------------------------------------------------------- #

## _TIMEOUT_MSEC bounds the wait for a transition, so one that never finishes fails its
## test instead of hanging the run.
const _TIMEOUT_MSEC := 10000

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## push_and_wait pushes `screen`, and returns its scene once every operation has run,
## the push and whatever it led to, and the scene's layout has settled, or null if the
## scene has since left the stack.
##
## NOTE: Passing a bare `StdTransition.new()` skips the screen's own transition.
func push_and_wait(
	screen: StdScreen,
	instance: Node = null,
	transition: StdTransition = null,
) -> Node:
	assert(is_node_ready(), "invalid state: not in the tree")
	assert(screen != null, "invalid argument: missing screen")

	# NOTE: A lambda can't rebind a local, so this is an array.
	var mounted := [false]

	var on_entering := func(_scene: Node) -> void: mounted[0] = true
	screen.entering.connect(on_entering)

	push(screen, instance, transition)

	# NOTE: This polls `is_settled` on `process_frame` so a transition that never
	# finishes times out, where awaiting `settled` would hang and GUT's `wait_until`
	# stops under a pause.
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + _TIMEOUT_MSEC
	while not is_settled() and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	screen.entering.disconnect(on_entering)

	assert(is_settled(), "invalid state: transition didn't finish")

	# NOTE: A push of a screen already on the stack mounts nothing and is no failure.
	assert(mounted[0] or _scenes.has(screen), "invalid state: screen didn't mount")

	await tree.process_frame

	return _scenes.get(screen)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(not initial, "invalid config: initial would sit under the empty screen")

	super()

	push(StdScreen.new(), Control.new())
