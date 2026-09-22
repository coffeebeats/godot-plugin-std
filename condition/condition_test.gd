##
## Tests pertaining to the `StdCondition` class and its expressions.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## FakeExpression is an expression whose value a test sets directly.
class FakeExpression:
	extends StdConditionExpression

	var value: bool = false

	func _init(initial: bool = false) -> void:
		value = initial

	func set_value(next: bool) -> void:
		value = next
		value_changed.emit(next)

	func _is_allowed() -> bool:
		return value


# -- TEST METHODS -------------------------------------------------------------------- #


func test_condition_allow_any_with_one_true_shows_target() -> void:
	# Given: A condition with one true and one false allow expression.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([false, true])

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is visible.
	assert_true(target.visible)


func test_condition_allow_any_with_all_false_hides_target() -> void:
	# Given: A condition whose allow expressions are all false.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([false, false])

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_allow_all_with_one_false_hides_target() -> void:
	# Given: A condition requiring every allow expression, one of which is false.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true, false])
	condition.expressions_allow_require_all = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_allow_all_with_all_true_shows_target() -> void:
	# Given: A condition requiring every allow expression, all of which are true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true, true])
	condition.expressions_allow_require_all = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is visible.
	assert_true(target.visible)


func test_condition_without_expressions_hides_target() -> void:
	# Given: A condition with no expressions at all.
	var condition := StdConditionTarget2D.new()

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_block_any_with_one_true_hides_target() -> void:
	# Given: A condition whose allow expression is true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true])

	# Given: One true and one false block expression.
	condition.expressions_block = _expressions([false, true])

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_block_any_with_all_false_shows_target() -> void:
	# Given: A condition whose allow expression is true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true])

	# Given: Block expressions which are all false.
	condition.expressions_block = _expressions([false, false])

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is visible.
	assert_true(target.visible)


func test_condition_block_all_with_all_true_hides_target() -> void:
	# Given: A condition whose allow expression is true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true])

	# Given: It requires every block expression, all of which are true.
	condition.expressions_block = _expressions([true, true])
	condition.expressions_block_require_all = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_block_all_with_one_false_shows_target() -> void:
	# Given: A condition whose allow expression is true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true])

	# Given: It requires every block expression, one of which is false.
	condition.expressions_block = _expressions([true, false])
	condition.expressions_block_require_all = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is visible.
	assert_true(target.visible)


func test_condition_force_block_with_force_allow_hides_target() -> void:
	# Given: A condition which is both forced to allow and forced to block.
	var condition := StdConditionTarget2D.new()
	condition.force_allow = true
	condition.force_block = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is hidden.
	assert_false(target.visible)


func test_condition_force_allow_without_expressions_shows_target() -> void:
	# Given: A condition forced to allow, with no expressions.
	var condition := StdConditionTarget2D.new()
	condition.force_allow = true

	# When: It enters the scene tree.
	var target := _place(condition)

	# Then: The target is visible.
	assert_true(target.visible)


func test_condition_block_expression_changing_toggles_target() -> void:
	# Given: A condition whose allow expression is true.
	var condition := StdConditionTarget2D.new()
	condition.expressions_allow = _expressions([true])

	# Given: A block expression which starts out false.
	var block := FakeExpression.new(false)
	condition.expressions_block = [block]

	# Given: The condition is in the scene tree, showing its target.
	var target := _place(condition)
	assert_true(target.visible)

	# When: The block expression becomes true.
	block.set_value(true)

	# Then: The target is hidden.
	assert_false(target.visible)

	# When: The block expression becomes false again.
	block.set_value(false)

	# Then: The target is visible again.
	assert_true(target.visible)


func test_feature_expression_with_present_feature_is_allowed() -> void:
	# Given: An expression checking for the editor feature, which a test run has.
	var expression := StdConditionExpressionFeature.new()
	expression.feature = &"editor"

	# When: The expression is evaluated.
	var got := expression.is_allowed()

	# Then: It is allowed.
	assert_true(got)


func test_feature_expression_with_absent_feature_is_blocked() -> void:
	# Given: An expression checking for a feature no build has.
	var expression := StdConditionExpressionFeature.new()
	expression.feature = &"std-condition-test-missing"

	# When: The expression is evaluated.
	var got := expression.is_allowed()

	# Then: It is blocked.
	assert_false(got)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _expressions(values: Array[bool]) -> Array[StdConditionExpression]:
	var expressions: Array[StdConditionExpression] = []
	for value in values:
		expressions.append(FakeExpression.new(value))
	return expressions


## _place adds the condition to the scene tree over a new target, which starts out
## visible, and returns that target.
func _place(condition: StdConditionTarget2D) -> Control:
	var target: Control = autofree(Control.new())
	condition.targets = [target]
	add_child_autofree(condition)
	return target
