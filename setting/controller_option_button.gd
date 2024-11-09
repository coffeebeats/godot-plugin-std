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

	if not _get_options_property() is StdSettingsProperty:
		warnings.append("invalid config: missing options property")

	return warnings


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	if Engine.is_editor_hint():
		return

	var property := _get_property()
	assert(
		property is StdSettingsProperty,
		"invalid state: missing property",
	)

	var options_property := _get_options_property()
	assert(
		options_property is StdSettingsProperty,
		"invalid state: missing options property",
	)

	var repository := scope.get_repository()
	assert(repository is StdSettingsRepository, "missing repository")
	if repository is StdSettingsRepository:
		repository.notify_on_change(
			[options_property], func(_property, _value): _rebuild_options()
		)
		repository.notify_on_change(
			[property], func(_property, value): _select_value(value)
		)

	if not _target.item_selected.is_connected(_on_OptionButton_item_selected):
		var err: Error = _target.item_selected.connect(_on_OptionButton_item_selected)
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_options_property() -> StdSettingsProperty:
	assert(false, "unimplemented")
	return null


func _is_valid_target() -> bool:
	return _target is OptionButton


func _set_initial_value(value: Variant) -> void:
	_rebuild_options()
	_select_value(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _get_options() -> Array:
	var options_property := _get_options_property()
	assert(
		options_property is StdSettingsProperty,
		"invalid state: missing options property",
	)

	return Array(options_property.get_value_from_config(scope.config))


func _rebuild_options() -> void:
	_target.clear()

	var options := _get_options()

	for option in options:
		_target.add_item(formatter.format_option(option) if formatter else str(option))


func _select_value(value) -> void:
	var options := _get_options()
	assert(options.has(value), "invalid config: value not in options")

	for option in options:
		if option == value:
			_target.select(_target.item_count - 1)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_OptionButton_item_selected(index: int) -> void:
	var options := _get_options()

	assert(
		index >= 0 and index < options.size(),
		"invalid argument: index out of range",
	)

	_set_value(options[index])
