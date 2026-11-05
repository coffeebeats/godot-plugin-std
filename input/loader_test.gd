# gdlint:ignore=max-public-methods
##
## std/input/loader_test.gd
##
## Tests pertaining to `StdInputActionSetLoader`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

const _TEST_ATTACHMENT_PATH := "res://input/_test_attachment.tscn"

var _slot: StdInputSlot = null
var _action_set: StdInputActionSet = null
var _layer: StdInputActionSetLayer = null
var _menu: StdInputActionSet = null
var _build_layer: StdInputActionSetLayer = null
var _panel_layer: StdInputActionSetLayer = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_loader_in_tree_follows_the_tree_and_the_screen() -> void:
	# Given: A loader active while in the tree, with a set and a layer.
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)

	# When: It enters the tree.
	add_child_autofree(loader)
	await wait_idle_frames(1)

	# Then: The set is loaded and the layer enabled.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: Another screen covers it, loading its own set.
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	_slot.load_action_set(_make_action_set(&"Menu"))

	# Then: The layer is disabled.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The screen is uncovered.
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)

	# Then: The set is loaded again and the layer enabled.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: The loader leaves the tree.
	remove_child(loader)

	# Then: The layer is disabled.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])


func test_loader_in_tree_ignores_its_own_visibility() -> void:
	# Given: A loader active while in the tree, under a hidden parent.
	var parent := Control.new()
	parent.hide()
	add_child_autofree(parent)
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)

	# When: It enters the tree.
	parent.add_child(loader)
	await wait_idle_frames(1)

	# Then: The layer is enabled all the same.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_visible_follows_visibility_and_the_screen() -> void:
	# Given: A loader active while visible, under a parent hidden before it enters.
	var parent := Control.new()
	parent.hide()
	add_child_autofree(parent)
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE)

	# When: It enters the tree hidden.
	parent.add_child(loader)
	await wait_idle_frames(1)

	# Then: Nothing is loaded or enabled.
	assert_null(_slot.actions.get_action_set(_slot.device_id))
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The screen is covered and uncovered while it is hidden.
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)

	# Then: Still nothing.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The parent is shown.
	parent.show()

	# Then: The set is loaded and the layer enabled.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: The parent is hidden.
	parent.hide()

	# Then: The layer is disabled.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])


func test_loader_visible_hidden_by_a_parents_ready_stays_off() -> void:
	# Given: A loader active while visible, whose parent hides it as it becomes ready.
	var parent := Control.new()
	parent.ready.connect(parent.hide)
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE)
	parent.add_child(loader)

	# When: Both enter the tree.
	add_child_autofree(parent)
	await wait_idle_frames(1)

	# Then: The layer is not enabled.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])


func test_loader_visible_entering_visible_waits_for_the_set() -> void:
	# Given: A map's loader with the set and no layers.
	var map := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	map.action_set_layers = [] as Array[StdInputActionSetLayer]

	# Given: A visible panel whose loader has only the layer.
	var panel := Control.new()
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE)
	loader.action_set = null
	panel.add_child(loader)

	# When: Both enter the tree, the map's loader first.
	add_child_autofree(map)
	add_child_autofree(panel)

	# Then: Nothing is enabled before the frame ends.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: The set is loaded and the layer enabled over it.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_visible_reentering_waits_for_the_end_of_the_frame() -> void:
	# Given: A visible panel whose loader has synced.
	var panel := Control.new()
	panel.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))
	add_child_autofree(panel)
	await wait_idle_frames(1)

	# When: The panel leaves the tree and enters it again.
	remove_child(panel)
	add_child(panel)

	# Then: Nothing is enabled before the frame ends.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: The layer is enabled.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_visible_under_a_window_follows_the_window() -> void:
	# Given: A window under a visible host control.
	var host := Control.new()
	add_child_autofree(host)
	var window := Window.new()
	host.add_child(window)

	# Given: A loader active while visible, in the window.
	window.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))

	# Given: A control beside the loader, whose visibility is the engine's answer.
	var probe := Control.new()
	window.add_child(probe)
	await wait_idle_frames(1)

	# Then: The layer is enabled.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: The window is hidden.
	window.hide()

	# Then: The layer is disabled, as the control beside the loader is hidden.
	assert_false(probe.is_visible_in_tree())
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The window is shown and the host hidden.
	window.show()
	host.hide()

	# Then: The layer is enabled, as the control beside the loader is visible.
	assert_true(probe.is_visible_in_tree())
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_visible_under_a_canvas_layer_follows_the_layer() -> void:
	# Given: A canvas layer under a visible host control.
	var host := Control.new()
	add_child_autofree(host)
	var layer := CanvasLayer.new()
	host.add_child(layer)

	# Given: A loader active while visible, in the canvas layer.
	layer.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))

	# Given: A control beside the loader, whose visibility is the engine's answer.
	var probe := Control.new()
	layer.add_child(probe)
	await wait_idle_frames(1)

	# Then: The action set layer is enabled.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: The canvas layer is hidden.
	layer.hide()

	# Then: The action set layer is disabled, as the control beside the loader is hidden.
	assert_false(probe.is_visible_in_tree())
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])

	# When: The canvas layer is shown and the host hidden.
	layer.show()
	host.hide()

	# Then: The action set layer is enabled, as the control beside the loader is visible.
	assert_true(probe.is_visible_in_tree())
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_visible_under_a_sub_viewport_holds() -> void:
	# Given: A sub viewport under a hidden host control.
	var host := Control.new()
	host.hide()
	add_child_autofree(host)
	var viewport := SubViewport.new()
	host.add_child(viewport)

	# Given: A loader active while visible, in the sub viewport.
	viewport.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))

	# Given: A control beside the loader, whose visibility is the engine's answer.
	var probe := Control.new()
	viewport.add_child(probe)
	await wait_idle_frames(1)

	# Then: The layer is enabled, as the control beside the loader is visible.
	assert_true(probe.is_visible_in_tree())
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_never_touches_nothing_and_needs_no_slot() -> void:
	# Given: No input slot in the tree, and a loader that is never active.
	_slot.queue_free()
	await wait_idle_frames(1)
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.NEVER)

	# When: It enters, is covered, uncovered, and leaves the tree.
	add_child_autofree(loader)
	await wait_idle_frames(1)
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	loader.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(loader)

	# Then: Nothing failed, and the loader still holds its sets.
	assert_eq(loader.action_set, _action_set)
	assert_eq(loader.action_set_layers, [_layer] as Array[StdInputActionSetLayer])


func test_loader_shares_a_layer_with_another_loader() -> void:
	# Given: Two loaders in the tree enabling the same layer.
	var first := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	var second := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	add_child_autofree(first)
	add_child_autofree(second)
	await wait_idle_frames(1)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: One leaves the tree.
	remove_child(first)

	# Then: The layer stays enabled for the other.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])

	# When: The other leaves too.
	remove_child(second)

	# Then: The layer is disabled.
	assert_eq(_slot.list_action_set_layers(), [] as Array[StdInputActionSetLayer])


func test_loader_restores_its_layer_through_a_pop() -> void:
	# Given: A map's loader enables the layer over its own set.
	var map := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	add_child_autofree(map)
	await wait_idle_frames(1)

	# Given: A pause menu covers the map, loading its own set and layer.
	map.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	pause.action_set_layers = (
		[_make_layer(&"PauseMenu", _menu)] as Array[StdInputActionSetLayer]
	)
	add_child_autofree(pause)
	await wait_idle_frames(1)

	# When: The pop uncovers the map before the pause menu leaves the tree.
	map.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)

	# Then: The map's set is loaded and the layer is still enabled.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_keeps_a_shared_layer_under_a_screen_with_the_same_sets() -> void:
	# Given: A pause menu's loader enables the layer over its set.
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	add_child_autofree(pause)
	await wait_idle_frames(1)

	# Given: A settings menu with the same set and layer covers it.
	var settings := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	add_child_autofree(settings)
	pause.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	await wait_idle_frames(1)

	# When: The pop uncovers the pause menu before the settings menu leaves the tree.
	pause.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(settings)

	# Then: The layer is still enabled.
	assert_eq(_slot.list_action_set_layers(), [_layer] as Array[StdInputActionSetLayer])


func test_loader_under_a_container_takes_no_slot_and_covers_no_sibling() -> void:
	# Given: A box container holding a button.
	var scene := Control.new()
	var box := VBoxContainer.new()
	scene.add_child(box)
	box.add_child(Button.new())

	# Given: A panel container holding another button, below the box.
	var panel := PanelContainer.new()
	panel.position = Vector2(0, 100)
	scene.add_child(panel)
	var button := Button.new()
	button.custom_minimum_size = Vector2(100, 40)
	panel.add_child(button)

	# Given: The scene is mounted and laid out.
	var input := await StdTestInput.mount(self, scene)
	var minimum := box.get_combined_minimum_size()

	# When: A loader enters each container beside its button.
	box.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))
	panel.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE))
	await wait_idle_frames(1)

	# Then: The box's minimum size is unchanged.
	assert_eq(box.get_combined_minimum_size(), minimum)

	# When: The panel's button is clicked.
	watch_signals(button)
	input.click(button)

	# Then: The click reaches it.
	assert_signal_emitted(button, "pressed")


func test_loader_panel_opening_and_closing_swaps_the_set_and_layers() -> void:
	# Given: A scene with a map's loaders and a hidden panel after them, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	var panel := _make_panel()
	scene.add_child(panel)
	add_child_autofree(scene)
	await wait_idle_frames(1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)

	# When: The panel opens.
	panel.show()

	# Then: The slot holds `Menu` and the panel's layer.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [_panel_layer] as Array[StdInputActionSetLayer]
	)

	# When: The panel closes.
	panel.hide()

	# Then: The slot holds the game's set and the map's layers in tree order.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_panel_closed_while_covered_leaves_the_screen_above_alone() -> void:
	# Given: A scene with a map's loaders and an open panel, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	var panel := _make_panel()
	scene.add_child(panel)
	add_child_autofree(scene)
	await wait_idle_frames(1)
	panel.show()

	# Given: A pause menu holding `Menu` and its own layer covers the scene.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	var pause_layer := _make_layer(&"PauseMenu", _menu)
	pause.action_set_layers = [pause_layer] as Array[StdInputActionSetLayer]
	add_child_autofree(pause)
	await wait_idle_frames(1)
	assert_eq(
		_slot.list_action_set_layers(), [pause_layer] as Array[StdInputActionSetLayer]
	)

	# When: The panel closes while covered.
	panel.hide()
	await wait_idle_frames(1)

	# Then: The pause menu's set and layer stay as they were.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [pause_layer] as Array[StdInputActionSetLayer]
	)

	# When: The pause menu is popped.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)
	await wait_idle_frames(1)

	# Then: The slot holds the game's set and the map's layers.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_panel_left_open_under_a_screen_returns_to_the_top_on_uncover() -> void:
	# Given: A scene with a map's loaders and an open panel, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	var panel := _make_panel()
	scene.add_child(panel)
	add_child_autofree(scene)
	await wait_idle_frames(1)
	panel.show()

	# Given: A pause menu holding `Menu` covers the scene.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	pause.action_set_layers = (
		[_make_layer(&"PauseMenu", _menu)] as Array[StdInputActionSetLayer]
	)
	add_child_autofree(pause)
	await wait_idle_frames(1)

	# When: The pause menu is popped.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)

	# Then: The map's loaders have synced before the frame ends.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: The panel's set and layer are back on top.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [_panel_layer] as Array[StdInputActionSetLayer]
	)

	# When: The panel closes.
	panel.hide()

	# Then: The slot holds the game's set and the map's layers.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_panel_freed_while_open_returns_the_maps_set_and_layers() -> void:
	# Given: A scene with a map's loaders and an open panel, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	var panel := _make_panel()
	scene.add_child(panel)
	add_child_autofree(scene)
	await wait_idle_frames(1)
	panel.show()
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)

	# When: The panel is freed while open.
	panel.queue_free()
	await wait_idle_frames(1)

	# Then: The slot holds the game's set and the map's layers.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_panel_before_the_map_in_the_tree_still_lands_above_it() -> void:
	# Given: A scene with an open panel before a map's loaders.
	var scene := Node.new()
	var panel := _make_panel()
	panel.show()
	scene.add_child(panel)
	scene.add_child(_make_map())

	# When: The scene enters the tree and the frame ends.
	add_child_autofree(scene)
	await wait_idle_frames(1)

	# Then: The slot holds `Menu` and the panel's layer.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [_panel_layer] as Array[StdInputActionSetLayer]
	)

	# Given: A pause menu holding `Menu` covers the scene.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	pause.action_set_layers = (
		[_make_layer(&"PauseMenu", _menu)] as Array[StdInputActionSetLayer]
	)
	add_child_autofree(pause)
	await wait_idle_frames(1)

	# When: The pause menu is popped.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)
	await wait_idle_frames(1)

	# Then: The slot holds `Menu` and the panel's layer again.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [_panel_layer] as Array[StdInputActionSetLayer]
	)

	# When: The panel closes.
	panel.hide()

	# Then: The slot holds the game's set and the map's layers in tree order.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_covered_with_a_panel_open_reloads_nothing() -> void:
	# Given: A scene with an open panel before a map's loaders, synced.
	var scene := Node.new()
	var panel := _make_panel()
	panel.show()
	scene.add_child(panel)
	scene.add_child(_make_map())
	add_child_autofree(scene)
	await wait_idle_frames(1)

	# Given: A pause menu holding `Menu` and its own layer has entered over it.
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	var pause_layer := _make_layer(&"PauseMenu", _menu)
	pause.action_set_layers = [pause_layer] as Array[StdInputActionSetLayer]
	add_child_autofree(pause)
	await wait_idle_frames(1)
	watch_signals(_slot)

	# When: The pause menu covers the scene.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)

	# Then: The pause menu's set and layer stay, with no set loaded in between.
	assert_signal_not_emitted(_slot, "action_set_loaded")
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	assert_eq(
		_slot.list_action_set_layers(), [pause_layer] as Array[StdInputActionSetLayer]
	)


func test_loader_screen_popped_without_a_panel_restores_the_scene_at_once() -> void:
	# Given: A scene with a map's loaders, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	add_child_autofree(scene)
	await wait_idle_frames(1)

	# Given: A pause menu holding `Menu` and a layer under it covers the scene.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _menu
	pause.action_set_layers = (
		[_make_layer(&"PauseMenu", _menu)] as Array[StdInputActionSetLayer]
	)
	add_child_autofree(pause)
	await wait_idle_frames(1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)

	# When: The pause menu is popped.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(pause)

	# Then: The game's set and the map's layers are back before the frame ends.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: Nothing changes.
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_screen_popped_with_a_panel_open_loads_only_the_scenes_set() -> void:
	# Given: A scene with a map's loaders, synced and covered.
	var scene := Node.new()
	scene.add_child(_make_map())
	add_child_autofree(scene)
	await wait_idle_frames(1)
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)

	# Given: A screen above it whose loader holds its own set, before an open panel.
	var screen := Node.new()
	var driving := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	driving.action_set = _make_action_set(&"Driving")
	driving.action_set_layers = [] as Array[StdInputActionSetLayer]
	screen.add_child(driving)
	var panel := _make_panel()
	screen.add_child(panel)
	add_child_autofree(screen)
	await wait_idle_frames(1)
	panel.show()
	watch_signals(_slot)

	# When: The screen above is popped.
	scene.propagate_notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)
	remove_child(screen)
	await wait_idle_frames(1)

	# Then: Only the game's set is loaded, with the map's layers.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)


func test_loader_branch_leaving_with_a_panel_open_loads_the_remaining_set() -> void:
	# Given: A loader holding its own set and layer, synced.
	var lobby := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	lobby.action_set = _make_action_set(&"Lobby")
	var lobby_layer := _make_layer(&"Lobby", lobby.action_set)
	lobby.action_set_layers = [lobby_layer] as Array[StdInputActionSetLayer]
	add_child_autofree(lobby)

	# Given: A scene after it with a map's loaders and an open panel, synced.
	var scene := Node.new()
	scene.add_child(_make_map())
	var panel := _make_panel()
	scene.add_child(panel)
	add_child_autofree(scene)
	await wait_idle_frames(1)
	panel.show()
	watch_signals(_slot)

	# When: The scene leaves the tree.
	remove_child(scene)

	# Then: Only the remaining loader's set is loaded, with its layer.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), lobby.action_set)
	assert_eq(
		_slot.list_action_set_layers(), [lobby_layer] as Array[StdInputActionSetLayer]
	)


func test_loader_screen_popped_with_a_panel_open_loads_the_set_below_once() -> void:
	# Given: A screen stack, which uses the slot's cursor.
	var manager := StdTestScreenManager.new()
	add_child_autofree(manager)

	# Given: A scene with a map's loaders, pushed.
	var scene := Node.new()
	scene.add_child(_make_map())
	await manager.push_and_wait(StdScreen.new(), scene)

	# Given: A pause menu holding `Menu`, with an open panel after it, pushed over it.
	var pause := Node.new()
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	loader.action_set = _menu
	var pause_layer := _make_layer(&"PauseMenu", _menu)
	loader.action_set_layers = [pause_layer] as Array[StdInputActionSetLayer]
	pause.add_child(loader)
	var panel := _make_panel()
	panel.show()
	pause.add_child(panel)
	await manager.push_and_wait(StdScreen.new(), pause)
	assert_eq(
		_slot.list_action_set_layers(),
		[pause_layer, _panel_layer] as Array[StdInputActionSetLayer],
	)
	watch_signals(_slot)

	# When: The pause menu is popped.
	manager.pop()

	# Then: The game's set is loaded once, with the map's layers in tree order.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: No other set has been loaded.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)


func test_loader_screen_popped_with_an_attachment_loads_the_set_below_once() -> void:
	# Given: A screen stack, which uses the slot's cursor.
	var manager := StdTestScreenManager.new()
	add_child_autofree(manager)

	# Given: A scene with a map's loaders, pushed.
	var scene := Node.new()
	scene.add_child(_make_map())
	await manager.push_and_wait(StdScreen.new(), scene)

	# Given: An attachment scene whose loader holds `Menu`.
	var attachment := PackedScene.new()
	var menu := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	menu.action_set = _menu
	menu.action_set_layers = [] as Array[StdInputActionSetLayer]
	attachment.pack(menu)
	menu.free()
	attachment.take_over_path(_TEST_ATTACHMENT_PATH)

	# Given: A screen with that attachment, whose own loader holds its own set, pushed.
	var screen := StdScreen.new()
	screen.attachment_scenes = PackedStringArray([_TEST_ATTACHMENT_PATH])
	var driving := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	driving.action_set = _make_action_set(&"Driving")
	driving.action_set_layers = [] as Array[StdInputActionSetLayer]
	await manager.push_and_wait(screen, driving)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _menu)
	watch_signals(_slot)

	# When: The screen is popped.
	manager.pop()

	# Then: The game's set is loaded once, with the map's layers in tree order.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)
	assert_eq(_slot.actions.get_action_set(_slot.device_id), _action_set)
	assert_eq(
		_slot.list_action_set_layers(),
		[_layer, _build_layer] as Array[StdInputActionSetLayer],
	)

	# When: The frame ends.
	await wait_idle_frames(1)

	# Then: No other set has been loaded.
	assert_signal_emit_count(_slot, "action_set_loaded", 1)

	attachment.take_over_path("")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_action_set = _make_action_set(&"Gameplay")
	_layer = _make_layer(&"Options", _action_set)
	_menu = _make_action_set(&"Menu")
	_build_layer = _make_layer(&"Build", _action_set)
	_panel_layer = _make_layer(&"Pause", _menu)

	_slot = SlotTest.make_slot()
	add_child_autofree(_slot)
	autofree(_slot.get_active_device())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_action_set returns an empty action set called `id`.
func _make_action_set(id: StringName) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	return action_set


## _make_layer returns an empty action set layer called `id` under `parent`.
func _make_layer(id: StringName, parent: StdInputActionSet) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	return layer


## _make_loader returns a loader for the test's set and layer under `rule`, not yet in
## the tree.
func _make_loader(
	rule: StdInputActionSetLoader.ActiveWhile,
) -> StdInputActionSetLoader:
	var loader := StdInputActionSetLoader.new()
	loader.active_while = rule
	loader.action_set = _action_set
	loader.action_set_layers = [_layer] as Array[StdInputActionSetLayer]
	return loader


## _make_map returns a node holding a map's two plain loaders, the first with the game's
## set and the `Options` layer and the second with only the `Build` layer, not yet in
## the tree.
func _make_map() -> Node:
	var map := Node.new()
	map.add_child(_make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE))
	var build := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	build.action_set = null
	build.action_set_layers = [_build_layer] as Array[StdInputActionSetLayer]
	map.add_child(build)
	return map


## _make_panel returns a hidden control whose loader holds `Menu` and the `Pause` layer
## while the control is visible, not yet in the tree.
func _make_panel() -> Control:
	var panel := Control.new()
	panel.hide()
	var loader := _make_loader(StdInputActionSetLoader.ActiveWhile.VISIBLE)
	loader.action_set = _menu
	loader.action_set_layers = [_panel_layer] as Array[StdInputActionSetLayer]
	panel.add_child(loader)
	return panel
