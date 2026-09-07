##
## screen/manager/overlays.gd
##
## Tracks overlay-to-screen mappings and manages overlay lifecycle.
##

extends RefCounted

# -- INITIALIZATION ------------------------------------------------------------------ #

var _overlays: Dictionary[StdScreen, StdScreenOverlay] = {}
var _owner: Node

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init(owner: Node) -> void:
	_owner = owner


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## clear frees all overlay nodes and removes all screen-overlay mappings.
func clear() -> void:
	var seen: Dictionary = {}
	for overlay: StdScreenOverlay in _overlays.values():
		if not is_instance_valid(overlay) or overlay in seen:
			continue

		seen[overlay] = true

		# NOTE: If the overlay still has a parent, the parent may be blocked
		# (e.g. during teardown). Use `queue_free` to let the parent cascade the
		# removal; otherwise free immediately to prevent orphans.
		if overlay.get_parent():
			overlay.queue_free()
		else:
			overlay.free()

	_overlays.clear()


## erase removes the mapping for the given screen.
func erase(screen: StdScreen) -> void:
	_overlays.erase(screen)


## free_if_unused frees an overlay if no screen still references it.
##
## NOTE: This frees the overlay right away. That is only safe because the caller has
## already detached the overlay's scene and attachments.
func free_if_unused(overlay: StdScreenOverlay) -> void:
	if not is_instance_valid(overlay):
		return
	if is_in_use(overlay):
		return

	if overlay.is_inside_tree():
		overlay.get_parent().remove_child(overlay)

	overlay.free()


## get_current returns the overlay for the topmost screen.
func get_current(stack: Array[StdScreen]) -> StdScreenOverlay:
	return null if stack.is_empty() else _overlays.get(stack[-1])


## get_or_create returns or creates an overlay for the given screen. When
## `block_input_below` is false and the stack is non-empty, shares the top screen's
## overlay.
func get_or_create(
	stack: Array[StdScreen],
	block_input_below: bool,
	on_background_clicked: Callable,
) -> StdScreenOverlay:
	if not block_input_below and not stack.is_empty():
		var shared: StdScreenOverlay = _overlays.get(stack[-1])
		assert(
			not shared or shared.get_parent() == _owner,
			"invalid state; overlay not child of manager",
		)

		if is_instance_valid(shared):
			return shared

	var overlay := StdScreenOverlay.new()
	overlay.background_clicked.connect(on_background_clicked)
	_owner.add_child(overlay)
	return overlay


## get_overlay returns the overlay for the given screen, or null.
func get_overlay(screen: StdScreen) -> StdScreenOverlay:
	return _overlays.get(screen)


## get_screens returns all screens sharing the given overlay.
func get_screens(
	overlay: StdScreenOverlay,
	stack: Array[StdScreen],
) -> Array[StdScreen]:
	var screens: Array[StdScreen] = []
	for screen in stack:
		if _overlays.get(screen) == overlay:
			screens.append(screen)
	return screens


## is_in_use returns whether any screen references the given overlay.
func is_in_use(overlay: StdScreenOverlay) -> bool:
	return _overlays.values().has(overlay)


## register stores the overlay mapping for a screen.
func register(
	screen: StdScreen,
	overlay: StdScreenOverlay,
) -> void:
	_overlays[screen] = overlay


## update_config recalculates overlay state after a stack operation: which overlay
## consumes unhandled input, and the click-to-close mask for the top-most overlay.
func update_config(stack: Array[StdScreen]) -> void:
	var current := get_current(stack)

	# NOTE: Only overlays still backing a stacked screen count; a popped screen's overlay
	# stays mapped until teardown. A lone overlay does not consume, so input passes
	# through to the rest of the application.
	var distinct: Dictionary[StdScreenOverlay, bool] = {}
	for screen in stack:
		var overlay: StdScreenOverlay = _overlays.get(screen)
		if is_instance_valid(overlay):
			distinct[overlay] = true

	# NOTE: Every overlay is written so one that was on top stops consuming once covered.
	for overlay: StdScreenOverlay in _overlays.values():
		if is_instance_valid(overlay):
			overlay.consumes_unhandled_input = (
				overlay == current and distinct.size() > 1
			)

	if not is_instance_valid(current):
		return

	var mask := 0
	for screen in get_screens(current, stack):
		mask |= screen.overlay_click_to_close
	current.click_to_close = mask
