##
## std/setting/controller_option_button.gd
##
## `StdSettingsControllerOptionButton` is a class which allows driving an `OptionButton`
## node using the provided `StdSettingsScope` and `StdSettingsPropertyFloatRange`.
##

@tool
class_name StdSettingsControllerOptionButton
extends StdSettingsController

# -- CONFIGURATION ------------------------------------------------------------------- #

## `options_property` is a settings property defining the list of options to choose
## from. To customize how those options are displayed, override `_map_option_to_string`.
@export var options_property: StdSettingsProperty = null:
	set(value):
		property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _target.item_selected.is_connected(_on_OptionButton_item_selected):
		_target.item_selected.disconnect(_on_OptionButton_item_selected)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if not options_property is StdSettingsProperty:
		(
			warnings
			. append(
				"missing or invalid property: options (expected a 'StdSettingsProperty'",
			)
		)
	elif not _is_valid_options_property():
		warnings.append("invalid type: property")

	return warnings


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	assert(_is_valid_options_property(), "invalid type: options_property")

	var repository := scope.get_repository()
	assert(repository is StdSettingsRepository, "missing repository")
	if repository is StdSettingsRepository:
		repository.notify_on_change([options_property], _initialize)

	if not _target.item_selected.is_connected(_on_OptionButton_item_selected):
		var err: Error = _target.item_selected.connect(_on_OptionButton_item_selected)
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _is_valid_property() -> bool:
	return property is StdSettingsPropertyStringOneOf


func _is_valid_options_property() -> bool:
	return property is StdSettingsPropertyStringOneOf


func _is_valid_target() -> bool:
	return _target is OptionButton


func _map_option_to_string(value: Variant) -> String:
	return value if value is String else str(value)


func _set_initial_value(value: Variant) -> void:
	_target.clear()

	var options := Array(options_property.get_value_from_config(scope.config))
	assert(options.has(value), "invalid config: value not in options")

	for option in options:
		_target.add_item(_map_option_to_string(option))
		if option == value:
			_target.select(_target.item_count - 1)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_OptionButton_item_selected(index: int) -> void:
	assert(
		index >= 0 and index < property.allowed_values.size(),
		"invalid argument: index out of range",
	)

	_set_value(property.allowed_values[index])
