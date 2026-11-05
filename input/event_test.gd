##
## std/input/event_test.gd
##
## Tests pertaining to `StdInputEvent`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _content_scale_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_DISABLED
var _content_scale_size := Vector2i.ZERO

# -- TEST METHODS -------------------------------------------------------------------- #


func test_refresh_hover_under_a_content_scale_hovers_the_control() -> void:
	# Given: A scene mounted at the root.
	var scene := Control.new()
	var input := await StdTestInput.mount(self, scene)

	# Given: The root scales its canvas items by two.
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(Vector2(root.size) * 0.5)
	await wait_process_frames(1)

	# Given: A hidden button with the mouse resting where it will show.
	var button := Button.new()
	button.position = Vector2(150, 100)
	button.size = Vector2(60, 30)
	button.hide()
	scene.add_child(button)
	await wait_process_frames(1)
	input.move_mouse(button.get_global_rect().get_center())

	# Given: The button is shown, which hovers nothing until the mouse moves.
	button.show()
	await wait_process_frames(1)
	assert_false(button.is_hovered())

	# When: Hover is refreshed.
	StdInputEvent.refresh_hover(root)
	await wait_process_frames(1)

	# Then: The button is hovered.
	assert_true(button.is_hovered())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func after_each() -> void:
	var root := get_tree().root
	root.content_scale_mode = _content_scale_mode
	root.content_scale_size = _content_scale_size


func before_each() -> void:
	var root := get_tree().root
	_content_scale_mode = root.content_scale_mode
	_content_scale_size = root.content_scale_size
