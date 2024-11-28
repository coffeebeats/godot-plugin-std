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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _options: Array = []

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return


func _exit_tree() -> void:
	if _target.item_selected.is_connected(_on_OptionButton_item_selected):
		_target.item_selected.disconnect(_on_OptionButton_item_selected)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()

	if not _get_options_property() is StdSettingsProperty:
		warnings.append("invalid config: missing options property")
	elif not _get_options_property().scope is StdSettingsScope:
		warnings.append("invalid config: missing 'scope' for options property")

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

	var err := options_property.value_changed.connect(
		func(v): _rebuild_options(Array(v))
	)
	assert(err == OK, "failed to connect to signal")

	err = property.value_changed.connect(_select_value)
	assert(err == OK, "failed to connect to signal")

	if not _target.item_selected.is_connected(_on_OptionButton_item_selected):
		err = _target.item_selected.connect(_on_OptionButton_item_selected)
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_options_property() -> StdSettingsProperty:
	assert(false, "unimplemented")
	return null


func _is_valid_target() -> bool:
	return _target is OptionButton


func _set_initial_value(value: Variant) -> void:
	var options_property := _get_options_property()
	assert(
		options_property is StdSettingsProperty,
		"invalid state: missing options property",
	)

	_rebuild_options(Array(options_property.get_value()))
	_select_value(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _rebuild_options(options: Array) -> void:
	assert(
		options is Array and not options.is_empty(),
		"invalid argument; missing options",
	)

	_options = options

	_target.clear()
	_target.disabled = len(options) <= 1

	for option in options:
		_target.add_item(formatter.format_option(option) if formatter else str(option))


func _select_value(value) -> void:
	assert(
		_options is Array and not _options.is_empty(),
		"invalid state; missing options",
	)

	assert(value in _options, "invalid config: value not in options")

	var index: int = 0
	for option in _options:
		if option == value:
			_target.select(index)
			break

		index += 1


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_OptionButton_item_selected(index: int) -> void:
	assert(
		_options is Array and not _options.is_empty(),
		"invalid state; missing options",
	)

	assert(
		index >= 0 and index < _options.size(),
		"invalid argument: index out of range",
	)

	_set_value(_options[index])
