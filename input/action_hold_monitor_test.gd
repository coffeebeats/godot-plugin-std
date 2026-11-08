# gdlint:ignore=max-public-methods
##
## std/input/action_hold_monitor_test.gd
##
## Tests pertaining to the `StdInputActionHoldMonitor` class, driven through a real slot
## by events and simulated time.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SlotTest := preload("slot_test.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _ACTION is the action the monitor reports.
const _ACTION := &"probe_monitor"

## _ACTION_OTHER is an action declared beside `_ACTION`.
const _ACTION_OTHER := &"probe_monitor_other"

## _ACTIONS lists every action this file defines.
const _ACTIONS: Array[StringName] = [_ACTION, _ACTION_OTHER]

## _DURATION is the `duration` of each hold, in seconds.
const _DURATION := 1.0

const MODE_HOLD := StdInputActionHold.MODE_HOLD
const MODE_INHERIT := StdInputActionHold.MODE_INHERIT
const MODE_TOGGLE := StdInputActionHold.MODE_TOGGLE

# -- INITIALIZATION ------------------------------------------------------------------ #

var hold_mode: StdSettingsPropertyInt = null
var input: StdTestInput = null
var monitor: StdInputActionHoldMonitor = null
var slot: StdInputSlot = null

# -- TEST METHODS -------------------------------------------------------------------- #

# Mode


func test_monitor_action_that_is_no_hold_reads_inherit() -> void:
	# Given: A set declaring no hold on the monitored action.
	await _mount(_make_set([]))

	# Then: The monitor reports no hold.
	assert_eq(monitor.get_mode(), MODE_INHERIT)
	assert_false(monitor.is_toggle_running())
	assert_eq(monitor.get_progress(), 0.0)


func test_monitor_reads_the_holds_own_mode() -> void:
	# Given: A set declaring a toggle on the monitored action.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Then: The monitor reports the toggle, with nothing running.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_false(monitor.is_toggle_running())


func test_monitor_mode_change_while_idle_through_the_slots_property_is_heard() -> void:
	# Given: A set declaring a hold, with nothing running.
	await _mount(_make_set([_make_hold(MODE_HOLD)]))

	# When: The player chooses the toggle for every hold.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The monitor reports the toggle once, though the slot signals nothing.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_signal_emit_count(monitor, "changed", 1)


func test_monitor_mode_change_while_idle_through_a_mode_override_is_heard() -> void:
	# Given: A hold with a mode override.
	var hold := _make_hold(MODE_HOLD)
	hold.mode_override = _make_mode_property(&"override")

	# Given: A set declaring it, with nothing running.
	await _mount(_make_set([hold]))

	# When: The player chooses the toggle for this hold's group.
	hold.mode_override.set_value(MODE_TOGGLE)

	# Then: The monitor reports the toggle once.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_signal_emit_count(monitor, "changed", 1)


func test_monitor_property_assigned_after_mount_is_heard() -> void:
	# Given: A set declaring a hold, with nothing running.
	await _mount(_make_set([_make_hold(MODE_HOLD)]))

	# Given: A script replaces the slot's property, as an ancestor's `_ready` does.
	var late := _make_mode_property(&"late")
	slot.hold_mode_property = late

	# When: The player chooses the toggle for every hold on the new property.
	late.set_value(MODE_TOGGLE)

	# Then: The monitor reports the toggle once.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_signal_emit_count(monitor, "changed", 1)


func test_monitor_property_of_a_dropped_hold_is_no_longer_heard() -> void:
	# Given: A set declaring a hold.
	await _mount(_make_set([_make_hold(MODE_HOLD)]))

	# Given: A set without the hold replaced it.
	slot.load_action_set(_make_set([]))
	assert_eq(monitor.get_mode(), MODE_INHERIT, "precondition")
	var emitted: int = get_signal_emit_count(monitor, "changed")

	# When: The player changes the mode for every hold.
	hold_mode.set_value(MODE_TOGGLE)

	# Then: The monitor still reports no hold, and emits nothing more.
	assert_eq(monitor.get_mode(), MODE_INHERIT)
	assert_signal_emit_count(monitor, "changed", emitted)


func test_monitor_set_change_declaring_a_hold_is_heard() -> void:
	# Given: A set declaring no hold on the monitored action.
	await _mount(_make_set([]))

	# When: A set declaring a toggle on it is loaded.
	slot.load_action_set(_make_set([_make_hold(MODE_TOGGLE)]))

	# Then: The monitor reports the toggle.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_signal_emit_count(monitor, "changed", 1)


# Progress


func test_monitor_hold_reports_its_progress() -> void:
	# Given: A set declaring a hold.
	await _mount(_make_set([_make_hold(MODE_HOLD)]))

	# When: The action is held for half the duration.
	input.press_action(_ACTION)
	await _elapse(_DURATION * 0.5)

	# Then: The monitor reports the slot's progress, with no toggle running.
	assert_almost_eq(monitor.get_progress(), 0.5, 0.2)
	assert_eq(monitor.get_progress(), slot.get_action_hold_progress(_ACTION))
	assert_false(monitor.is_toggle_running())

	# When: The action is released.
	input.release_action(_ACTION)

	# Then: The progress drops to none.
	assert_eq(monitor.get_progress(), 0.0)


func test_monitor_ignores_another_actions_hold() -> void:
	# Given: A set declaring holds on the monitored action and another.
	await _mount(
		_make_set([_make_hold(MODE_TOGGLE), _make_hold(MODE_TOGGLE, _ACTION_OTHER)])
	)

	# When: The other action is tapped.
	input.press_action(_ACTION_OTHER)
	input.release_action(_ACTION_OTHER)

	# Then: The monitor emits nothing.
	assert_signal_emit_count(monitor, "changed", 0)
	assert_false(monitor.is_toggle_running())


# Tapped toggles


func test_monitor_tapped_toggle_runs_until_it_fills() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The monitor reports the toggle running.
	assert_true(monitor.is_toggle_running())

	# When: The duration passes.
	await _elapse(_DURATION)

	# Then: The toggle has ended, with its progress dropped.
	assert_signal_emit_count(slot, "action_hold_triggered", 1, "precondition")
	assert_false(monitor.is_toggle_running())
	assert_eq(monitor.get_progress(), 0.0)
	assert_eq(monitor.get_mode(), MODE_TOGGLE)


func test_monitor_tapped_toggle_ends_on_a_second_tap() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION * 0.5)

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: The toggle has ended, with its progress dropped.
	assert_signal_emit_count(slot, "action_hold_cancelled", 1, "precondition")
	assert_false(monitor.is_toggle_running())
	assert_eq(monitor.get_progress(), 0.0)


func test_monitor_tapped_toggle_ends_when_the_app_loses_focus() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The app loses focus.
	slot.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)

	# Then: The toggle has ended.
	assert_false(monitor.is_toggle_running())


func test_monitor_tapped_toggle_ends_when_a_set_change_drops_it() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: A set without the hold is loaded.
	slot.load_action_set(_make_set([]))

	# Then: The toggle has ended, and the action is no hold.
	assert_false(monitor.is_toggle_running())
	assert_eq(monitor.get_mode(), MODE_INHERIT)


func test_monitor_tapped_toggle_ends_when_a_setting_change_alters_it() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The player chooses to hold every hold.
	hold_mode.set_value(MODE_HOLD)

	# Then: The toggle has ended, and the hold runs held.
	assert_false(monitor.is_toggle_running())
	assert_eq(monitor.get_mode(), MODE_HOLD)


func test_monitor_action_change_reads_a_toggle_already_running() -> void:
	# Given: A set declaring a toggle, with the monitor on another action.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))
	monitor.action = _ACTION_OTHER

	# Given: The toggle was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The monitor is moved to the toggle's action.
	monitor.action = _ACTION

	# Then: It reports the toggle running.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_true(monitor.is_toggle_running())


# Binding


func test_monitor_placed_before_its_slot_is_bound() -> void:
	# Given: A monitor mounted before its slot, with a set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]), true)

	# Then: The monitor reports the slot's hold.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)


func test_monitor_branch_returning_to_the_tree_binds_a_slot_placed_after_it() -> void:
	# Given: A monitor mounted before its slot, with a set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]), true)

	# When: The branch holding both leaves the tree and returns.
	var branch := monitor.get_parent()
	var host := branch.get_parent()
	host.remove_child(branch)
	host.add_child(branch)

	# Then: The monitor reports the slot's hold.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)

	# When: The action is tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# Then: The monitor hears the toggle run.
	assert_true(monitor.is_toggle_running())


func test_monitor_player_with_no_slot_reads_inherit() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# When: The monitor is moved to a player with no slot.
	monitor.player_id = 2

	# Then: It reports no hold.
	assert_eq(monitor.get_mode(), MODE_INHERIT)

	# When: It's moved back.
	monitor.player_id = 1

	# Then: It reports the slot's hold again.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)


func test_monitor_leaving_the_tree_stops_listening_until_it_returns() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)
	await _elapse(_DURATION * 0.5)

	# When: The monitor leaves the tree.
	var parent := monitor.get_parent()
	parent.remove_child(monitor)

	# Then: It reports no hold.
	assert_eq(monitor.get_mode(), MODE_INHERIT)
	assert_false(monitor.is_toggle_running())

	# When: The toggle fills further while the monitor is out.
	var emitted: int = get_signal_emit_count(monitor, "changed")
	await _elapse(_DURATION * 0.25)

	# Then: The monitor emits nothing more.
	assert_signal_emit_count(monitor, "changed", emitted)

	# When: The monitor returns to the tree.
	parent.add_child(monitor)

	# Then: It reports the toggle running again.
	assert_eq(monitor.get_mode(), MODE_TOGGLE)
	assert_true(monitor.is_toggle_running())

	# When: The action is tapped again.
	input.press_action(_ACTION)

	# Then: The monitor hears the toggle end.
	assert_false(monitor.is_toggle_running())


func test_monitor_slot_leaving_the_tree_reads_inherit() -> void:
	# Given: A set declaring a toggle.
	await _mount(_make_set([_make_hold(MODE_TOGGLE)]))

	# Given: The action was tapped.
	input.press_action(_ACTION)
	input.release_action(_ACTION)

	# When: The slot leaves the tree.
	slot.get_parent().remove_child(slot)
	autofree(slot)

	# Then: The monitor reports no hold.
	assert_eq(monitor.get_mode(), MODE_INHERIT)
	assert_false(monitor.is_toggle_running())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_all() -> void:
	for action in _ACTIONS:
		InputMap.erase_action(action)


func after_each() -> void:
	# NOTE: `Input` outlives each test, so a press left down would carry into the next.
	for action in _ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func before_all() -> void:
	for action in _ACTIONS:
		InputMap.add_action(action, 0.5)


func before_each() -> void:
	hold_mode = _make_mode_property(&"mode")

	slot = SlotTest.make_slot()
	slot.hold_mode_property = hold_mode

	monitor = StdInputActionHoldMonitor.new()
	monitor.action = _ACTION


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _elapse makes `seconds` pass for each running hold and lets a frame report it.
func _elapse(seconds: float) -> void:
	for gesture in slot._gestures._gestures.values():
		gesture.started_usec -= int(seconds * 1_000_000)

	await wait_process_frames(1)


## _make_hold returns a new hold on `action`.
func _make_hold(
	mode: StdInputActionHold.Mode, action: StringName = _ACTION
) -> StdInputActionHold:
	var hold := StdInputActionHold.new()
	hold.action = action
	hold.duration = _DURATION
	hold.mode = mode
	return hold


## _make_mode_property returns a new property at `MODE_INHERIT` in a scope of its own.
func _make_mode_property(property_name: StringName) -> StdSettingsPropertyInt:
	var property := StdSettingsPropertyInt.new()
	property.category = &"probe"
	property.name = property_name
	property.scope = StdSettingsScope.new()
	return property


## _make_set returns a new set declaring every action in this file and `holds`.
func _make_set(holds: Array[StdInputActionHold]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = &"Probe"
	action_set.actions_digital = _ACTIONS
	action_set.holds = holds
	return action_set


## _mount adds the slot and the monitor under one parent, the monitor first when
## `monitor_first`, loads `action_set`, and watches both nodes' signals.
func _mount(action_set: StdInputActionSet, monitor_first: bool = false) -> void:
	var parent := Node.new()
	for node: Node in [monitor, slot] if monitor_first else [slot, monitor]:
		parent.add_child(node)

	input = await StdTestInput.mount(self, parent)
	autofree(slot.get_active_device())

	slot.load_action_set(action_set)

	watch_signals(monitor)
	watch_signals(slot)
