##
## std/setting/controller/range.gd
##
## SettingsRangeController allows for synchronizing a 'Range' slider with the specified
## 'SettingsRepository'.
##

class_name SettingsRangeController
extends SettingsController

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a 'SettingsFloatProperty' to scope changes to.
@export var property: SettingsFloatProperty = null:
	set(value):
		property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _target.value_changed.is_connected(_on_Range_value_changed):
		_target.value_changed.disconnect(_on_Range_value_changed)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if property is not SettingsFloatProperty:
		out.append("Invalid config; expected 'SettingsFloatProperty' for 'property'!")

	return out


func _ready() -> void:
	assert(_target is Range, "invalid target type, expected a Range node")
	assert(
		property is SettingsFloatProperty,
		"invalid configuration; missing property: property",
	)

	if not _target.value_changed.is_connected(_on_Range_value_changed):
		_target.value_changed.connect(_on_Range_value_changed)

	var value: float = property.get_value_from_config(_repository.config)
	assert(value is float, "invalid value type from property")

	_target.value = value


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Range_value_changed(value: float) -> void:
	property.set_value_on_config(_repository.config, value)
