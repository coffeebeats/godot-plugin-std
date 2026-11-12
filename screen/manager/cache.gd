##
## screen/manager/cache.gd
##
## Cache holds the scenes the manager keeps while their screens are off the stack, and
## decides where each waits: out of the tree for a `DETACHED` screen, and parked in its
## own overlay for an `IN_TREE` one. Each kept scene holds the preparation it was built
## from, so opening it never waits on a load.
##
## A parked scene is in the tree, hidden, with processing disabled and told it is
## covered, so it draws nothing, gets no input, and holds no action set or focus. Its
## overlay stays a child of the manager for the scene's whole life, so opening it moves
## the overlay to the top instead of re-entering the tree.
##

extends RefCounted

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Preparation := preload("preparation.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #


## Entry is one kept scene.
class Entry:
	extends RefCounted

	## overlay is the overlay an `IN_TREE` scene lives in, or null for a detached one.
	var overlay: StdScreenOverlay = null

	## parked is whether the scene is parked rather than open on the stack.
	var parked: bool = false

	## preparation holds the resources the scene was built from.
	var preparation: Preparation = null

	## scene is the kept scene.
	var scene: Node = null


# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"std/screen/cache")  # gdlint:ignore=class-definitions-order,max-line-length

## _demoted holds each `IN_TREE` screen whose scene can't be parked, kept detached.
var _demoted: Dictionary[StdScreen, bool] = {}

## _entries maps each screen with a kept scene to it.
var _entries: Dictionary[StdScreen, Entry] = {}

## _manager is the manager whose screens this keeps.
var _manager: StdScreenManager = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## admit reports whether `scene` can be parked for `screen`, checking it once, and keeps
## `screen` detached from then on if it can't. A screen kept in the tree always isolates
## input, so it also reports a `block_input_below` that is off.
func admit(screen: StdScreen, scene: Node) -> bool:
	if not screen.block_input_below:
		(
			_logger
			. warn(
				"Ignored 'block_input_below'; a screen kept in the tree isolates input.",
				{&"scene": screen.scene_path},
			)
		)

	var offenders := find_unparkable(scene)
	if offenders.is_empty():
		return true

	(
		_logger
		. error(
			"Scene can't be kept in the tree; keeping it detached.",
			{&"scene": screen.scene_path, &"nodes": ",".join(offenders)},
		)
	)

	_demoted[screen] = true

	return false


## build instantiates the scene of `screen`, an `IN_TREE` screen, from `preparation`
## and parks it, or keeps it detached if it can't be parked. No lifecycle signal fires,
## since the screen isn't on the stack. It returns false if the scene didn't load.
func build(screen: StdScreen, preparation: Preparation) -> bool:
	var packed := preparation.get_scene()
	if packed == null:
		_logger.error("Failed to build kept screen.", {&"scene": screen.scene_path})
		return false

	var scene := packed.instantiate()

	if not admit(screen, scene):
		keep(screen, scene, preparation)
		return true

	var overlay := create_overlay(false)

	# NOTE: The scene enters the tree inside a hidden overlay, so it readies with
	# nothing visible.
	overlay.add_child(scene)
	register(screen, scene, preparation, overlay)
	park(screen)

	return true


## clear frees every kept scene, along with the overlays parked scenes live in.
func clear() -> void:
	for entry: Entry in _entries.values():
		_free(entry)

	_entries.clear()


## create_overlay adds an overlay for a scene kept in the tree to the manager, wired to
## the manager's close handlers as any screen's overlay is.
func create_overlay(shown: bool) -> StdScreenOverlay:
	var overlay := StdScreenOverlay.new()
	overlay.visible = shown
	overlay.background_clicked.connect(_manager._request_close_overlay)
	overlay.close_action_pressed.connect(_manager._request_close_top)
	_manager.add_child(overlay)
	return overlay


## erase forgets the scene kept for `screen` and frees it, which only a detached scene
## may need once its screen stops being kept.
func erase(screen: StdScreen) -> void:
	var entry: Entry = _entries.get(screen)
	if not entry:
		return

	_entries.erase(screen)

	if not entry.overlay and is_instance_valid(entry.scene):
		entry.scene.free()


## find_unparkable returns the path of each node under `scene` that hiding and disabling
## `scene` would leave shown or running, with the reason, or an empty list if none.
static func find_unparkable(scene: Node) -> PackedStringArray:
	var offenders := PackedStringArray()

	if scene is CanvasLayer or scene is Node3D or (scene is Window and scene.visible):
		offenders.append(".: %s" % scene.get_class())

	_find_unparkable_under(scene, scene, offenders)

	return offenders


## get_entry returns the scene kept for `screen`, or null if none is.
func get_entry(screen: StdScreen) -> Entry:
	return _entries.get(screen)


## is_in_tree returns whether `screen` is kept in the tree, which it is when it asks to
## be and its scene can be parked.
func is_in_tree(screen: StdScreen) -> bool:
	return screen.cache_mode == StdScreen.CacheMode.IN_TREE and screen not in _demoted


## keep holds `scene`, out of the tree, for `screen`, with the preparation it came from.
## A different scene kept for `screen` before, such as one an instance passed to an
## operation stood in for, is freed.
func keep(screen: StdScreen, scene: Node, preparation: Preparation) -> void:
	var previous: Entry = _entries.get(screen)
	if previous and previous.scene != scene:
		_free(previous)

	var entry := Entry.new()
	entry.scene = scene
	entry.preparation = preparation
	_entries[screen] = entry


## open shows the parked scene of `screen` at the top of the manager, and returns its
## overlay. The caller restores its processing and tells it it's uncovered.
func open(screen: StdScreen) -> StdScreenOverlay:
	var entry: Entry = _entries[screen]
	assert(entry.overlay, "invalid state; scene isn't kept in the tree")

	_manager.move_child(entry.overlay, _manager.get_child_count() - 1)
	entry.overlay.process_mode = Node.PROCESS_MODE_INHERIT
	entry.overlay.visible = true
	entry.parked = false

	return entry.overlay


## owns returns whether `overlay` belongs to a scene kept in the tree, which outlives
## the screens on the stack.
func owns(overlay: StdScreenOverlay) -> bool:
	for entry: Entry in _entries.values():
		if entry.overlay == overlay:
			return true

	return false


## park hides the scene kept in the tree for `screen`, disables its processing, saving
## the mode it had, and tells its subtree it is covered. It does nothing to a scene that
## is already parked.
##
## NOTE: The screen's lifecycle handlers stay connected, since the scene stays alive to
## use them at the next open.
func park(screen: StdScreen) -> void:
	var entry: Entry = _entries.get(screen)
	if not entry or not entry.overlay or entry.parked:
		return

	entry.parked = true

	# NOTE: The overlay keeps the input settings it had on top until the manager next
	# writes them, so they are cleared here, and it stops running so it sees no input.
	var overlay := entry.overlay
	overlay.visible = false
	overlay.click_to_close = 0
	overlay.close_actions = []
	overlay.consumes_unhandled_input = false
	overlay.process_mode = Node.PROCESS_MODE_DISABLED

	var scene := entry.scene
	if not is_instance_valid(scene):
		return

	if not scene.has_meta(StdScreenManager._META_PROCESS_MODE):
		scene.set_meta(StdScreenManager._META_PROCESS_MODE, scene.process_mode)

	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)


## register records `scene`, open in `overlay`, as the scene kept in the tree for
## `screen`, with the preparation it came from.
func register(
	screen: StdScreen,
	scene: Node,
	preparation: Preparation,
	overlay: StdScreenOverlay,
) -> void:
	keep(screen, scene, preparation)
	_entries[screen].overlay = overlay


## take returns the detached scene kept for `screen`, which leaves the cache, or null if
## none is.
func take(screen: StdScreen) -> Node:
	var entry: Entry = _entries.get(screen)
	if not entry or entry.overlay:
		return null

	_entries.erase(screen)

	return entry.scene if is_instance_valid(entry.scene) else null


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(manager: StdScreenManager) -> void:
	_manager = manager


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _free frees a kept scene, along with its overlay if it lives in one.
static func _free(entry: Entry) -> void:
	if entry.overlay:
		# NOTE: The manager may be leaving the tree, which refuses `remove_child`, so a
		# parked scene goes down with its overlay at the end of the frame.
		if is_instance_valid(entry.overlay):
			entry.overlay.queue_free()
	elif is_instance_valid(entry.scene):
		entry.scene.free()


## _find_unparkable_under appends to `offenders` each node under `node` that hiding and
## disabling `top` would leave shown or running.
static func _find_unparkable_under(
	node: Node, top: Node, offenders: PackedStringArray
) -> void:
	for child in node.get_children():
		var reason := ""

		if (
			child is CanvasLayer
			or child is Node3D
			or (child is Window and child.visible)
		):
			reason = child.get_class()
		elif child is CanvasItem and not node is CanvasItem:
			reason = "CanvasItem under %s" % node.get_class()
		elif (
			child.process_mode != Node.PROCESS_MODE_INHERIT
			and child.process_mode != Node.PROCESS_MODE_DISABLED
		):
			reason = "process mode %d" % child.process_mode

		if reason:
			offenders.append("%s: %s" % [top.get_path_to(child), reason])

		_find_unparkable_under(child, top, offenders)
