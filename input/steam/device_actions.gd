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

const Signals := preload("../../event/signal.gd")
const SteamJoypadMonitor := preload("joypad_monitor.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DEVICE_ID_ALL := Steam.INPUT_HANDLE_ALL_CONTROLLERS

# -- CONFIGURATION ------------------------------------------------------------------- #

## in_game_actions is a Steam In-game actions resource which lists all Steam-registered
## action sets.
@export var in_game_actions: StdInputSteamInGameActions = null

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


func _exit_tree() -> void:
	Signals.disconnect_safe(Steam.input_action_event, _on_input_action_event)
	Signals.disconnect_safe(
		steam_input_enabled_property.value_changed, _on_steam_input_state_changed
	)


func _ready() -> void:
	assert(in_game_actions, "invalid state; missing in game actions")
	assert(joypad_monitor is SteamJoypadMonitor, "invalid state; missing node")
	assert(
		steam_input_enabled_property is StdSettingsPropertyBool,
		"invalid state; missing property",
	)

	if steam_input_enabled_property.get_value():
		_on_steam_input_state_changed(true)

	Signals.connect_safe(Steam.input_action_event, _on_input_action_event)
	Signals.connect_safe(
		steam_input_enabled_property.value_changed, _on_steam_input_state_changed
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
		return false

	_action_sets[handle] = action_set
	Steam.activateActionSet(DEVICE_ID_ALL, handle)

	# NOTE: Incoming action events only contain the action's handle. In order to look
	# up the corresponding action name, populate the action handles now.
	_store_action_handles(action_set)

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
		layer.parent == _get_action_set(slot),
		"invalid argument: wrong parent action set",
	)

	var handle := get_action_set_handle(layer.name)
	if not handle:
		return false

	# FIXME: This lookup is required because of the need to return whether the action
	# set layer was changed. This may be a performance issue, so consider removing.
	if handle in Steam.getActiveActionSetLayers(device):
		return false

	_action_sets[handle] = layer
	Steam.activateActionSetLayer(DEVICE_ID_ALL, handle)

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

	var handle := get_action_set_handle(layer.name)
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


func _initialize_action_handles() -> void:
	# Fetch all action and action set handles prior to connecting to event handler.
	for action_set in in_game_actions.action_sets + in_game_actions.action_set_layers:
		get_action_set_handle(action_set.name)
		_store_action_handles(action_set)


func _publish_input_event(event: InputEvent) -> void:
	Input.parse_input_event(event)

	if not event is InputEventAction:
		return

	if event.pressed:
		Input.action_press(event.action)
	else:
		Input.action_release(event.action)


func _store_action_handles(action_set: StdInputActionSet) -> void:
	if action_set in _actions_seen_action_sets:
		return

	for action in action_set.actions_digital:
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
			action.ends_with("_x") or action.ends_with("_y"),
			"invalid action; 2D analog action must specify axis"
		)
		assert(
			action != action_set.action_absolute_mouse,
			"invalid config; conflicting action type"
		)

		var action_base := action.trim_suffix("_x").trim_suffix("_y")

		var handle := get_analog_action_handle(action_base)
		if not handle:
			assert(false, "failed to fetch action handle")
			continue

		_actions[handle] = action_base

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

			match action_data["mode"]:
				Steam.INPUT_SOURCE_MODE_TRIGGER:
					var event := InputEventAction.new()
					event.action = action
					event.device = slot
					event.event_index = action_handle
					event.strength = motion.x

					# FIXME: It's not clear whether reported event strength is *after* deadzone
					# handling or if it's always the raw value.
					event.pressed = event.strength != 0.0

					_publish_input_event(event)

				Steam.INPUT_SOURCE_MODE_ABSOLUTE_MOUSE, Steam.INPUT_SOURCE_MODE_RELATIVE_MOUSE:
					var event := InputEventMouseMotion.new()
					event.device = -1  # FIXME: Should this be `0` or `device`?
					event.relative = motion

					_publish_input_event(event)

				_:
					var event_x := InputEventAction.new()
					event_x.device = slot
					event_x.action = action + "_x"
					event_x.event_index = action_handle

					event_x.strength = motion.x

					# FIXME: It's not clear whether reported event strength is *after* deadzone
					# handling or if it's always the raw value.
					event_x.pressed = event_x.strength != 0.0

					var event_y := event_x.duplicate()
					event_y.action = action + "_y"
					event_y.strength = action_data["y"]

					# FIXME: It's not clear whether reported event strength is *after* deadzone
					# handling or if it's always the raw value.
					event_y.pressed = event_y.strength != 0.0

					_publish_input_event(event_x)
					_publish_input_event(event_y)

		Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION:
			var event := InputEventAction.new()
			event.action = action
			event.device = slot
			event.event_index = action_handle

			event.pressed = action_data["state"]
			event.strength = 1.0 if event.pressed else 0.0

			_publish_input_event(event)


func _on_steam_input_state_changed(enabled: bool) -> void:
	if not enabled or _is_initialized:
		return

	_initialize_action_handles()
	_is_initialized = true
