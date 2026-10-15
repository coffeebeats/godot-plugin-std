##
## std/input/loader_test.gd
##
## Tests pertaining to `StdInputActionSetLoader`.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## _DeviceActions is a device actions component that holds whatever it is handed.
class _DeviceActions:
	extends StdInputDeviceActions

	var action_set: StdInputActionSet = null
	var layers: Array[StdInputActionSetLayer] = []

	func _get_action_set(_device: int) -> StdInputActionSet:
		return action_set

	func _load_action_set(_device: int, next: StdInputActionSet) -> bool:
		if next == action_set:
			return false
		action_set = next
		layers = []
		return true

	func _disable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
		if layer not in layers:
			return false
		layers.erase(layer)
		return true

	func _enable_action_set_layer(_device: int, layer: StdInputActionSetLayer) -> bool:
		if layer in layers:
			return false
		layers.append(layer)
		return true

	func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
		return layers.duplicate()


## _JoypadMonitor is a joypad monitor that reports no joypads.
class _JoypadMonitor:
	extends StdInputSlot.JoypadMonitor

	func _broadcast_connected_joypads() -> void:
		pass


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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_action_set = _make_action_set(&"Gameplay")
	_layer = StdInputActionSetLayer.new()
	_layer.name = &"Options"

	_slot = StdInputSlot.new()
	_slot.player_id = 1
	_slot.haptics_disabled_property = StdSettingsPropertyBool.new()
	_slot.haptics_strength_property = StdSettingsPropertyFloatRange.new()

	_slot.joypad_monitor = _JoypadMonitor.new()
	_slot.add_child(_slot.joypad_monitor)

	_slot.cursor = StdInputCursor.new()
	_slot.add_child(_slot.cursor)

	_slot.actions_kbm = add_child_autofree(_DeviceActions.new())
	_slot.glyphs_kbm = add_child_autofree(StdInputDeviceGlyphs.new())
	_slot.haptics_kbm = add_child_autofree(StdInputDeviceHaptics.new())

	_slot.actions_joy = add_child_autofree(_DeviceActions.new())
	_slot.glyphs_joy = add_child_autofree(StdInputDeviceGlyphs.new())
	_slot.haptics_joy = add_child_autofree(StdInputDeviceHaptics.new())

	add_child_autofree(_slot)
	autofree(_slot.get_active_device())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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
