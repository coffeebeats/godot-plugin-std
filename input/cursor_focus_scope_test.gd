##
## std/input/cursor_focus_scope_test.gd
##
## Tests pertaining to `StdInputCursorFocusScope`.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var _control: Control = null
var _cursor: StdInputCursor = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_scope_without_a_panel_claims_while_its_control_is_visible() -> void:
	# Given: A shown control with a scope.
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree.
	add_child_autofree(_control)

	# Then: The control is the focus root.
	assert_eq(_cursor.get_focus_root(), _control)

	# When: The control is hidden.
	_control.hide()

	# Then: The claim is released.
	assert_null(_cursor.get_focus_root())

	# When: The control is shown again.
	_control.show()

	# Then: The control is the focus root again.
	assert_eq(_cursor.get_focus_root(), _control)


func test_scope_covered_by_a_screen_releases_until_uncovered() -> void:
	# Given: A shown control with a scope, in the tree.
	var scope := StdInputCursorFocusScope.new()
	_control.add_child(scope)
	add_child_autofree(_control)

	# When: A screen covers it.
	scope.notification(StdScreenManager.NOTIFICATION_SCREEN_COVERED)

	# Then: The claim is released.
	assert_null(_cursor.get_focus_root())

	# When: The screen is uncovered.
	scope.notification(StdScreenManager.NOTIFICATION_SCREEN_UNCOVERED)

	# Then: The control is the focus root again.
	assert_eq(_cursor.get_focus_root(), _control)


func test_scope_in_a_panel_claims_only_while_the_panel_is_open() -> void:
	# Given: A hidden control with a panel and a scope, in the tree.
	_control.hide()
	var panel := StdPanel.new()
	_control.add_child(panel)
	_control.add_child(StdInputCursorFocusScope.new())
	add_child_autofree(_control)

	# Then: Nothing is claimed.
	assert_null(_cursor.get_focus_root())

	# When: The panel opens.
	panel.open()

	# Then: The control is the focus root.
	assert_eq(_cursor.get_focus_root(), _control)

	# When: The panel closes.
	panel.close()

	# Then: The claim is released.
	assert_null(_cursor.get_focus_root())


func test_scope_leaving_the_tree_releases_its_claim() -> void:
	# Given: A shown control with a scope, in the tree.
	_control.add_child(StdInputCursorFocusScope.new())
	add_child_autofree(_control)

	# When: The control leaves the tree.
	remove_child(_control)

	# Then: The claim is released.
	assert_null(_cursor.get_focus_root())


func test_scope_claiming_without_an_anchor_reports_it() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	_add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree while the cursor shows, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: The missing anchor is reported.
	assert_engine_error("missing focus anchor")


func test_scope_claiming_twice_in_one_frame_reports_its_missing_anchor_once() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	_add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree.
	add_child_autofree(_control)

	# When: It's hidden and shown again in the same frame, and the frame ends.
	_control.hide()
	_control.show()
	await wait_process_frames(1)

	# Then: The missing anchor is reported once.
	#
	# NOTE: GUT fails the test on any further engine error, such as a second report.
	assert_engine_error("missing focus anchor")


func test_scope_whose_anchor_is_set_in_the_claiming_frame_reports_nothing() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	var button := _add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree.
	add_child_autofree(_control)

	# When: The button is made an anchor in the same frame, and the frame ends.
	button.get_child(0).use_as_anchor = true
	await wait_process_frames(1)

	# Then: Nothing is reported.
	assert_engine_error_count(0)


func test_scope_whose_anchor_is_disabled_reports_nothing() -> void:
	# Given: A control with a scope, holding a disabled button which is an anchor.
	_add_button(true).disabled = true
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: Nothing is reported.
	assert_engine_error_count(0)


func test_scope_whose_only_anchor_is_hidden_reports_it() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	_add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# Given: A hidden button beside it which is an anchor.
	_add_button(true).hide()

	# When: It enters the tree, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: The missing anchor is reported.
	assert_engine_error("missing focus anchor")


func test_scope_whose_only_anchor_is_in_a_closed_sub_panel_reports_it() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	_add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# Given: A hidden sub-panel with its own scope, holding a button which is an anchor.
	_add_sub_panel().hide()

	# When: It enters the tree, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: The missing anchor is reported.
	assert_engine_error("missing focus anchor")


func test_scope_whose_only_anchor_is_in_an_open_sub_panel_reports_it() -> void:
	# Given: A control with a scope, holding a button whose handler isn't an anchor.
	_add_button(false)
	_control.add_child(StdInputCursorFocusScope.new())

	# Given: A shown sub-panel with its own scope, holding a button which is an anchor.
	_add_sub_panel()

	# When: It enters the tree, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: The missing anchor is reported once, for the outer control.
	#
	# NOTE: GUT fails the test on any further engine error, such as a second report.
	assert_engine_error("missing focus anchor")


func test_scope_without_focus_handlers_reports_nothing() -> void:
	# Given: A control with a scope, holding only a label.
	_control.add_child(Label.new())
	_control.add_child(StdInputCursorFocusScope.new())

	# When: It enters the tree, and the frame ends.
	add_child_autofree(_control)
	await wait_process_frames(1)

	# Then: Nothing is reported.
	assert_engine_error_count(0)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_cursor = StdInputCursor.new()
	add_child_autofree(_cursor)

	_control = Control.new()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _add_button adds a focusable button to `parent`, else `_control`, with a focus
## handler, an anchor if `anchor` is set, and returns it.
func _add_button(anchor: bool, parent: Control = null) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	(parent if parent else _control).add_child(button)
	var handler := StdInputCursorFocusHandler.new()
	handler.use_as_anchor = anchor
	button.add_child(handler)
	return button


## _add_sub_panel adds a control to `_control` with its own scope, holding a button
## which is an anchor, and returns it.
func _add_sub_panel() -> Control:
	var sub_panel := Control.new()
	_control.add_child(sub_panel)
	_add_button(true, sub_panel)
	sub_panel.add_child(StdInputCursorFocusScope.new())
	return sub_panel
