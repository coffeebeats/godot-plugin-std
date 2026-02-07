#gdlint:ignore=max-public-methods

##
## router/stage_test.gd
##
## Tests for StdRouterStage view reconciler: scene tracking, container
## management, overlay lifecycle, snapshot/restore, and focus edge cases.
##

extends GutTest

# -- DEPENDENCIES ------------------------------------------------------------ #

const StdRouterOverlay := preload("overlay.gd")
const StdRouterStage := preload("stage.gd")
const StdRouteModal := preload("route/modal.gd")
const StdRouteView := preload("route/view.gd")

# -- INITIALIZATION ---------------------------------------------------------- #

var _stage: StdRouterStage
var _content_root: Node
var _overlay_root: Node

# -- TEST METHODS: SCENES ---------------------------------------------------- #


func test_get_scene_returns_null_for_null_route():
	# Given: A stage with no tracked scenes.

	# When: get_scene is called with null.
	var result := _stage.get_scene(null)

	# Then: Null is returned.
	assert_null(result)


func test_get_scene_returns_null_for_unknown_route():
	# Given: A stage with no tracked scenes.
	var route := _create_view(&"unknown")

	# When: get_scene is called with an untracked route.
	var result := _stage.get_scene(route)

	# Then: Null is returned.
	assert_null(result)


func test_get_scene_returns_tracked_scene():
	# Given: A stage with a manually tracked scene.
	var route := _create_view(&"tracked")
	var scene := Node.new()
	_stage._active_scenes[route] = scene

	# When: get_scene is called.
	var result := _stage.get_scene(route)

	# Then: The tracked scene is returned.
	assert_eq(result, scene)

	# Cleanup.
	scene.free()


func test_cleanup_scene_erases_scene_and_focus():
	# Given: A stage with a tracked scene and focus entry.
	var route := _create_view(&"route")
	var scene := Node.new()
	_stage._active_scenes[route] = scene
	_stage._scene_focus[scene] = Control.new()

	# When: cleanup_scene is called.
	_stage.cleanup_scene(route)

	# Then: Scene and focus are erased.
	assert_null(_stage.get_scene(route))
	assert_false(_stage._scene_focus.has(scene))

	# Cleanup.
	scene.free()


func test_cleanup_scene_no_op_for_unknown_route():
	# Given: A stage with no tracked scenes.
	var route := _create_view(&"unknown")

	# When: cleanup_scene is called with unknown route.
	_stage.cleanup_scene(route)

	# Then: No error (no-op).
	assert_null(_stage.get_scene(route))


func test_cleanup_entering_frees_scenes():
	# Given: A stage with tracked scenes for entering routes.
	var route_a := _create_view(&"a")
	var route_b := _create_view(&"b")
	var scene_a := Node.new()
	var scene_b := Node.new()
	_stage._active_scenes[route_a] = scene_a
	_stage._active_scenes[route_b] = scene_b

	# When: cleanup_entering is called.
	var routes: Array[StdRoute] = [route_a, route_b]
	_stage.cleanup_entering(routes)

	# Then: Scenes are erased from tracking.
	assert_null(_stage.get_scene(route_a))
	assert_null(_stage.get_scene(route_b))


# -- TEST METHODS: CONTAINERS ------------------------------------------------ #


func test_register_container_adds_to_mapping():
	# Given: A container and a route.
	var route := _create_view(&"parent")
	var container := StdRouteContainer.new()

	# When: The container is registered.
	_stage.register_container(container, route)

	# Then: The container is tracked.
	assert_true(_stage._containers.has(route))
	var containers: Array[StdRouteContainer] = _stage._containers[route]
	assert_true(container in containers)

	# Cleanup.
	container.free()


func test_register_container_with_null_route():
	# Given: A container with no route (root container).
	var container := StdRouteContainer.new()

	# When: The container is registered with null route.
	_stage.register_container(container, null)

	# Then: The container is tracked under null key.
	assert_true(_stage._containers.has(null))

	# Cleanup.
	container.free()


func test_unregister_container_removes_from_mapping():
	# Given: A registered container.
	var route := _create_view(&"parent")
	var container := StdRouteContainer.new()
	_stage.register_container(container, route)

	# When: The container is unregistered.
	_stage.unregister_container(container)

	# Then: The container is removed.
	var containers: Array[StdRouteContainer] = _stage._containers[route]
	assert_false(container in containers)

	# Cleanup.
	container.free()


func test_get_container_top_level_view_returns_content_root():
	# Given: A stage with content_root set.
	var route := _create_view(&"top_level")

	# When: get_container is called with a single-element chain.
	var chain: Array[StdRoute] = [route]
	var result := _stage.get_container(route, chain)

	# Then: content_root is returned.
	assert_eq(result, _content_root)


func test_get_container_top_level_modal_returns_overlay_root():
	# Given: A stage with overlay_root set.
	var modal := _create_modal(&"top_level")

	# When: get_container is called with a single-element chain.
	var chain: Array[StdRoute] = [modal]
	var result := _stage.get_container(modal, chain)

	# Then: overlay_root is returned.
	assert_eq(result, _overlay_root)


func test_get_container_nested_returns_parent_container():
	# Given: A parent route with a tracked scene and container.
	var parent := _create_view(&"parent")
	var child := _create_view(&"child")
	var parent_scene := Node.new()
	var container := StdRouteContainer.new()
	container.view_type = (StdRouteContainer.ViewType.VIEW_TYPE_CONTENT)

	_stage._active_scenes[parent] = parent_scene
	_stage.register_container(container, parent)

	# When: get_container is called for the child.
	var chain: Array[StdRoute] = [parent, child]
	var result := _stage.get_container(child, chain)

	# Then: The parent's container is returned.
	assert_eq(result, container)

	# Cleanup.
	parent_scene.free()
	container.free()


# -- TEST METHODS: OVERLAYS -------------------------------------------------- #


func test_create_overlay_tracks_overlay():
	# Given: A modal route.
	var modal := _create_modal(&"dialog")

	# When: An overlay is created.
	var overlay := _stage.create_overlay(modal)

	# Then: The overlay is tracked.
	assert_not_null(overlay)
	assert_eq(_stage.get_overlay(modal), overlay)

	# Cleanup.
	overlay.free()


func test_create_overlay_configures_from_modal():
	# Given: A modal with specific configuration.
	var modal := _create_modal(&"config")
	modal.backdrop_mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.close_on_backdrop = 1
	modal.close_action = &"ui_cancel"

	# When: An overlay is created.
	var overlay := _stage.create_overlay(modal)

	# Then: The overlay has the modal's configuration.
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(overlay.click_to_close, 1)
	assert_eq(overlay.close_action, &"ui_cancel")

	# Cleanup.
	overlay.free()


func test_get_overlay_returns_null_for_unknown():
	# Given: A modal with no overlay created.
	var modal := _create_modal(&"unknown")

	# When: get_overlay is called.
	var result := _stage.get_overlay(modal)

	# Then: Null is returned.
	assert_null(result)


func test_disconnect_overlay_disconnects_signals():
	# Given: A created overlay.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)

	# When: disconnect_overlay is called.
	_stage.disconnect_overlay(modal)

	# Then: Signals are disconnected.
	assert_false(
		overlay.backdrop_clicked.is_connected(_stage._on_overlay_backdrop_clicked)
	)
	assert_false(
		overlay.cancel_requested.is_connected(_stage._on_overlay_cancel_requested)
	)

	# Cleanup.
	overlay.free()


func test_disconnect_overlay_no_op_for_unknown():
	# Given: A modal with no overlay.
	var modal := _create_modal(&"unknown")

	# When: disconnect_overlay is called.
	_stage.disconnect_overlay(modal)

	# Then: No error (no-op).
	assert_null(_stage.get_overlay(modal))


func test_cleanup_overlay_erases_tracking():
	# Given: A created overlay added to the tree.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)
	add_child_autofree(overlay)

	# When: cleanup_overlay is called.
	_stage.cleanup_overlay(modal)

	# Then: The overlay is no longer tracked.
	assert_null(_stage.get_overlay(modal))


func test_cleanup_overlay_no_op_for_unknown():
	# Given: A modal with no overlay.
	var modal := _create_modal(&"unknown")

	# When: cleanup_overlay is called.
	_stage.cleanup_overlay(modal)

	# Then: No error (no-op).
	assert_null(_stage.get_overlay(modal))


func test_cleanup_all_overlays_clears_all():
	# Given: Multiple created overlays in the tree.
	var modal_a := _create_modal(&"a")
	var modal_b := _create_modal(&"b")
	var overlay_a := _stage.create_overlay(modal_a)
	var overlay_b := _stage.create_overlay(modal_b)
	add_child_autofree(overlay_a)
	add_child_autofree(overlay_b)

	# When: cleanup_all_overlays is called.
	_stage.cleanup_all_overlays()

	# Then: All overlays are erased.
	assert_null(_stage.get_overlay(modal_a))
	assert_null(_stage.get_overlay(modal_b))


# -- TEST METHODS: OVERLAY SIGNALS ------------------------------------------- #


func test_overlay_backdrop_click_forwards_signal():
	# Given: A stage with a created overlay.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)
	watch_signals(_stage)

	# When: The overlay emits backdrop_clicked.
	var event := InputEventMouseButton.new()
	overlay.backdrop_clicked.emit(event)

	# Then: The stage forwards the signal.
	assert_signal_emitted(_stage, "overlay_backdrop_clicked")

	# Cleanup.
	overlay.free()


func test_overlay_cancel_forwards_signal():
	# Given: A stage with a created overlay.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)
	watch_signals(_stage)

	# When: The overlay emits cancel_requested.
	overlay.cancel_requested.emit()

	# Then: The stage forwards the signal.
	assert_signal_emitted(_stage, "overlay_cancel_requested")

	# Cleanup.
	overlay.free()


# -- TEST METHODS: SNAPSHOTS ------------------------------------------------- #


func test_snapshot_overlays_returns_copy():
	# Given: A stage with two overlays.
	var modal_a := _create_modal(&"a")
	var modal_b := _create_modal(&"b")
	var overlay_a := _stage.create_overlay(modal_a)
	var overlay_b := _stage.create_overlay(modal_b)

	# When: A snapshot is taken.
	var snapshot := _stage.snapshot_overlays()

	# Then: The snapshot contains both overlays.
	assert_eq(snapshot.size(), 2)
	assert_eq(snapshot[modal_a], overlay_a)
	assert_eq(snapshot[modal_b], overlay_b)

	# Then: Modifying the snapshot doesn't affect the stage.
	snapshot.clear()
	assert_eq(_stage.get_overlay(modal_a), overlay_a)

	# Cleanup.
	overlay_a.free()
	overlay_b.free()


func test_restore_snapshot_frees_new_overlays():
	# Given: A stage with one overlay (the "before" state).
	var modal_old := _create_modal(&"old")
	var overlay_old := _stage.create_overlay(modal_old)

	# Given: A snapshot of the "before" state.
	var snapshot := _stage.snapshot_overlays()

	# Given: A new overlay is created after the snapshot.
	var modal_new := _create_modal(&"new")
	var overlay_new := _stage.create_overlay(modal_new)

	# When: The snapshot is restored.
	_stage.restore_overlay_snapshot(snapshot)

	# Then: The new overlay is erased.
	assert_null(_stage.get_overlay(modal_new))

	# Then: The old overlay survives.
	assert_eq(_stage.get_overlay(modal_old), overlay_old)

	# Cleanup.
	overlay_old.free()


func test_restore_snapshot_reconnects_surviving():
	# Given: A stage with an overlay.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)

	# Given: A snapshot and then disconnect.
	var snapshot := _stage.snapshot_overlays()
	_stage.disconnect_overlay(modal)

	# Verify signals are disconnected.
	assert_false(
		overlay.backdrop_clicked.is_connected(_stage._on_overlay_backdrop_clicked)
	)

	# When: The snapshot is restored.
	_stage.restore_overlay_snapshot(snapshot)

	# Then: Signals are reconnected.
	assert_true(
		overlay.backdrop_clicked.is_connected(_stage._on_overlay_backdrop_clicked)
	)
	assert_true(
		overlay.cancel_requested.is_connected(_stage._on_overlay_cancel_requested)
	)

	# Cleanup.
	overlay.free()


func test_snapshot_on_empty_returns_empty():
	# Given: A stage with no overlays.

	# When: A snapshot is taken.
	var snapshot := _stage.snapshot_overlays()

	# Then: The snapshot is empty.
	assert_eq(snapshot.size(), 0)


# -- TEST METHODS: ACTIVE OVERLAY -------------------------------------------- #


func test_set_active_overlay_activates_matching():
	# Given: Two overlays for two modals.
	var modal_a := _create_modal(&"a")
	var modal_b := _create_modal(&"b")
	var overlay_a := _stage.create_overlay(modal_a)
	var overlay_b := _stage.create_overlay(modal_b)

	# When: set_active_overlay is called with modal_b.
	_stage.set_active_overlay(modal_b)

	# Then: Only overlay_b is active.
	assert_false(overlay_a.active)
	assert_true(overlay_b.active)

	# Cleanup.
	overlay_a.free()
	overlay_b.free()


func test_set_active_overlay_null_deactivates_all():
	# Given: Two overlays.
	var modal_a := _create_modal(&"a")
	var modal_b := _create_modal(&"b")
	var overlay_a := _stage.create_overlay(modal_a)
	var overlay_b := _stage.create_overlay(modal_b)

	# When: set_active_overlay is called with null.
	_stage.set_active_overlay(null)

	# Then: Both overlays are inactive.
	assert_false(overlay_a.active)
	assert_false(overlay_b.active)

	# Cleanup.
	overlay_a.free()
	overlay_b.free()


func test_set_active_overlay_single_overlay():
	# Given: A single overlay.
	var modal := _create_modal(&"dialog")
	var overlay := _stage.create_overlay(modal)

	# When: set_active_overlay is called with the modal.
	_stage.set_active_overlay(modal)

	# Then: The overlay is active.
	assert_true(overlay.active)

	# Cleanup.
	overlay.free()


# -- TEST METHODS: FOCUS ----------------------------------------------------- #


func test_save_focus_null_scene_is_no_op():
	# Given: A stage.

	# When: save_focus is called with null scene.
	_stage.save_focus(null, get_viewport())

	# Then: No error (no-op). Nothing to assert beyond no crash.
	assert_true(true)


func test_save_focus_null_viewport_is_no_op():
	# Given: A stage with a scene.
	var scene := Node.new()

	# When: save_focus is called with null viewport.
	_stage.save_focus(scene, null)

	# Then: No focus saved.
	assert_false(_stage._scene_focus.has(scene))

	# Cleanup.
	scene.free()


func test_restore_focus_null_scene_is_no_op():
	# Given: A stage.

	# When: restore_focus is called with null.
	_stage.restore_focus(null)

	# Then: No error (no-op). Nothing to assert beyond no crash.
	assert_true(true)


func test_restore_focus_non_control_is_no_op():
	# Given: A non-Control scene node.
	var scene := Node.new()

	# When: restore_focus is called.
	_stage.restore_focus(scene)

	# Then: No error (no-op).
	assert_true(true)

	# Cleanup.
	scene.free()


func test_restore_focus_prefers_overlay_tracked_focus():
	# Given: An overlay with a scene child added to the tree.
	var overlay := StdRouterOverlay.new()
	var scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	scene.add_child(button)
	overlay.add_child(scene)
	add_child_autofree(overlay)

	# Given: The overlay has tracked focus on the button.
	overlay._last_focus = button

	# Given: The stage has a stale snapshot focus.
	var stale := Button.new()
	stale.focus_mode = Control.FOCUS_ALL
	scene.add_child(stale)
	_stage._scene_focus[scene] = stale

	# When: restore_focus is called.
	_stage.restore_focus(scene)

	# Then: The overlay-tracked focus is used.
	assert_eq(button.has_focus(), true)


func test_restore_focus_falls_back_without_overlay():
	# Given: A scene (not parented to an overlay) in the tree.
	var scene := Control.new()
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	scene.add_child(button)
	add_child_autofree(scene)

	# Given: A saved focus in the stage.
	_stage._scene_focus[scene] = button

	# When: restore_focus is called.
	_stage.restore_focus(scene)

	# Then: The stage snapshot focus is used.
	assert_eq(button.has_focus(), true)


# -- TEST METHODS: VERIFY NESTED --------------------------------------------- #


func test_verify_nested_single_route_succeeds():
	# Given: An ancestor chain with a single top-level route.
	var route := _create_view(&"top")
	var chain: Array[StdRoute] = [route]

	# When: verify_nested is called.
	var err := _stage.verify_nested(chain)

	# Then: No nested routes to verify, returns OK.
	assert_eq(err, OK)


func test_verify_nested_skips_uninstantiated_parent():
	# Given: A parent with no active scene and a child route.
	var parent := _create_view(&"parent")
	var child := _create_view(&"child")
	var chain: Array[StdRoute] = [parent, child]

	# When: verify_nested is called.
	var err := _stage.verify_nested(chain)

	# Then: Returns OK (parent scene not yet instantiated).
	assert_eq(err, OK)


# -- TEST HOOKS -------------------------------------------------------------- #


func before_each() -> void:
	_content_root = Node.new()
	_content_root.name = "ContentRoot"

	_overlay_root = Node.new()
	_overlay_root.name = "OverlayRoot"

	_stage = StdRouterStage.new()
	_stage.content_root = _content_root
	_stage.overlay_root = _overlay_root


func after_each() -> void:
	_stage = null

	if is_instance_valid(_content_root):
		_content_root.free()
		_content_root = null

	if is_instance_valid(_overlay_root):
		_overlay_root.free()
		_overlay_root = null


# -- PRIVATE METHODS --------------------------------------------------------- #


func _create_view(segment: StringName) -> StdRouteView:
	var route := StdRouteView.new()
	route.segment = segment
	route.name = str(segment)
	return route


func _create_modal(segment: StringName) -> StdRouteModal:
	var route := StdRouteModal.new()
	route.segment = segment
	route.name = str(segment)
	return route
