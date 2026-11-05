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


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	_cursor = StdInputCursor.new()
	add_child_autofree(_cursor)

	_control = Control.new()
