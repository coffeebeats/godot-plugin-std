##
## std/test/input.gd
##
## StdTestInput mounts a scene at the root viewport under headless GUT and drives it
## with real events, so a test covers the picking and focus that emitting `pressed` or
## aiming GUT's `InputSender` at a control's `_gui_input` skips.
##
## A GUT test awaits `mount` and then sends events, each of which takes effect before
## its call returns. GUT frees this node after the test, which frees the mounted scene
## and undoes what mounting and sending changed.
##
## NOTE: Events go through `Input`, so polled state follows them, and they reach every
## node in the tree as a game's do, including a node an earlier test left there. A
## `SubViewport` would isolate a scene, but `Input` doesn't see what `push_input` sends,
## so a scene that polls it would silently read nothing.
##
## NOTE: A click at the headless root is lost to two things, which this node undoes
## while it lives. The root window stays 64x64, and a press beyond it picks no control.
## GUT's panel, on canvas layer 128, takes a press over most of that corner. Events do
## dispatch there, whatever godotengine/godot#73557 suggests. A control with a set size
## takes a click in the frame it mounts, and each event flushes `Input`'s buffer, so
## neither loses one.
##
## NOTE: Mounting awaits, which std otherwise never does, since only GUT tests call it.
##
## NOTE: A release sent at free is stamped with the current frame, and GUT doesn't
## always cross one between tests, so a test reading `Input.is_action_just_released`
## before its first await can see one from the test before it. Awaiting `mount` crosses
## a frame.
##

class_name StdTestInput
extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const _GUT_LAYER_PATH := ^"GutRunner/GutLayer"
const _SETTING_WINDOW_HEIGHT := &"display/window/size/viewport_height"
const _SETTING_WINDOW_WIDTH := &"display/window/size/viewport_width"

# -- INITIALIZATION ------------------------------------------------------------------ #

## _mounted is the helper holding the root, since two can't restore it in the right
## order when GUT frees them in the order they were added.
static var _mounted: StdTestInput = null

var _gut_layer: CanvasLayer = null

## _releases holds the event which ends each input still held. Each is a copy taken at
## the press, so a test that goes on to change the event it sent doesn't change it.
var _releases: Array[InputEvent] = []

var _root_size := Vector2i.ZERO

## _window_mouse_position is where the mouse was at mount. It's in window coordinates
## because the root's own coordinates change with its content scale.
var _window_mouse_position := Vector2.ZERO

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## click moves the mouse to the center of `control` and clicks there. The click is
## picked as a real one is, so whatever covers `control` takes it instead.
func click(control: Control, button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	assert(
		control.get_viewport() == get_viewport(),
		"invalid argument: control isn't in the root viewport",
	)

	click_at(
		control.get_global_transform_with_canvas() * (control.size / 2.0),
		button_index,
	)


## click_at moves the mouse to `position`, in the root's coordinates, and clicks there.
func click_at(
	position: Vector2,
	button_index: MouseButton = MOUSE_BUTTON_LEFT,
) -> void:
	move_mouse(position)
	press_mouse(button_index)
	release_mouse(button_index)


## mount adds `scene` to the root viewport, sizes the root to the project's window size,
## hides GUT's panel, and returns once the scene's layout has settled. `test` is the
## calling `GutTest`, which frees the returned node when the test ends.
##
## NOTE: A test mounts once, so several scenes go under one parent.
##
## NOTE: This requires `--headless`. Elsewhere the root's mouse position follows the
## real cursor, so a press would land there rather than where this node moved the mouse.
##
## NOTE: `test` is typed as a `Node` so that this file loads in a project without GUT.
static func mount(test: Node, scene: Node) -> StdTestInput:
	assert(
		test.has_method(&"add_child_autofree"),
		"invalid argument: test isn't a GutTest",
	)
	assert(DisplayServer.get_name() == &"headless", "invalid state: not headless")
	assert(_mounted == null, "invalid state: a helper is already mounted")

	var input := StdTestInput.new()
	test.add_child_autofree(input)

	await input._mount(scene)

	return input


## move_mouse sends a motion to `position`, in the root's coordinates, which updates
## hover and the root's mouse position.
##
## NOTE: A hidden cursor is revealed only by a motion crossing its threshold, so pass a
## `relative` distance, in the root's coordinates, to stand in for a player moving the
## mouse. A held press starts a drag the same way, once the distance sent adds up past
## the viewport's threshold.
func move_mouse(position: Vector2, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = get_tree().root.get_final_transform().basis_xform(relative)
	event.screen_relative = event.relative
	event.button_mask = Input.get_mouse_button_mask()
	_set_mouse_position(event, position)

	send(event)


## press_action sends a press of `action`, held until it's released or this node is
## freed.
func press_action(action: StringName) -> void:
	send(_make_action(action, true))


## press_key sends a press of the key `keycode`, held until it's released or this node
## is freed.
##
## NOTE: The event carries no `unicode`, so a `LineEdit` takes no text from it.
func press_key(keycode: Key) -> void:
	send(_make_key(keycode, true))


## press_mouse sends a press of `button_index` where the mouse is, held until it's
## released or this node is freed.
##
## NOTE: The event carries no `button_mask`, which the engine reads only from a motion.
func press_mouse(button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	send(_make_mouse_button(button_index, true))


## release_action sends a release of `action`.
func release_action(action: StringName) -> void:
	send(_make_action(action, false))


## release_key sends a release of the key `keycode`.
func release_key(keycode: Key) -> void:
	send(_make_key(keycode, false))


## release_mouse sends a release of `button_index` where the mouse is.
func release_mouse(button_index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	send(_make_mouse_button(button_index, false))


## send dispatches `event` as a player's input, for anything the other methods don't
## cover. A press or a joypad axis still held when this node is freed is released then.
func send(event: InputEvent) -> void:
	assert(_mounted == self, "invalid state: nothing mounted")

	_track_held(event)

	Input.parse_input_event(event)
	Input.flush_buffered_events()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _mounted != self:
		return

	for release in _releases.duplicate():
		send(release)

	var root := get_tree().root
	move_mouse(root.get_final_transform().affine_inverse() * _window_mouse_position)

	if _gut_layer:
		_gut_layer.show()

	root.size = _root_size

	_mounted = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _is_same_input returns whether `a` and `b` come from one origin on one device.
##
## NOTE: `is_match` isn't enough alone. An action matches any event bound to it, and a
## touch matches nothing.
func _is_same_input(a: InputEvent, b: InputEvent) -> bool:
	if a.device != b.device or a.get_class() != b.get_class():
		return false

	if a is InputEventScreenTouch:
		return a.index == b.index

	return a.is_match(b, false)


func _make_action(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed

	return event


func _make_key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed

	return event


func _make_mouse_button(
	button_index: MouseButton,
	pressed: bool,
) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	_set_mouse_position(event, get_viewport().get_mouse_position())

	return event


## _make_release returns an event which ends the hold that `event` started.
##
## NOTE: A key repeat holds an action as a press does, but `Input` ignores a repeat for
## key state, so a release can't be one.
func _make_release(event: InputEvent) -> InputEvent:
	var release: InputEvent = event.duplicate()

	if release is InputEventJoypadMotion:
		release.axis_value = 0.0
	else:
		release.pressed = false

	if release is InputEventKey:
		release.echo = false

	return release


func _mount(scene: Node) -> void:
	var root := get_tree().root
	assert(get_viewport() == root, "invalid state: not in the root viewport")

	_mounted = self
	_root_size = root.size
	_window_mouse_position = root.get_final_transform() * root.get_mouse_position()

	root.size = Vector2i(
		ProjectSettings.get_setting(_SETTING_WINDOW_WIDTH),
		ProjectSettings.get_setting(_SETTING_WINDOW_HEIGHT),
	)

	_gut_layer = root.get_node_or_null(_GUT_LAYER_PATH)
	if _gut_layer:
		_gut_layer.hide()

	add_child(scene)

	await get_tree().process_frame


## _set_mouse_position places `event` at `position` in the root's coordinates.
##
## NOTE: `Input` takes window coordinates, which differ from the root's own under a
## content scale.
func _set_mouse_position(event: InputEventMouse, position: Vector2) -> void:
	position = get_tree().root.get_final_transform() * position

	event.global_position = position
	event.position = position


## _track_held records the release for `event` if it holds input, replacing any earlier
## record from the same device on the same origin.
##
## NOTE: A joypad axis counts as held at any value other than zero, since `Input` keeps
## the value while `is_pressed` is false below 0.5. A shortcut event is always pressed
## but holds nothing, so an event without a `pressed` property to clear isn't held.
func _track_held(event: InputEvent) -> void:
	for index in _releases.size():
		if _is_same_input(_releases[index], event):
			_releases.remove_at(index)
			break

	var is_held: bool = (
		not is_zero_approx(event.axis_value)
		if event is InputEventJoypadMotion
		else event.is_pressed() and &"pressed" in event
	)

	if is_held:
		_releases.append(_make_release(event))
