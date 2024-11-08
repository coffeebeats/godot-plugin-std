##
## std/setting/controller_range.gd
##
## `StdSettingsControllerRange` is a class which allows driving a `Range` node using the
## provided `StdSettingsScope` and `StdSettingsPropertyFloatRange`.
##

@tool
class_name StdSettingsControllerRange
extends StdSettingsController

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a settings property defining which configuration property to update.
@export var property: StdSettingsPropertyBool = null:
	set(value):
		property = value
		update_configuration_warnings()

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _target.value_changed.is_connected(_on_Range_value_changed):
		_target.value_changed.disconnect(_on_Range_value_changed)


func _ready() -> void:
	# NOTE: Call first to set initial value prior to signal connection, avoiding an
	# extra set operation from the controller.
	super._ready()

	if Engine.is_editor_hint():
		return

	if not _target.value_changed.is_connected(_on_Range_value_changed):
		var err: Error = _target.value_changed.connect(_on_Range_value_changed)
		assert(err == OK, "failed to connect to signal")


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_property() -> StdSettingsProperty:
	return property


func _is_valid_target() -> bool:
	return _target is Range


func _set_initial_value(value: Variant) -> void:
	assert(value is float, "invalid argument: wrong value type")

	_target.value = value
	_target.min_value = property.minimum
	_target.max_value = property.maximum
	_target.step = property.step


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Range_value_changed(value: float) -> void:
	_set_value(value)
