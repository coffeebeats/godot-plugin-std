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


## clear removes all screen-overlay mappings.
func clear() -> void:
	_overlays.clear()


## erase removes the mapping for the given screen.
func erase(screen: StdScreen) -> void:
	_overlays.erase(screen)


## free_if_unused frees an overlay if no screen still references it.
func free_if_unused(overlay: StdScreenOverlay) -> void:
	if not is_instance_valid(overlay):
		return
	if is_in_use(overlay):
		return

	if overlay.is_inside_tree():
		overlay.get_parent().remove_child(overlay)

	overlay.queue_free()


## get_current returns the overlay for the topmost screen.
func get_current(stack: Array[StdScreen]) -> StdScreenOverlay:
	return null if stack.is_empty() else _overlays.get(stack[-1])


## get_or_create returns or creates an overlay for the given screen. When
## `block_input_below` is false and the stack is non-empty, shares the top screen's
## overlay. When `reuse` is provided and valid, it will be returned directly.
func get_or_create(
	stack: Array[StdScreen],
	block_input_below: bool,
	on_background_clicked: Callable,
	reuse: StdScreenOverlay = null,
) -> StdScreenOverlay:
	if is_instance_valid(reuse) and block_input_below:
		return reuse

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


## update_config recalculates the click-to-close mask for the top-most overlay.
func update_config(stack: Array[StdScreen]) -> void:
	var overlay := get_current(stack)
	if not is_instance_valid(overlay):
		return

	var mask := 0
	for screen in get_screens(overlay, stack):
		mask |= screen.overlay_click_to_close
	overlay.click_to_close = mask
