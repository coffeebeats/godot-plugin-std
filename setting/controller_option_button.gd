##
## std/setting/controller_option_button.gd
##
## `StdSettingsControllerOptionButton` is a class which allows driving an `OptionButton`
## node using the provided `StdSettingsScope` and `StdSettingsPropertyFloatRange`.
##

@tool
class_name StdSettingsControllerOptionButton
extends StdSettingsController

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	super._exit_tree()

	if _target.item_selected.is_connected(_on_OptionButton_item_selected):
		_target.item_selected.disconnect(_on_OptionButton_item_selected)


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	if not _target.item_selected.is_connected(_on_OptionButton_item_selected):
		var err: Error = _target.item_selected.connect(_on_OptionButton_item_selected)
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_valid_property() -> bool:
	return property is StdSettingsPropertyStringOneOf


func _is_valid_target() -> bool:
	return _target is OptionButton


func _set_initial_value(value: Variant) -> void:
	assert(value is String, "invalid argument: wrong value type")

	_target.clear()

	for allowed_value in property.allowed_values:
		_target.add_item(allowed_value)
		if allowed_value == value:
			_target.select(_target.item_count - 1)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_OptionButton_item_selected(value: float) -> void:
	_set_value(value)
