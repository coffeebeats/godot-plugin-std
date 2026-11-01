##
## std/transition/context.gd
##
## StdTransitionContext is a mediator between whatever runs a transition and the
## transition itself, recreated for each run. Mounting shows the entering node and
## unmounting hides the exiting one, so no screen manager has to be in the tree.
##

class_name StdTransitionContext
extends RefCounted

# -- SIGNALS ------------------------------------------------------------------------- #

## finished is emitted when the transition completes normally. A runner connects a
## one-shot handler to receive completion; `abort` prevents emission.
signal finished

# -- DEFINITIONS --------------------------------------------------------------------- #


## _RectBlocker is a control that takes the mouse over its parent control's rect. It's
## `top_level` so that a container never lays it out, and it still inherits visibility,
## so it takes nothing while the parent is hidden.
##
## NOTE: Neither the parent's scale nor an ancestor's move emits `item_rect_changed`, so
## a transition animating either leaves this at the last rect.
##
## NOTE: The engine doesn't mark an event handled for a `top_level` control whose filter
## stops the mouse, so this accepts it, or the click would reach `_unhandled_input`.
class _RectBlocker:
	extends Control

	func _gui_input(_event: InputEvent) -> void:
		accept_event()

	func _init() -> void:
		name = &"TransitionInputBlocker"
		mouse_filter = MOUSE_FILTER_STOP
		top_level = true

	func _ready() -> void:
		get_parent().item_rect_changed.connect(_fit)
		_fit()

	## _fit places this over the parent's global rect.
	func _fit() -> void:
		var rect: Rect2 = get_parent().get_global_rect()
		global_position = rect.position
		size = rect.size


# -- INITIALIZATION ------------------------------------------------------------------ #

## entering is the node coming in, or null if nothing is.
var entering: Node = null

## exiting is the node going out, or null if nothing is.
var exiting: Node = null

## host is the node that gives this context a tree and that its tweens are bound to.
var host: Node

var _blockers: Array[Control] = []
var _did_finish: bool = false
var _did_mount: bool = false
var _did_unmount: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## abort ends the transition without emitting `finished`, and releases what's blocking
## input. `done` has no effect afterward, and this has none once finished.
func abort() -> void:
	if _did_finish:
		return

	_did_finish = true
	_unblock_input()


## create_tween creates a new `Tween` bound to the host, which runs exactly when the
## host can process and dies with it. A game that wants a panel to animate under a
## paused scene sets `process_mode` on the host.
func create_tween() -> Tween:
	return host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_BOUND)


## done signals that the transition completed normally. Releases what's blocking input
## and emits the `finished` signal.
func done() -> void:
	if _did_finish:
		return

	_did_finish = true
	_unblock_input()
	finished.emit()


## mount brings in the entering node. This is a no-op if already mounted.
func mount() -> void:
	if _did_mount:
		return

	_did_mount = true
	_mount()


## swap performs an atomic unmount and then mount.
func swap() -> void:
	unmount()
	mount()


## unmount removes the exiting node. This is a no-op if already unmounted.
func unmount() -> void:
	if _did_unmount:
		return

	_did_unmount = true
	_unmount()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(node: Node) -> void:
	assert(node is Node, "invalid argument; missing host")
	host = node


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _block_input covers the rect of each control involved until the transition ends. A
## node without a rect has nothing to cover.
func _block_input() -> void:
	for node: Node in [entering, exiting]:
		if node is Control:
			var blocker := _RectBlocker.new()
			node.add_child(blocker, false, Node.INTERNAL_MODE_BACK)
			_blockers.append(blocker)


## _mount shows the entering node.
func _mount() -> void:
	if entering is CanvasItem:
		entering.visible = true


## _unblock_input removes whatever `_block_input` added.
func _unblock_input() -> void:
	for blocker in _blockers:
		# NOTE: A blocker dies with a parent that was freed mid-transition. It's hidden
		# rather than detached since a parent leaving the tree refuses `remove_child`.
		if is_instance_valid(blocker):
			blocker.hide()
			blocker.queue_free()

	_blockers.clear()


## _unmount hides the exiting node.
func _unmount() -> void:
	if exiting is CanvasItem:
		exiting.visible = false
