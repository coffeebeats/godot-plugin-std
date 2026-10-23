##
## std/input/steam/device_actions.gd
##
## StdInputSteamDeviceActions is an implemention of `StdInputDeviceActions` which uses
## the Steam Input API to manage action sets.
##
## NOTE: This implementation requires that all action sets/bindings apply to all input
## devices. Changing action sets for one device thus changes them for all devices.

extends StdInputDeviceActions

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MotionFilter := preload("../motion_filter.gd")
const Signals := preload("../../event/signal.gd")
const SteamJoypadMonitor := preload("joypad_monitor.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := Steam.INPUT_HANDLE_ALL_CONTROLLERS

## _STICK_DEADZONE is the `InputMap` deadzone of a stick's directions while Steam Input
## drives the stick, since Steam reports it past the deadzone its configurator sets.
##
## NOTE: It stays above `0`, at which Godot reads a native axis at rest as pressed.
const _STICK_DEADZONE := 0.00001

# -- CONFIGURATION ------------------------------------------------------------------- #

## joypad_monitor is a Steam-specific joypad monitor, used to look up slot-to-device ID
## translations.
@export var joypad_monitor: StdInputSlot.JoypadMonitor = null

## steam_input_enabled_property is a settings property that the joypad monitor will
## toggle based on connected controller activity.
##
## NOTE: It unfortunately seems that the only way to check for whether Steam Input is in
## use is by the presence of a connected joypad. As such, this property will be enabled
## when devices are connected and disabled otherwise.
@export var steam_input_enabled_property: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

## _action_set_handles is a reverse mapping from action set names to action set handles.
static var _action_set_handles: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _actions_sets is a mapping from action set handles to `StdInputActionSet`; this
## includes action set layers too.
static var _action_sets: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _actions is a mapping from action handles to action names.
static var _actions: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _action_handles is a reverse mapping from action names to action handles.
static var _action_handles: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _actions_seen_action_sets is the list of action sets which already have their action
## handles populated. This is used to skip duplicate work.
##
## NOTE: Because the number of action sets should be small, an array is preferred.
static var _actions_seen_action_sets: Array[StdInputActionSet] = []  # gdlint:ignore=class-definitions-order,max-line-length

## _is_initialized tracks whether this component has been initialized. This needs to
## occur once *after the first joypad has been connected*.
static var _is_initialized: bool = false  # gdlint:ignore=class-definitions-order

## _stick_deadzones maps each stick direction whose deadzone Steam Input took over to
## the `InputMap` deadzone it had before, which is restored once Steam Input stops.
static var _stick_deadzones: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _held maps slots to the actions Steam holds pressed on them; each action maps the
## name of every Steam action pressing it to the strength it presses at.
var _held: Dictionary = {}

## _is_listening tracks whether this instance receives Steam Input events; the caches
## above are shared, but each instance connects to the signals itself.
var _is_listening: bool = false

var _logger := StdLogger.create("std/input/steam/device-actions")

## _pointer_motion maps slots to the filter which decides when that slot's "absolute
## mouse" motion counts as joypad activity.
var _pointer_motion: Dictionary = {}

## _warp_remainder is the sub-pixel pointer motion not yet applied by a warp, which the
## window system only accepts in whole pixels.
var _warp_remainder := Vector2.ZERO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_action_set_handle returns the handle for the specified action set, fetching it
## from the Steam Input API if it hasn't yet been loaded.
static func get_action_set_handle(id: StringName) -> int:
	assert(_is_initialized, "invalid state; Steam Input not initialized")

	var handle: int = _action_set_handles.get(id, 0)
	if not handle:
		handle = Steam.getActionSetHandle(id)

	if not handle:
		return 0

	_action_set_handles[id] = handle

	return handle


## get_analog_action_handle returns the handle for the specified analog action,
## fetching it from the Steam Input API if it hasn't yet been loaded.
static func get_analog_action_handle(action: StringName) -> int:
	assert(_is_initialized, "invalid state; Steam Input not initialized")

	var handle: int = _action_handles.get(action, 0)
	if not handle:
		handle = Steam.getAnalogActionHandle(action)

	if not handle:
		return 0

	_actions[handle] = action
	_action_handles[action] = handle

	return handle


## get_digital_action_handle returns the handle for the specified digital action,
## fetching it from the Steam Input API if it hasn't yet been loaded.
static func get_digital_action_handle(action: StringName) -> int:
	assert(_is_initialized, "invalid state; Steam Input not initialized")

	var handle: int = _action_handles.get(action, 0)
	if not handle:
		handle = Steam.getDigitalActionHandle(action)

	if not handle:
		return 0

	_actions[handle] = action
	_action_handles[action] = handle

	return handle


## resolve_action_set_name returns the name the Steam Input manifest knows `action_set`
## by on `device`. A layer with no parent resolves to its `<Layer>_<Set>` copy under the
## device's current set; anything else keeps its own name.
static func resolve_action_set_name(
	action_set: StdInputActionSet, device: int
) -> StringName:
	if not action_set is StdInputActionSetLayer or action_set.parent:
		return action_set.name

	var current: StdInputActionSet = _action_sets.get(Steam.getCurrentActionSet(device))
	if not current:
		return action_set.name

	return StringName("%s_%s" % [action_set.name, current.name])


## split_analog_2d returns the four directional action events a stick's `motion` drives
## for the 2D analog `action`, in `StdInputActionSet.ANALOG_2D_DIRECTIONS` order, each
## at the strength of its half of the axis and pressed at any strength. Godot clamps an
## action's strength to `[0, 1]`, so a signed axis can't travel on one action.
##
## NOTE: Steam reports a stick's `y` as positive upward, so `+y` drives `_up`.
static func split_analog_2d(
	action: StringName,
	motion: Vector2,
	slot: int,
) -> Array[InputEventAction]:
	var events: Array[InputEventAction] = []

	var names := StdInputActionSet.list_analog_2d_actions(action)
	var strengths: Array[float] = [
		maxf(-motion.x, 0.0),
		maxf(motion.x, 0.0),
		maxf(motion.y, 0.0),
		maxf(-motion.y, 0.0),
	]

	for i in names.size():
		var event := InputEventAction.new()
		event.action = names[i]
		event.device = slot
		event.strength = strengths[i]
		event.pressed = event.strength > 0.0

		events.append(event)

	return events


## is_action_set_enabled returns whether the provided name refers to an active action
## set or action set layer.
func is_action_set_enabled(slot: int, action_set_name: String) -> bool:
	assert(_is_initialized, "invalid state; Steam Input not initialized")

	var action_set := _get_action_set(slot)
	if not action_set:
		return false

	if action_set.name == action_set_name:
		return true

	for layer in _list_action_set_layers(slot):
		if layer.name == action_set_name:
			return true

	return false


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(joypad_monitor is SteamJoypadMonitor, "invalid state; missing node")
	assert(
		steam_input_enabled_property is StdSettingsPropertyBool,
		"invalid state; missing property",
	)

	Signals.connect_safe(joypad_monitor.joy_disconnected, _on_joypad_disconnected)

	if steam_input_enabled_property.get_value():
		_on_steam_input_state_changed(true)

	Signals.connect_safe(
		steam_input_enabled_property.value_changed, _on_steam_input_state_changed
	)


func _exit_tree() -> void:
	# NOTE: No release arrives once this stops listening, so every action a joypad holds
	# is released now.
	for slot in _held.keys():
		_on_joypad_disconnected(slot)

	Signals.disconnect_safe(joypad_monitor.joy_disconnected, _on_joypad_disconnected)
	Signals.disconnect_safe(
		steam_input_enabled_property.value_changed, _on_steam_input_state_changed
	)

	if not _is_listening:
		return

	_is_listening = false

	Signals.disconnect_safe(Steam.input_action_event, _on_input_action_event)
	Signals.disconnect_safe(
		Steam.input_configuration_loaded, _on_input_configuration_loaded
	)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## get_action_set returns the currently active `InputActionSet` *for the specified
## device*.
func _get_action_set(slot: int) -> StdInputActionSet:
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return null

	var handle := Steam.getCurrentActionSet(device)
	return _action_sets.get(handle) as StdInputActionSet


## load_action_set unloads the currently active `StdInputActionSet`, if any, and then
## activates the provided action set *for the specified device*. If the action set
## is already active for the device then no change occurs.
func _load_action_set(slot: int, action_set: StdInputActionSet) -> bool:
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(action_set is StdInputActionSet, "missing argument: action set")
	assert(
		not action_set is StdInputActionSetLayer, "invalid argument: cannot use a layer"
	)

	# FIXME: This lookup is required because of the need to return whether the action
	# set was changed. This may be a performance issue, so consider removing.
	if action_set == _get_action_set(slot):
		return false

	var handle := get_action_set_handle(action_set.name)
	if not handle:
		_logger.warn("Steam Input has no such action set.", {&"name": action_set.name})
		return false

	_action_sets[handle] = action_set
	Steam.activateActionSet(DEVICE_ID_ALL, handle)

	# NOTE: Incoming action events only contain the action's handle. In order to look
	# up the corresponding action name, populate the action handles now.
	_store_action_handles(action_set)
	_clear_stick_deadzones(action_set)

	# FIXME: Need to await first input.
	return handle == Steam.getCurrentActionSet(device)


# Action set layers


## enable_action_set_layer pushes the provided action set layer onto the stack of
## active layers *for the specified device*. If the action set layer is already
## active then no change occurs.
func _enable_action_set_layer(slot: int, layer: StdInputActionSetLayer) -> bool:
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(layer is StdInputActionSetLayer, "missing argument: layer")
	assert(
		_get_action_set(slot) is StdInputActionSet,
		"invalid state: missing action set",
	)
	assert(
		layer.parent == null or layer.parent == _get_action_set(slot),
		"invalid argument: wrong parent action set",
	)

	var layer_name := resolve_action_set_name(layer, device)
	var handle := get_action_set_handle(layer_name)
	if not handle:
		_logger.warn("Steam Input has no such action set layer.", {&"name": layer_name})
		return false

	# FIXME: This lookup is required because of the need to return whether the action
	# set layer was changed. This may be a performance issue, so consider removing.
	if handle in Steam.getActiveActionSetLayers(device):
		return false

	_action_sets[handle] = layer
	Steam.activateActionSetLayer(DEVICE_ID_ALL, handle)
	_store_action_handles(layer)
	_clear_stick_deadzones(layer)

	# NOTE: This won't organically return `true` until the next player action input is
	# received by the game. This is an unfortunate discrepancy between the Godot
	# architecture and the Steam one.
	return true


## disable_action_set_layer removes the provided action set layer from the set of
## active layers *for the specified device*. If the action set layer is not active
## then no change occurs.
func _disable_action_set_layer(slot: int, layer: StdInputActionSetLayer) -> bool:
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(layer is StdInputActionSetLayer, "missing argument: layer")

	var handle := get_action_set_handle(resolve_action_set_name(layer, device))
	if not handle:
		return false

	# FIXME: This lookup is required because of the need to return whether the action
	# set layer was changed. This may be a performance issue, so consider removing.
	if handle not in Steam.getActiveActionSetLayers(device):
		return false

	_action_sets[handle] = layer
	Steam.deactivateActionSetLayer(device, handle)

	# NOTE: This won't organically return `true` until the next player action input is
	# received by the game. This is an unfortunate discrepancy between the Godot
	# architecture and the Steam one.
	return true


## list_action_set_layers returns the stack of currently active action set layers
## *for the specified device*.
func _list_action_set_layers(slot: int) -> Array[StdInputActionSetLayer]:
	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return []

	var layers: Array[StdInputActionSetLayer] = []

	for handle in Steam.getActiveActionSetLayers(device):
		var layer: StdInputActionSetLayer = _action_sets.get(handle)
		assert(layer is StdInputActionSetLayer, "invalid state; missing layer")

		layers.append(layer)

	return layers


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _clear_stick_deadzones sets the `InputMap` deadzone of each of `action_set`'s stick
## directions to `_STICK_DEADZONE`, remembering the one it replaces, since Steam reports
## a stick past the deadzone its configurator sets.
##
## NOTE: `Input.get_vector` applies the directions' deadzone even to injected actions.
static func _clear_stick_deadzones(action_set: StdInputActionSet) -> void:
	for stick in action_set.actions_analog_2d:
		for action in StdInputActionSet.list_analog_2d_actions(stick):
			if not InputMap.has_action(action):
				continue

			if action not in _stick_deadzones:
				_stick_deadzones[action] = InputMap.action_get_deadzone(action)

			InputMap.action_set_deadzone(action, _STICK_DEADZONE)


## _get_pointer_motion_filter returns the slot's pointer motion filter, configured from
## the action sets Steam currently reports active for it.
##
## NOTE: The threshold is read on each event rather than when sets change, since Steam
## only reflects a set or layer change once the next input arrives.
func _get_pointer_motion_filter(slot: int) -> MotionFilter:
	var filter: MotionFilter = _pointer_motion.get(slot)
	if not filter:
		filter = MotionFilter.new()
		_pointer_motion[slot] = filter

	var action_sets: Array[StdInputActionSet] = []

	var action_set := get_action_set(slot)
	if action_set:
		action_sets.append(action_set)

	action_sets.append_array(list_action_set_layers(slot))

	filter.configure(action_sets)

	return filter


## _publish_input_event records `event` as the press of its action by the Steam action
## `source`, then parses the action's combined state once it differs from the one last
## published for its slot: pressed while any source presses it, at the strongest one's
## strength, as Godot combines an action's bound events. Parsing presses the action on
## `Input` at that strength, so no explicit press or release is needed; an explicit
## release would also release the action for every other device, such as a key held for
## it.
##
## NOTE: Steam reports a stick on every change, so a direction it keeps reporting as
## released would otherwise read as just released on every event. A layer's stick can
## also drive a direction its parent set binds as a button, so neither source may
## release the other's press.
func _publish_input_event(event: InputEventAction, source: StringName) -> void:
	var sources: Dictionary = _held.get_or_add(event.device, {}).get_or_add(
		event.action, {}
	)

	var was_pressed := not sources.is_empty()
	var previous: float = sources.values().max() if was_pressed else 0.0

	if event.pressed:
		sources[source] = event.strength
	else:
		sources.erase(source)

	event.pressed = not sources.is_empty()
	event.strength = sources.values().max() if event.pressed else 0.0

	if (
		event.pressed == was_pressed
		and (not event.pressed or is_equal_approx(event.strength, previous))
	):
		return

	Input.parse_input_event(event)


## _publish_pointer_motion moves the pointer by `motion`, in pixels, for a Steam analog
## action in a mouse mode. A captured cursor can't move, so the motion is delivered as a
## mouse motion event for mouse-look; otherwise the cursor is warped, and the window
## system echoes a positioned mouse motion event which hover and the cursor's reveal
## logic handle like a real mouse.
##
## NOTE: Godot's Wayland backend can't warp a free pointer, so a Linux export must use
## the X11 driver (Godot's default, and what gamescope presents on Steam Deck), and
## macOS may not echo warps. A set which reads pointer deltas for mouse-look must
## capture the cursor, or the pointer stops at the window edge, as a real mouse does.
func _publish_pointer_motion(motion: Vector2) -> void:
	if DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
		# NOTE: The viewport resolves hover from the event's position and `Input` stores
		# it as the pointer's, so the current position is carried; a zero position would
		# hover whatever control sits at the window origin on every delta. An event's
		# position is in window pixels, which the window's own transform maps back to
		# from the viewport's coordinates under content scaling.
		var window := get_window()
		var pointer := window.get_final_transform() * window.get_mouse_position()

		var event := InputEventMouseMotion.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.position = pointer
		event.global_position = pointer
		event.relative = motion
		event.screen_relative = motion

		Input.parse_input_event(event)
		return

	var position := Vector2(
		DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
	)
	var size := Vector2(DisplayServer.window_get_size())

	# NOTE: A warp lands on a whole pixel, so the fraction it drops is carried to the
	# next motion; otherwise slow motion never moves the pointer and jitter drifts it.
	# The remainder is dropped at a window edge, so it can't build up there.
	var target := position + motion + _warp_remainder
	var warped := target.round()
	var clamped := warped.clamp(Vector2.ZERO, size - Vector2.ONE)
	_warp_remainder = target - warped if clamped == warped else Vector2.ZERO

	Input.warp_mouse(clamped)


## _restore_stick_deadzones restores the `InputMap` deadzone of each stick direction
## `_clear_stick_deadzones` changed, so a native joypad's stick is filtered again.
static func _restore_stick_deadzones() -> void:
	for action in _stick_deadzones:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, _stick_deadzones[action])

	_stick_deadzones.clear()


func _store_action_handles(action_set: StdInputActionSet) -> void:
	if action_set in _actions_seen_action_sets:
		return

	for action in action_set.actions_digital:
		# NOTE: A stick's directional actions have no Steam action of their own; the
		# stick's 2D action publishes them.
		if action_set.get_analog_2d_action(action):
			continue

		var handle := get_digital_action_handle(action)
		if not handle:
			assert(false, "failed to fetch action handle")
			continue

		_actions[handle] = action

	for action in action_set.actions_analog_1d:
		var handle := get_analog_action_handle(action)
		if not handle:
			assert(false, "failed to fetch action handle")
			continue

		_actions[handle] = action

	for action in action_set.actions_analog_2d:
		assert(
			action != action_set.action_absolute_mouse,
			"invalid config; conflicting action type"
		)

		var handle := get_analog_action_handle(action)
		if not handle:
			assert(false, "failed to fetch action handle")
			continue

		_actions[handle] = action

	if action_set.action_absolute_mouse:
		var handle := get_analog_action_handle(action_set.action_absolute_mouse)
		assert(handle, "failed to fetch action handle")
		if handle:
			_actions[handle] = action_set.action_absolute_mouse

	_actions_seen_action_sets.append(action_set)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_input_action_event(
	device: int,
	event_type: Steam.InputActionEventType,
	action_handle: int,
	is_active: bool,
	action_data: Dictionary,
) -> void:
	# Don't emit action events for actions which aren't loaded.
	if not is_active:
		return

	if not action_handle in _actions:
		assert(false, "missing action handle: %d: %s" % [action_handle, action_data])
		return

	var slot: int = joypad_monitor.get_slot_for_device_id(device)
	if slot == -1:
		return

	var action: StringName = _actions[action_handle]

	match event_type:
		Steam.INPUT_ACTION_EVENT_TYPE_ANALOG_ACTION:
			var motion := Vector2(action_data["x"], action_data["y"])

			# NOTE: No event carries the action's handle as its `event_index`, which names
			# one of an action's bound events and is rejected at `32` and above.
			match action_data["mode"]:
				Steam.INPUT_SOURCE_MODE_TRIGGER:
					var event := InputEventAction.new()
					event.action = action
					event.device = slot
					event.strength = motion.x

					# NOTE: Steam rescales a trigger from the deadzone its configurator
					# sets, so any strength is a press.
					event.pressed = event.strength > 0.0

					_publish_input_event(event, action)

				Steam.INPUT_SOURCE_MODE_ABSOLUTE_MOUSE, Steam.INPUT_SOURCE_MODE_RELATIVE_MOUSE:
					_publish_pointer_motion(motion)

					# NOTE: The action is parsed on every motion, since it needn't exist in
					# the `InputMap`; it only marks joypad activity for the slot. It's
					# pressed once motion passes the active sets' cursor reveal threshold,
					# the same filter `StdInputCursor` applies, so gyro wobble from a
					# controller at rest can't switch glyphs away from a mouse in use.
					var event := InputEventAction.new()
					event.action = action
					event.device = slot
					event.strength = 1.0
					event.pressed = _get_pointer_motion_filter(slot).push(motion)

					Input.parse_input_event(event)

				_:
					for event in split_analog_2d(action, motion, slot):
						_publish_input_event(event, action)

		Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION:
			var event := InputEventAction.new()
			event.action = action
			event.device = slot

			event.pressed = action_data["state"]
			event.strength = 1.0 if event.pressed else 0.0

			_publish_input_event(event, action)


func _on_input_configuration_loaded(
	_app_id: int,
	_device_handle: int,
	_config_data: Dictionary,
) -> void:
	# NOTE: Steam loads a configuration once per controller per focus change, which
	# covers a rebind in its configurator.
	bindings_changed.emit()


## _on_joypad_disconnected releases every action the joypad in `slot` was holding, since
## Steam reports nothing further for it, and forgets the slot's held actions.
func _on_joypad_disconnected(slot: int) -> void:
	var held: Dictionary = _held.get(slot, {})

	for action in held:
		if held[action].is_empty():
			continue

		var event := InputEventAction.new()
		event.action = action
		event.device = slot
		event.pressed = false
		event.strength = 0.0

		Input.parse_input_event(event)

	_held.erase(slot)
	_pointer_motion.erase(slot)


func _on_steam_input_state_changed(enabled: bool) -> void:
	if not enabled:
		_restore_stick_deadzones()
		return

	for action_set in _actions_seen_action_sets:
		_clear_stick_deadzones(action_set)

	if _is_listening:
		return

	_is_initialized = true
	_is_listening = true

	Signals.connect_safe(Steam.input_action_event, _on_input_action_event)
	Signals.connect_safe(
		Steam.input_configuration_loaded, _on_input_configuration_loaded
	)
