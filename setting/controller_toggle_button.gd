##
## std/setting/controller_toggle_button.gd
##
## `StdSettingsControllerToggleButton` is a class which allows driving a `Button` node,
## configured as a toggle switch, using the provided `StdSettingsScope` and
## `StdSettingsPropertyBool`.
##

@tool
class_name StdSettingsControllerToggleButton
extends StdSettingsController

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a settings property defining which configuration property to update.
@export var property: StdSettingsPropertyBool = null:
	set(value):
		property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _target.toggled.is_connected(_on_BaseButton_toggled):
		_target.toggled.disconnect(_on_BaseButton_toggled)


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	if Engine.is_editor_hint():
		return

	if not _target.toggled.is_connected(_on_BaseButton_toggled):
		var err: Error = _target.toggled.connect(_on_BaseButton_toggled)
		assert(err == OK, "failed to connect to signal")

	if not property.value_changed.is_connected(_set_initial_value):
		var err: Error = property.value_changed.connect(_set_initial_value) as Error
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	return property


func _is_valid_target() -> bool:
	return _target is CheckBox or _target is CheckButton


func _set_enabled(value: bool) -> void:
	_target.disabled = not value

func _set_initial_value(value: Variant) -> void:
	assert(value is bool, "invalid argument: wrong value type")

	_target.button_pressed = value


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_BaseButton_toggled(value: bool) -> void:
	_set_value(value)
