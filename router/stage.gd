##
## router/stage.gd
##
## StdRouterStage manages all visual state for the router: active
## scenes, overlays, containers, and focus tracking. It serves as
## the view reconciler — the router tells the stage what to render
## without the stage knowing about navigation layers or hooks.
##

class_name StdRouterStage
extends RefCounted

# -- SIGNALS ----------------------------------------------------------------- #

## overlay_backdrop_clicked is forwarded from individual overlays.
signal overlay_backdrop_clicked(event: InputEventMouseButton)

## overlay_cancel_requested is forwarded from individual overlays.
signal overlay_cancel_requested

# -- INITIALIZATION ---------------------------------------------------------- #

## content_root is the node where top-level view scenes render.
var content_root: Node = null

## overlay_root is the node where top-level modal scenes render.
var overlay_root: Node = null

## _active_scenes maps routes to instantiated scene nodes.
var _active_scenes: Dictionary = {}

## _active_overlays maps StdRouteModal to StdRouterOverlay.
var _active_overlays: Dictionary = {}

## _containers maps routes (or null) to StdRouteContainer arrays.
var _containers: Dictionary = {}

## _scene_focus tracks last focused control per scene node.
var _scene_focus: Dictionary = {}

# -- PUBLIC METHODS: SCENES -------------------------------------------------- #


## instantiate creates a scene for a renderable route without
## adding it to the tree. Returns the instance, or null.
func instantiate(route: StdRoute) -> Node:
	if not route is StdRouteRenderable:
		return null

	var renderable := route as StdRouteRenderable
	var scene := renderable.get_scene()
	if scene == null:
		return null

	var instance := scene.instantiate()
	_active_scenes[route] = instance
	return instance


## get_scene returns the active scene for a route, or null.
func get_scene(route: StdRoute) -> Node:
	if route == null:
		return null
	return _active_scenes.get(route)


## cleanup_scene erases a route's scene and focus tracking.
func cleanup_scene(route: StdRoute) -> void:
	var scene: Node = _active_scenes.get(route)
	if scene:
		_scene_focus.erase(scene)
	_active_scenes.erase(route)


## cleanup_entering frees and erases scenes for interrupted
## entering routes.
func cleanup_entering(routes: Array[StdRoute]) -> void:
	for route in routes:
		var scene: Node = _active_scenes.get(route)
		if scene and is_instance_valid(scene):
			if scene.is_inside_tree():
				scene.queue_free()
			else:
				scene.free()
		_active_scenes.erase(route)


# -- PUBLIC METHODS: CONTAINERS ---------------------------------------------- #


## get_container returns the container node for a route. Walks
## the ancestor chain (provided by the caller) to find the
## nearest ancestor with an active scene and matching container.
## Falls back to content_root or overlay_root.
func get_container(
	route: StdRoute,
	ancestor_chain: Array[StdRoute],
) -> Node:
	var required_type := StdRouteContainer.ViewType.VIEW_TYPE_CONTENT
	if route is StdRouteModal:
		required_type = StdRouteContainer.ViewType.VIEW_TYPE_MODAL

	# Walk up ancestors (excluding the route itself).
	for i in range(ancestor_chain.size() - 2, -1, -1):
		var ancestor := ancestor_chain[i]

		if not _active_scenes.has(ancestor):
			continue

		if _containers.has(ancestor):
			var containers: Array[StdRouteContainer] = _containers[ancestor]
			for container in containers:
				if container.view_type == required_type:
					return container

		push_error(
			"StdRouterStage: No container for nested" + " route '%s'" % route.name
		)
		return null

	if route is StdRouteModal:
		return overlay_root
	return content_root


## verify_nested validates containers exist for nested routes.
func verify_nested(
	ancestor_chain: Array[StdRoute],
) -> Error:
	for i in range(1, ancestor_chain.size()):
		var current := ancestor_chain[i]
		var parent := ancestor_chain[i - 1]

		var required_type := StdRouteContainer.ViewType.VIEW_TYPE_CONTENT
		if current is StdRouteModal:
			required_type = (StdRouteContainer.ViewType.VIEW_TYPE_MODAL)

		var parent_scene: Node = _active_scenes.get(parent)
		if parent_scene == null:
			continue

		var found := false
		if _containers.has(parent):
			var containers: Array[StdRouteContainer] = _containers[parent]
			for container in containers:
				if (
					container.view_type == required_type
					and parent_scene.is_ancestor_of(container)
				):
					found = true
					break

		if not found:
			push_error(
				(
					"StdRouterStage: Missing StdRouteContainer"
					+ " for nested route %s" % current.name
				)
			)
			return ERR_DOES_NOT_EXIST

	return OK


## register_container adds a container to the mapping.
func register_container(container: StdRouteContainer, route: StdRoute) -> void:
	container.route = route

	if not _containers.has(route):
		_containers[route] = [] as Array[StdRouteContainer]

	var containers: Array[StdRouteContainer] = _containers[route]

	for existing in containers:
		assert(
			existing.view_type != container.view_type,
			(
				("invalid state: duplicate container type %s" + " for route %s")
				% [
					container.view_type,
					route.name if route else "root",
				]
			)
		)

	containers.append(container)


## unregister_container removes a container from the mapping.
func unregister_container(container: StdRouteContainer) -> void:
	for route in _containers:
		var containers: Array[StdRouteContainer] = _containers[route]
		containers.erase(container)


# -- PUBLIC METHODS: OVERLAYS ------------------------------------------------ #


## create_overlay creates and configures a StdRouterOverlay from
## a modal route, connecting close trigger signals.
func create_overlay(modal: StdRouteModal) -> StdRouterOverlay:
	var overlay := StdRouterOverlay.new()
	overlay.mouse_filter = modal.backdrop_mouse_filter
	overlay.click_to_close = modal.close_on_backdrop
	overlay.close_action = modal.close_action
	overlay.backdrop_clicked.connect(_on_overlay_backdrop_clicked)
	overlay.cancel_requested.connect(_on_overlay_cancel_requested)
	_active_overlays[modal] = overlay
	return overlay


## get_overlay returns the overlay for a modal, or null.
func get_overlay(modal: StdRouteModal) -> StdRouterOverlay:
	return _active_overlays.get(modal)


## disconnect_overlay disconnects signals without freeing.
func disconnect_overlay(modal: StdRouteModal) -> void:
	var overlay: StdRouterOverlay = _active_overlays.get(modal)
	if overlay == null:
		return
	_disconnect_signals(overlay)


## cleanup_overlay disconnects, frees, and erases an overlay.
func cleanup_overlay(modal: StdRouteModal) -> void:
	var overlay: StdRouterOverlay = _active_overlays.get(modal)
	if overlay == null:
		return

	_disconnect_signals(overlay)
	overlay.queue_free()
	_active_overlays.erase(modal)


## cleanup_all_overlays disconnects and frees all overlays.
func cleanup_all_overlays() -> void:
	for modal in _active_overlays.keys():
		var overlay: StdRouterOverlay = _active_overlays[modal]
		if overlay and is_instance_valid(overlay):
			_disconnect_signals(overlay)
			overlay.queue_free()
	_active_overlays.clear()


## set_active_overlay marks the overlay for the given modal as
## active and deactivates all others. Pass null to deactivate all.
func set_active_overlay(modal: StdRouteModal) -> void:
	for key in _active_overlays:
		var overlay: StdRouterOverlay = _active_overlays[key]
		if overlay and is_instance_valid(overlay):
			overlay.active = (key == modal)


# -- PUBLIC METHODS: FOCUS --------------------------------------------------- #


## save_focus records the currently focused control for a scene.
func save_focus(scene: Node, viewport: Viewport) -> void:
	if scene == null:
		return
	if viewport == null:
		return

	var focused := viewport.gui_get_focus_owner()
	if focused and scene.is_ancestor_of(focused):
		_scene_focus[scene] = focused


## restore_focus restores saved focus for a scene. Prefers
## overlay-tracked focus for modal scenes, then falls back to
## the navigation snapshot, StdInputCursor, or first focusable.
func restore_focus(scene: Node) -> void:
	if scene == null:
		return
	if not scene is Control:
		return

	var control := scene as Control

	# Prefer overlay-tracked focus for modal scenes.
	var parent := scene.get_parent()
	if parent is StdRouterOverlay:
		var tracked := (parent as StdRouterOverlay).get_last_focus()
		if tracked:
			tracked.grab_focus()
			return

	var saved: Control = _scene_focus.get(scene)
	if (
		saved
		and is_instance_valid(saved)
		and saved.is_visible_in_tree()
		and saved.focus_mode != Control.FOCUS_NONE
	):
		saved.grab_focus()
		return

	var cursor := _get_input_cursor()
	if cursor:
		cursor.set_focus_root(control)
		return

	var focusable := _find_first_focusable(control)
	if focusable:
		focusable.grab_focus()


# -- PUBLIC METHODS: SNAPSHOTS ----------------------------------------------- #


## snapshot_overlays returns a shallow copy of _active_overlays.
func snapshot_overlays() -> Dictionary:
	return _active_overlays.duplicate()


## restore_overlay_snapshot frees overlays not in the snapshot
## and reconnects signals for surviving ones.
func restore_overlay_snapshot(snapshot: Dictionary) -> void:
	for modal in _active_overlays.keys():
		if modal not in snapshot:
			var overlay: StdRouterOverlay = _active_overlays[modal]
			if overlay and is_instance_valid(overlay):
				_disconnect_signals(overlay)
				if overlay.is_inside_tree():
					overlay.queue_free()
				else:
					overlay.free()
			_active_overlays.erase(modal)

	for modal in snapshot:
		var overlay: StdRouterOverlay = snapshot[modal]
		if overlay and is_instance_valid(overlay):
			if not overlay.backdrop_clicked.is_connected(_on_overlay_backdrop_clicked):
				overlay.backdrop_clicked.connect(_on_overlay_backdrop_clicked)
			if not overlay.cancel_requested.is_connected(_on_overlay_cancel_requested):
				overlay.cancel_requested.connect(_on_overlay_cancel_requested)


# -- PRIVATE METHODS --------------------------------------------------------- #


## _disconnect_signals disconnects overlay close trigger signals.
func _disconnect_signals(overlay: StdRouterOverlay) -> void:
	if overlay.backdrop_clicked.is_connected(_on_overlay_backdrop_clicked):
		overlay.backdrop_clicked.disconnect(_on_overlay_backdrop_clicked)
	if overlay.cancel_requested.is_connected(_on_overlay_cancel_requested):
		overlay.cancel_requested.disconnect(_on_overlay_cancel_requested)


## _get_input_cursor returns the StdInputCursor singleton via
## StdGroup, or null if none is registered.
func _get_input_cursor() -> StdInputCursor:
	var group := StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR)
	var members := group.list_members()
	if members.is_empty():
		return null
	return members[0] as StdInputCursor


## _find_first_focusable recursively finds the first Control that
## can receive focus. Returns null if none exists.
func _find_first_focusable(node: Control) -> Control:
	if node.focus_mode != Control.FOCUS_NONE:
		return node

	for child in node.get_children():
		if child is Control:
			var result := _find_first_focusable(child as Control)
			if result:
				return result

	return null


# -- SIGNAL HANDLERS --------------------------------------------------------- #


func _on_overlay_backdrop_clicked(
	event: InputEventMouseButton,
) -> void:
	overlay_backdrop_clicked.emit(event)


func _on_overlay_cancel_requested() -> void:
	overlay_cancel_requested.emit()
