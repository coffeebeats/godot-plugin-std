##
## std/input/loader_test.gd
##
## Tests pertaining to `StdInputActionSetLoader`.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _slot: StdInputSlot = null
var _action_set: StdInputActionSet = null
var _layer: StdInputActionSetLayer = null

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


func test_loader_keeps_a_shared_layer_through_a_pop() -> void:
	# Given: A map's loader enables the layer over its own set.
	var map := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	add_child_autofree(map)
	await wait_idle_frames(1)

	# Given: A pause menu covers the map, loading its own set and the same layer.
	map.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)
	var pause := _make_loader(StdInputActionSetLoader.ActiveWhile.IN_TREE)
	pause.action_set = _make_action_set(&"Menu")
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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_action_set = _make_action_set(&"Gameplay")
	_layer = StdInputActionSetLayer.new()
	_layer.name = &"Options"

	_slot = SlotTest.make_slot()
	add_child_autofree(_slot)
	autofree(_slot.get_active_device())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _make_action_set returns an empty action set called `id`.
func _make_action_set(id: StringName) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	return action_set


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
