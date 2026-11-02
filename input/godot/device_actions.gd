##
## std/input/godot/device_bindings.gd
##
## An implemention of `StdInputDeviceActions` which uses Godot's built-in action map
## (plus custom action set handling) to manage available actions.
##
## NOTE: This implementation requires that all action sets/bindings apply to all input
## devices. Changing action sets for one device thus changes them for all devices.
##

extends StdInputDeviceActions

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../../event/signal.gd")
const Bindings := preload("binding.gd")
const Origin := preload("origin.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name
const DEVICE_ID_ALL := StdInputDevice.DEVICE_ID_ALL

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_group("Device types")

## claim_kbm_input defines whether this implementation should manage bindings for the
## keyboard and mouse input device.
@export var claim_kbm_input: bool = true:
	set(value):
		if value == claim_kbm_input:
			return

		claim_kbm_input = value

		reload()

## claim_joy_input defines whether this implementation should manage bindings for joypad
## input devices.
@export var claim_joy_input: bool = true:
	set(value):
		if value == claim_joy_input:
			return

		claim_joy_input = value

		reload()

# -- INITIALIZATION ------------------------------------------------------------------ #

## _action_set is the currently active action set.
static var _action_set: StdInputActionSet = null  # gdlint: ignore=class-definitions-order,max-line-length

## _action_set_layers is the stack of currently active action set layers.
static var _action_set_layers: Array[StdInputActionSetLayer] = []  # gdlint: ignore=class-definitions-order,max-line-length

## _bindings maps origins (integers) to the actions they are bound to.
static var _bindings: Dictionary = {}  # gdlint: ignore=class-definitions-order

var _logger := StdLogger.create("std/input/godot/device-actions")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## reload refreshes the state of all input bindings for the specified device (defaults
## to updating all devices). This is helpful for rebuilding Godot's input map after
## configuration changes, which it reports through `bindings_changed`.
func reload(device: int = DEVICE_ID_ALL) -> void:
	_rebuild(device)

	bindings_changed.emit()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if scope:
		Signals.disconnect_safe(scope.loaded, _on_scope_loaded)

		if scope.config:
			Signals.disconnect_safe(scope.config.changed, _on_config_changed)


func _ready() -> void:
	assert(scope is StdSettingsScope, "invalid config; missing bindings scope")

	if scope.is_loaded:
		_on_scope_loaded()
	else:
		scope.loaded.connect(_on_scope_loaded, CONNECT_ONE_SHOT)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## get_action_set returns the currently active `InputActionSet` *for the specified
## device*.
func _get_action_set(_device: int) -> StdInputActionSet:
	return _action_set


## load_action_set unloads the currently active `StdInputActionSet`, if any, and then
## activates the provided action set *for the specified device*. If the action set
## is already active for the device then no change occurs.
func _load_action_set(_device: int, action_set: StdInputActionSet) -> bool:
	assert(action_set is StdInputActionSet, "missing argument: action set")
	assert(
		not action_set is StdInputActionSetLayer, "invalid argument: cannot use a layer"
	)

	if action_set == _action_set:
		return false

	_action_set = action_set
	_action_set_layers = []

	_rebuild(DEVICE_ID_ALL)

	return true


# Action set layers


## disable_action_set_layer removes the provided action set layer from the set of
## active layers *for the specified device*. If the action set layer is not active
## then no change occurs.
func _disable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")

	if not _action_set is StdInputActionSet:
		assert(false, "invalid state: missing action set")
		return false

	assert(
		action_set_layer.parent == null or action_set_layer.parent == _action_set,
		"invalid argument: wrong parent action set",
	)

	if action_set_layer not in _action_set_layers:
		return false

	_action_set_layers.erase(action_set_layer)
	assert(action_set_layer not in _action_set_layers, "found duplicate layer")

	# NOTE: The caller reports the layer change itself, so `bindings_changed` is not
	# emitted here; it would reach the slot while the layer is still listed as active.
	_rebuild(DEVICE_ID_ALL)

	return true


## enable_action_set_layer pushes the provided action set layer onto the stack of
## active layers *for the specified device*. If the action set layer is already
## active then no change occurs.
func _enable_action_set_layer(
	_device: int, action_set_layer: StdInputActionSetLayer
) -> bool:
	assert(action_set_layer is StdInputActionSetLayer, "missing argument: layer")

	if not _action_set is StdInputActionSet:
		assert(false, "invalid state: missing action set")
		return false

	assert(
		action_set_layer.parent == null or action_set_layer.parent == _action_set,
		"invalid argument: wrong parent action set",
	)

	if action_set_layer in _action_set_layers:
		return false

	_action_set_layers.append(action_set_layer)

	if claim_kbm_input:
		_apply_action_set(DEVICE_ID_ALL, DeviceType.KEYBOARD, action_set_layer)
	if claim_joy_input:
		_apply_action_set(DEVICE_ID_ALL, DeviceType.GENERIC, action_set_layer)

	_sync_input_map()

	return true


## list_action_set_layers returns the stack of currently active action set layers
## *for the specified device*.
func _list_action_set_layers(_device: int) -> Array[StdInputActionSetLayer]:
	return _action_set_layers.duplicate()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_action_set(
	device: int, device_type: DeviceType, action_set: StdInputActionSet
) -> void:
	# NOTE: A 2D analog action names a Steam stick which drives four digital actions;
	# Godot binds those four directional actions instead, so the stick is skipped.
	for actions in [action_set.actions_analog_1d, action_set.actions_digital]:
		for action in actions:
			if not InputMap.has_action(action):
				assert(false, "invalid state; unknown action")
				InputMap.add_action(action)

			for origin in _get_action_origins(device, device_type, action_set, action):
				_bind_action_to_origin(device, action_set, action, origin)


func _bind_action_to_origin(
	device: int, action_set: StdInputActionSet, action: StringName, origin: int
) -> void:
	var event := Origin.decode(origin)
	assert(event is InputEvent, "invalid state; missing event")

	event.device = device

	if not action_set.is_matching_event_origin(action, event):
		assert(false, "invalid state; wrong event type")
		return

	if origin in _bindings:
		var previous: StringName = _bindings[origin]
		if previous != action:
			# NOTE: A later set or layer takes the origin; this only reports it.
			(
				_logger
				. debug(
					"Rebound origin from another action.",
					{&"origin": origin, &"from": previous, &"to": action},
				)
			)

	_bindings[origin] = action


func _get_action_origins(
	_device: int,
	device_type: DeviceType,
	action_set: StdInputActionSet,
	action: StringName,
) -> PackedInt64Array:
	var origins := PackedInt64Array()

	for index in StdInputDeviceActions.BindingIndex.values():
		var event := (
			Bindings
			. get_action_binding(
				scope,
				action_set,
				action,
				StdInputDevice.get_device_category(device_type),
				index,
			)
		)

		if not event:
			continue

		var value_encoded: int = Origin.encode(event)
		if value_encoded < 0:
			assert(false, "invalid state; failed to encode origin")
			continue

		if value_encoded not in origins:
			origins.append(value_encoded)

	return origins


## _list_active_sets returns the active action set, if any, followed by its layers.
func _list_active_sets() -> Array[StdInputActionSet]:
	var action_sets: Array[StdInputActionSet] = []

	if _action_set:
		action_sets.append(_action_set)

	action_sets.append_array(_action_set_layers)

	return action_sets


## _rebuild recomputes the bindings of the active set and layers, without reporting a
## change, and applies them to the input map.
func _rebuild(_device: int) -> void:
	assert(
		_action_set or not _action_set_layers, "invalid state; found dangling layers"
	)

	_bindings = {}

	for action_set in _list_active_sets():
		if claim_kbm_input:
			_apply_action_set(DEVICE_ID_ALL, DeviceType.KEYBOARD, action_set)
		if claim_joy_input:
			_apply_action_set(DEVICE_ID_ALL, DeviceType.GENERIC, action_set)

	_sync_input_map()


## _sync_input_map makes the input map match `_bindings`, leaving an action whose
## bindings are unchanged alone so that `Input` keeps its state.
##
## NOTE: A changed action is rebound whole, which releases it. Adding a binding alone
## would strand a held injected press, whose state is indexed by the binding count.
func _sync_input_map() -> void:
	var wanted: Dictionary[StringName, Array] = {}

	for action_set in _list_active_sets():
		for action in action_set.list_action_names(true):
			wanted[StringName(action)] = []

	for origin: int in _bindings:
		var event := Origin.decode(origin)
		event.device = DEVICE_ID_ALL

		wanted[_bindings[origin]].append(event)

	for action: StringName in InputMap.get_actions():
		# NOTE: Nothing reports the release of a press on an action outside the sets. One
		# inside them may be unbound here and still be held on another component's device.
		if action not in wanted and Input.is_action_pressed(action):
			Input.action_release(action)

		var events: Array = wanted.get(action, [])
		var existing := InputMap.action_get_events(action)

		# NOTE: The map keeps one of two events which match, such as a key at two
		# locations, so the events are compared as the map does rather than counted.
		if (
			events.all(func(e): return InputMap.action_has_event(action, e))
			and existing.all(func(e): return events.any(func(w): return w.is_match(e)))
		):
			continue

		InputMap.action_erase_events(action)

		for event: InputEvent in events:
			InputMap.action_add_event(action, event)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_config_changed(_category: StringName, _key: StringName) -> void:
	reload()


func _on_scope_loaded() -> void:
	Signals.connect_safe(scope.config.changed, _on_config_changed)
	reload(DEVICE_ID_ALL)
