##
## std/test/input.gd
##
## StdTestInput mounts a scene where input dispatches under headless GUT and drives it
## with real events, so a test covers the picking and focus that emitting `pressed` or
## aiming GUT's `InputSender` at a control's `_gui_input` skips.
##
## A GUT test adds it with `add_child_autofree`, awaits one mount, and then sends
## events. Freeing it frees the mounted scene and undoes what mounting and sending
## changed.
##
## `mount` is the default. Its events go straight to a `SubViewport` through
## `Viewport.push_input`, so they pick and focus as usual but `Input` doesn't see them.
## `mount_at_root` is for a scene that polls `Input`. Its events take the engine's own
## path through `Input.parse_input_event`, so `Input.is_key_pressed`,
## `Input.is_mouse_button_pressed` and the root's `get_mouse_position` all follow them.
##
## NOTE: Events do dispatch at the headless root, whatever godotengine/godot#73557
## suggests. Two other things lose a click there, and `mount_at_root` undoes both while
## this node lives. The headless display server leaves the root window at 64x64, and a
## press beyond that rect picks no control. GUT's own panel, on canvas layer 128, covers
## most of that corner and takes the press itself.
##
## NOTE: The other suspects were not the cause. A control with a set size takes a click
## in the frame it mounts, though a container's children only settle a frame later,
## which is why mounting awaits one. `Input.parse_input_event` does hold events until
## `Input.flush_buffered_events`, which each event sent at the root calls.
##
## NOTE: Mounting awaits, which std otherwise never does, since only GUT tests call it.
##

class_name StdTestInput
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const _GUT_LAYER_PATH := ^"GutRunner/GutLayer"
const _SETTING_WINDOW_HEIGHT := &"display/window/size/viewport_height"
const _SETTING_WINDOW_WIDTH := &"display/window/size/viewport_width"

# -- INITIALIZATION ------------------------------------------------------------------ #

## viewport is where the scene is mounted and where events are sent. It's `null` until a
## mount starts.
var viewport: Viewport = null

var _gut_layer: CanvasLayer = null
var _held_actions: Array[StringName] = []
var _held_keys: Array[Key] = []
var _root_mouse_position := Vector2.ZERO
var _root_size := Vector2i.ZERO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## click sends a press and a release of `button_index` at the center of `control`, which
## also moves the mouse there. Both are picked as a real click is, so whatever covers
## `control` takes them instead.
func click(control: Control, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	assert(viewport, "invalid state: nothing mounted")
	assert(
		control.get_viewport() == viewport,
		"invalid argument: control isn't in the mounted viewport",
	)

	var center := control.get_global_transform_with_canvas() * (control.size / 2.0)

	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button_index
		event.pressed = pressed
		_set_mouse_position(event, center)

		_send(event)


## mount adds `scene` to a `SubViewport` of the project's window size, away from
## everything at the root, and returns after one frame so that its layout has settled.
func mount(scene: Node) -> void:
	assert(viewport == null, "invalid state: already mounted")

	var sub_viewport := SubViewport.new()
	sub_viewport.size = _get_window_size()
	add_child(sub_viewport)

	viewport = sub_viewport
	viewport.add_child(scene)

	await get_tree().process_frame


## mount_at_root adds `scene` to the root viewport, sizes the root to the project's
## window size, hides GUT's panel, and returns after one frame so that its layout has
## settled.
func mount_at_root(scene: Node) -> void:
	assert(viewport == null, "invalid state: already mounted")
	assert(get_viewport() == get_tree().root, "invalid state: not in the root viewport")

	var root := get_tree().root

	_root_mouse_position = root.get_mouse_position()
	_root_size = root.size
	root.size = _get_window_size()

	_gut_layer = root.get_node_or_null(_GUT_LAYER_PATH)
	if _gut_layer:
		_gut_layer.hide()

	viewport = root
	add_child(scene)

	await get_tree().process_frame


## move_mouse sends a motion to `position`, in the mounted viewport's coordinates.
##
## NOTE: The motion has no relative distance, so it updates hover and the viewport's
## mouse position without crossing the threshold that reveals a hidden cursor.
func move_mouse(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	_set_mouse_position(event, position)

	_send(event)


## press_action holds `action` in `Input` and sends its press event. An action still
## held when this node is freed is released then.
func press_action(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)

	_send_action(action, true)


## press_key sends a press of the key `keycode`. A key still held when this node is
## freed is released then.
##
## NOTE: The event carries no `unicode`, so a `LineEdit` takes no text from it. Under
## `mount`, `Input` doesn't see the key, so a test polling a bound action there should
## use `press_action`.
func press_key(keycode: Key) -> void:
	_held_keys.append(keycode)

	_send_key(keycode, true)


## release_action releases `action` in `Input` and sends its release event.
func release_action(action: StringName) -> void:
	Input.action_release(action)
	_held_actions.erase(action)

	_send_action(action, false)


## release_key sends a release of the key `keycode`.
func release_key(keycode: Key) -> void:
	_held_keys.erase(keycode)

	_send_key(keycode, false)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	for action in _held_actions:
		Input.action_release(action)

	_held_actions.clear()

	if viewport != get_tree().root:
		return

	for keycode in _held_keys:
		_send_key(keycode, false)

	_held_keys.clear()

	move_mouse(_root_mouse_position)

	if _gut_layer:
		_gut_layer.show()

	get_tree().root.size = _root_size


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_window_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting(_SETTING_WINDOW_WIDTH),
		ProjectSettings.get_setting(_SETTING_WINDOW_HEIGHT),
	)


func _send(event: InputEvent) -> void:
	assert(viewport, "invalid state: nothing mounted")

	if viewport is SubViewport:
		viewport.push_input(event, true)
		return

	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed

	_send(event)


func _send_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed

	_send(event)


## _set_mouse_position places `event` at `position` in the mounted viewport's
## coordinates.
##
## NOTE: `Input` takes window coordinates, which differ from the root viewport's own
## under a content scale, while `push_input` is called with local ones.
func _set_mouse_position(event: InputEventMouse, position: Vector2) -> void:
	if viewport is Window:
		position = (viewport as Window).get_final_transform() * position

	event.global_position = position
	event.position = position
