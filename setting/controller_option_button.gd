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
		options_property = value
		update_configuration_warnings()

## `formatter` is a type which describes how to format the options available to this
## `OptionButton` node. The formatter should accept types returned by `options_property`
## and return a `String`.
@export var formatter: StdSettingsControllerOptionButtonFormatter = null

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
				"missing or invalid property: options (expected a 'StdSettingsProperty')",
			)
		)
	elif not _is_valid_options_property():
		warnings.append("invalid type: options property")

	return warnings


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	if Engine.is_editor_hint():
		return

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
	assert(false, "unimplemented")
	return false


func _is_valid_options_property() -> bool:
	assert(false, "unimplemented")
	return false


func _is_valid_target() -> bool:
	return _target is OptionButton


func _set_initial_value(value: Variant) -> void:
	_target.clear()

	var options := _get_options()
	assert(options.has(value), "invalid config: value not in options")

	for option in options:
		_target.add_item(formatter.format_option(option) if formatter else str(option))
		if option == value:
			_target.select(_target.item_count - 1)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_options() -> Array:
	return Array(options_property.get_value_from_config(scope.config))


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_OptionButton_item_selected(index: int) -> void:
	var options := _get_options()

	assert(
		index >= 0 and index < options.size(),
		"invalid argument: index out of range",
	)

	_set_value(options[index])
