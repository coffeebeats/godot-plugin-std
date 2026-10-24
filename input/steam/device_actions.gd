##
## std/input/steam/device_actions.gd
##
## StdInputSteamDeviceActions is an implemention of `StdInputDeviceActions` which uses
## the Steam Input API to manage action sets.
##
## NOTE: Steam resets a controller's action set and layers on every focus change, and
## reports a change a frame after it's made. The set and layer stack are thus recorded
## per joypad, answer every query, and are applied to Steam again whenever it reports
## something else, as Valve advises; see
## https://partner.steamgames.com/doc/api/ISteamInput#ActivateActionSet.

extends StdInputDeviceActions

# -- DEPENDENCIES -------------------------------------------------------------------- #

const MotionFilter := preload("../motion_filter.gd")
const Signals := preload("../../event/signal.gd")
const SteamJoypadMonitor := preload("joypad_monitor.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## _STICK_DEADZONE is the `InputMap` deadzone of a stick's directions while Steam Input
## drives the stick, since Steam reports it past the deadzone its configurator sets.
##
## NOTE: It's Godot's `CMP_EPSILON`, above `0`, at which a native axis at rest reads
## pressed, and below a 16-bit axis's step of `1 / 32767`, so it filters no reading.
const _STICK_DEADZONE := 0.00001


## _ActionSetStack is the action set and layer stack recorded for one joypad.
class _ActionSetStack:
	extends RefCounted

	var action_set: StdInputActionSet = null
	var layers: Array[StdInputActionSetLayer] = []

	## written is the process frame in which the stack was last applied to Steam.
	var written: int = 0


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

## _analog_actions is a mapping from analog action handles to action names.
##
## NOTE: Steam numbers digital and analog action handles separately, so a digital action
## and an analog action can share a handle; each kind keeps its own maps.
static var _analog_actions: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _analog_action_handles is a reverse mapping from analog action names to handles.
static var _analog_action_handles: Dictionary = {}  # gdlint:ignore=class-definitions-order,max-line-length

## _digital_actions is a mapping from digital action handles to action names.
static var _digital_actions: Dictionary = {}  # gdlint:ignore=class-definitions-order

## _digital_action_handles is a reverse mapping from digital action names to handles.
static var _digital_action_handles: Dictionary = {}  # gdlint:ignore=class-definitions-order,max-line-length

## _actions_seen_action_sets is the list of action sets which already have their action
## handles populated. This is used to skip duplicate work.
##
## NOTE: Because the number of action sets should be small, an array is preferred.
static var _actions_seen_action_sets: Array[StdInputActionSet] = []  # gdlint:ignore=class-definitions-order,max-line-length

## _is_initialized tracks whether this component has been initialized. This needs to
## occur once *after the first joypad has been connected*.
static var _is_initialized: bool = false  # gdlint:ignore=class-definitions-order

## _stacks maps each joypad's slot to the action set and layer stack recorded for it.
static var _stacks: Dictionary[int, _ActionSetStack] = {}  # gdlint:ignore=class-definitions-order,max-line-length

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


## get_action_for_event returns the name of the action behind an action event's handle,
## or an empty name when no loaded set registered it.
static func get_action_for_event(
	event_type: Steam.InputActionEventType, action_handle: int
) -> StringName:
	match event_type:
		Steam.INPUT_ACTION_EVENT_TYPE_DIGITAL_ACTION:
			return _digital_actions.get(action_handle, &"")
		Steam.INPUT_ACTION_EVENT_TYPE_ANALOG_ACTION:
			return _analog_actions.get(action_handle, &"")

	return &""


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

	var handle: int = _analog_action_handles.get(action, 0)
	if not handle:
		handle = Steam.getAnalogActionHandle(action)

	if not handle:
		return 0

	_analog_actions[handle] = action
	_analog_action_handles[action] = handle

	return handle


## get_digital_action_handle returns the handle for the specified digital action,
## fetching it from the Steam Input API if it hasn't yet been loaded.
static func get_digital_action_handle(action: StringName) -> int:
	assert(_is_initialized, "invalid state; Steam Input not initialized")

	var handle: int = _digital_action_handles.get(action, 0)
	if not handle:
		handle = Steam.getDigitalActionHandle(action)

	if not handle:
		return 0

	_digital_actions[handle] = action
	_digital_action_handles[action] = handle

	return handle


## resolve_action_set_name returns the name the Steam Input manifest knows `action_set`
## by for the joypad in `slot`. A layer with no parent resolves to its `<Layer>_<Set>`
## copy under the set recorded for the joypad; anything else keeps its own name.
static func resolve_action_set_name(
	action_set: StdInputActionSet, slot: int
) -> StringName:
	if not action_set is StdInputActionSetLayer or action_set.parent:
		return action_set.name

	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		return action_set.name

	return StringName("%s_%s" % [action_set.name, stack.action_set.name])


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

	# NOTE: Steam resets a controller's sets on a focus change even while the game is
	# paused, so the record is applied again regardless.
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	Signals.disconnect_safe(Steam.input_device_connected, _on_input_device_connected)


func _process(_delta: float) -> void:
	for slot in _stacks:
		# NOTE: Steam reports a change a frame after it's made, so a stack applied this
		# frame or the last isn't compared yet.
		if Engine.get_process_frames() - _stacks[slot].written < 2:
			continue

		var device: int = joypad_monitor.get_device_id_for_slot(slot)
		if device == -1:
			continue

		var action_set := Steam.getCurrentActionSet(device)
		var layers := Steam.getActiveActionSetLayers(device)

		if not _is_applied(slot, action_set, layers):
			_apply(slot)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## get_action_set returns the action set recorded for the joypad in `slot`.
func _get_action_set(slot: int) -> StdInputActionSet:
	var stack: _ActionSetStack = _stacks.get(slot)
	return stack.action_set if stack else null


## load_action_set records `action_set` for the joypad in `slot`, with no layers, and
## applies it to Steam. If the action set is already recorded then no change occurs.
func _load_action_set(slot: int, action_set: StdInputActionSet) -> bool:
	if joypad_monitor.get_device_id_for_slot(slot) == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(action_set is StdInputActionSet, "missing argument: action set")
	assert(
		not action_set is StdInputActionSetLayer, "invalid argument: cannot use a layer"
	)

	if action_set == _get_action_set(slot):
		return false

	if not get_action_set_handle(action_set.name):
		_logger.warn("Steam Input has no such action set.", {&"name": action_set.name})
		return false

	var stack := _ActionSetStack.new()
	stack.action_set = action_set
	_stacks[slot] = stack

	# NOTE: Incoming action events only contain the action's handle. In order to look
	# up the corresponding action name, populate the action handles now.
	_store_action_handles(action_set)
	_clear_stick_deadzones(action_set)

	_apply(slot)

	return true


# Action set layers


## enable_action_set_layer pushes `layer` onto the stack recorded for the joypad in
## `slot` and applies the stack to Steam. If the layer is already recorded then no
## change occurs.
func _enable_action_set_layer(slot: int, layer: StdInputActionSetLayer) -> bool:
	if joypad_monitor.get_device_id_for_slot(slot) == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(layer is StdInputActionSetLayer, "missing argument: layer")

	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		assert(false, "invalid state: missing action set")
		return false

	assert(
		layer.parent == null or layer.parent == stack.action_set,
		"invalid argument: wrong parent action set",
	)

	if layer in stack.layers:
		return false

	var layer_name := resolve_action_set_name(layer, slot)
	if not get_action_set_handle(layer_name):
		_logger.warn("Steam Input has no such action set layer.", {&"name": layer_name})
		return false

	stack.layers.append(layer)
	_store_action_handles(layer)
	_clear_stick_deadzones(layer)

	_apply(slot)

	return true


## disable_action_set_layer removes `layer` from the stack recorded for the joypad in
## `slot` and applies the stack to Steam. If the layer isn't recorded then no change
## occurs.
func _disable_action_set_layer(slot: int, layer: StdInputActionSetLayer) -> bool:
	if joypad_monitor.get_device_id_for_slot(slot) == -1:
		assert(false, "invalid argument; failed to find device for slot")
		return false

	assert(layer is StdInputActionSetLayer, "missing argument: layer")

	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack or layer not in stack.layers:
		return false

	stack.layers.erase(layer)

	_apply(slot)

	return true


## list_action_set_layers returns the layer stack recorded for the joypad in `slot`.
func _list_action_set_layers(slot: int) -> Array[StdInputActionSetLayer]:
	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		return []

	return stack.layers.duplicate()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _apply makes Steam hold the stack recorded for the joypad in `slot`: it deactivates
## every layer, activates the set, then activates each layer in stack order, so the
## layers stack as recorded.
func _apply(slot: int) -> void:
	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		return

	var device: int = joypad_monitor.get_device_id_for_slot(slot)
	if device == -1:
		return

	Steam.deactivateAllActionSetLayers(device)
	Steam.activateActionSet(device, get_action_set_handle(stack.action_set.name))

	for handle in _list_layer_handles(slot):
		Steam.activateActionSetLayer(device, handle)

	stack.written = Engine.get_process_frames()


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
## the action set and layers recorded for it.
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


## _is_applied returns whether Steam holds the stack recorded for the joypad in `slot`,
## given the set handle `action_set` and layer handles `layers` Steam reports for it.
## Layers must match in stack order; a joypad with no record holds anything.
static func _is_applied(slot: int, action_set: int, layers: Array) -> bool:
	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		return true

	if action_set != get_action_set_handle(stack.action_set.name):
		return false

	return layers == _list_layer_handles(slot)


## _list_layer_handles returns the handle of each layer recorded for the joypad in
## `slot`, in stack order, skipping any layer the Steam Input manifest lacks.
static func _list_layer_handles(slot: int) -> Array:
	var handles := []

	var stack: _ActionSetStack = _stacks.get(slot)
	if not stack:
		return handles

	for layer in stack.layers:
		var handle := get_action_set_handle(resolve_action_set_name(layer, slot))
		if handle:
			handles.append(handle)

	return handles


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

		if not get_digital_action_handle(action):
			assert(false, "failed to fetch action handle")

	for action in action_set.actions_analog_1d:
		if not get_analog_action_handle(action):
			assert(false, "failed to fetch action handle")

	for action in action_set.actions_analog_2d:
		assert(
			action != action_set.action_absolute_mouse,
			"invalid config; conflicting action type"
		)

		if not get_analog_action_handle(action):
			assert(false, "failed to fetch action handle")

	if action_set.action_absolute_mouse:
		if not get_analog_action_handle(action_set.action_absolute_mouse):
			assert(false, "failed to fetch action handle")

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

	# NOTE: Steam can report a handle no loaded set registered (observed for digital
	# actions on a configuration load), which has no name to publish under.
	var action := get_action_for_event(event_type, action_handle)
	if not action:
		return

	var slot: int = joypad_monitor.get_slot_for_device_id(device)
	if slot == -1:
		return

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
	device_handle: int,
	_config_data: Dictionary,
) -> void:
	# NOTE: Steam loads a configuration once per controller per focus change, which
	# covers a rebind in its configurator, and the load resets the controller's sets.
	var slot: int = joypad_monitor.get_slot_for_device_id(device_handle)
	if slot != -1:
		_apply(slot)

	bindings_changed.emit()


func _on_input_device_connected(device_handle: int) -> void:
	var slot: int = joypad_monitor.get_slot_for_device_id(device_handle)
	if slot != -1:
		_apply(slot)


## _on_joypad_disconnected releases every action the joypad in `slot` was holding, since
## Steam reports nothing further for it, and forgets the slot's held actions and stack.
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
	_stacks.erase(slot)


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
	Signals.connect_safe(Steam.input_device_connected, _on_input_device_connected)
