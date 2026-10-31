##
## std/test/input.gd
##
## StdTestInput mounts a scene where input dispatches under headless GUT and drives it
## with real events, so a test covers the picking and focus that emitting `pressed` or
## aiming GUT's `InputSender` at a control's `_gui_input` skips.
##
## A GUT test adds it with `add_child_autofree`, awaits one mount, and then sends
## events. Freeing it frees the mounted scene and undoes what mounting changed. `mount`
## is the default; `mount_at_root` is for a scene that needs the real root, such as one
## that reads `get_window()`.
##
## NOTE: Events do dispatch at the headless root, whatever godotengine/godot#73557 and
## earlier notes here suggest. Two other things lose a click there, and `mount_at_root`
## undoes both while this node lives. The headless display server leaves the root
## window at 64x64, and a press beyond that rect picks no control. GUT's own panel, on
## canvas layer 128, covers most of that corner and takes the press itself.
##
## NOTE: The other suspects were not the cause. A control with a set size takes a click
## in the frame it mounts, though a container's children only settle a frame later,
## which is why mounting awaits one. `Input.parse_input_event` does hold events until
## `Input.flush_buffered_events`, but it reaches only the root, so events here go
## through `Viewport.push_input` on the mounted viewport.
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
var _root_size := Vector2i.ZERO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## click sends a press and a release of `button_index` at the center of `control`. Both
## are picked as a real click is, so whatever covers `control` takes them instead.
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
		event.global_position = center
		event.position = center
		event.pressed = pressed

		viewport.push_input(event, true)


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

	_root_size = root.size
	root.size = _get_window_size()

	_gut_layer = root.get_node_or_null(_GUT_LAYER_PATH)
	if _gut_layer:
		_gut_layer.hide()

	viewport = root
	add_child(scene)

	await get_tree().process_frame


## press_action holds `action` in `Input` and sends its press event. An action still
## held when this node is freed is released then.
func press_action(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)

	_push_action(action, true)


## press_key sends a press of the key `keycode`.
##
## NOTE: This only reaches the viewport, so `Input.is_key_pressed` and action polling
## don't see it. A test of polled state should use `press_action`.
func press_key(keycode: Key) -> void:
	_push_key(keycode, true)


## release_action releases `action` in `Input` and sends its release event.
func release_action(action: StringName) -> void:
	Input.action_release(action)
	_held_actions.erase(action)

	_push_action(action, false)


## release_key sends a release of the key `keycode`.
func release_key(keycode: Key) -> void:
	_push_key(keycode, false)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	for action in _held_actions:
		Input.action_release(action)

	_held_actions.clear()

	if _gut_layer:
		_gut_layer.show()

	if _root_size != Vector2i.ZERO:
		get_tree().root.size = _root_size


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_window_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting(_SETTING_WINDOW_WIDTH),
		ProjectSettings.get_setting(_SETTING_WINDOW_HEIGHT),
	)


func _push_action(action: StringName, pressed: bool) -> void:
	assert(viewport, "invalid state: nothing mounted")

	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed

	viewport.push_input(event)


func _push_key(keycode: Key, pressed: bool) -> void:
	assert(viewport, "invalid state: nothing mounted")

	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed

	viewport.push_input(event)
