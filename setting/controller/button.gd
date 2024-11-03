##
## std/setting/controller/button.gd
##
## SettingsButtonController allows for synchronizing a button with the specified
## 'SettingsRepository'. Note that this implementation requires that the button is set
## to use 'toggle_mode', as the toggle state is interpreted as a boolean value.
##

@tool
class_name SettingsButtonController
extends SettingsController

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a 'SettingsBoolProperty' to scope changes to.
@export var property: SettingsBoolProperty = null:
	set(value):
		property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _target.toggled.is_connected(_on_BaseButton_toggled):
		_target.value_changed.disconnect(_on_BaseButton_toggled)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()

	if property is not SettingsBoolProperty:
		out.append("Invalid config; expected 'SettingsBoolProperty' for 'property'!")

	return out


func _ready() -> void:
	assert(_target is BaseButton, "invalid target type, expected a BaseButton node")
	assert(_target.toggle_mode, "invalid state; expected toggle button")
	assert(
		property is SettingsBoolProperty,
		"invalid configuration; missing property: property",
	)

	if not _target.toggled.is_connected(_on_BaseButton_toggled):
		_target.toggled.connect(_on_BaseButton_toggled)

	var value: float = property.get_value_from_config(_repository.config)
	assert(value is float, "invalid value type from property")

	_target.value = value


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_BaseButton_toggled(value: bool) -> void:
	property.set_value_on_config(_repository.config, value)
