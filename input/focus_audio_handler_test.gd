##
## Tests pertaining to the `StdFocusAudioHandler` class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var cursor: StdInputCursor = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_focus_handler_state_when_focused_and_not_hovered() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var focus_handler := StdInputCursorFocusHandler.new()
	focus_handler.control = NodePath("..")
	button.add_child(focus_handler)

	# Given: An audio handler (no sound effects - just testing state).
	var audio_handler := StdFocusAudioHandler.new()
	audio_handler.focus_handler = NodePath("..")
	focus_handler.add_child(audio_handler)

	# When: The button gains focus (not hovered).
	button.focus_entered.emit()

	# Then: The state is correct for focus sound to play (focused and not hovered).
	assert_true(focus_handler.is_focused())
	assert_false(focus_handler.is_hovered())


func test_focus_sound_skipped_when_already_hovered() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var focus_handler := StdInputCursorFocusHandler.new()
	focus_handler.control = NodePath("..")
	button.add_child(focus_handler)

	# Given: An audio handler (no sound effects - just testing state).
	var audio_handler := StdFocusAudioHandler.new()
	audio_handler.focus_handler = NodePath("..")
	focus_handler.add_child(audio_handler)

	# Given: The button is already hovered.
	button.mouse_entered.emit()
	assert_true(focus_handler.is_hovered())

	# When: The button gains focus while hovered.
	button.focus_entered.emit()

	# Then: The state shows focus sound should be skipped (already hovered).
	assert_true(focus_handler.is_focused())
	assert_true(focus_handler.is_hovered())


func test_focus_handler_state_when_hovered_and_not_focused() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var focus_handler := StdInputCursorFocusHandler.new()
	focus_handler.control = NodePath("..")
	button.add_child(focus_handler)

	# Given: An audio handler (no sound effects - just testing state).
	var audio_handler := StdFocusAudioHandler.new()
	audio_handler.focus_handler = NodePath("..")
	focus_handler.add_child(audio_handler)

	# When: The mouse enters the button (not focused).
	button.mouse_entered.emit()

	# Then: The state is correct for hover sound to play (hovered and not focused).
	assert_true(focus_handler.is_hovered())
	assert_false(focus_handler.is_focused())


func test_hover_sound_skipped_when_already_focused() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var focus_handler := StdInputCursorFocusHandler.new()
	focus_handler.control = NodePath("..")
	button.add_child(focus_handler)

	# Given: An audio handler (no sound effects - just testing state).
	var audio_handler := StdFocusAudioHandler.new()
	audio_handler.focus_handler = NodePath("..")
	focus_handler.add_child(audio_handler)

	# Given: The button is already focused.
	button.focus_entered.emit()
	assert_true(focus_handler.is_focused())

	# When: The mouse enters the button while focused.
	button.mouse_entered.emit()

	# Then: The state shows hover sound should be skipped (already focused).
	assert_true(focus_handler.is_hovered())
	assert_true(focus_handler.is_focused())


func test_no_errors_when_sound_events_not_configured() -> void:
	# Given: A cursor in the scene.
	add_child_autofree(cursor)

	# Given: A button with a focus handler.
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_child_autofree(button)

	var focus_handler := StdInputCursorFocusHandler.new()
	focus_handler.control = NodePath("..")
	button.add_child(focus_handler)

	# Given: An audio handler without sound effects configured.
	var audio_handler := StdFocusAudioHandler.new()
	audio_handler.focus_handler = NodePath("..")
	focus_handler.add_child(audio_handler)

	# When: Focus and hover events occur.
	button.focus_entered.emit()
	button.mouse_entered.emit()

	# Then: No errors occur and state is tracked correctly.
	assert_true(focus_handler.is_focused())
	assert_true(focus_handler.is_hovered())


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	# Clear global state before each test.
	StdGroup.with_id(StdInputCursor.GROUP_INPUT_CURSOR).clear_members()
	StdInputCursorFocusHandler._anchors.clear()

	cursor = autofree(StdInputCursor.new())


func after_each() -> void:
	cursor = null
