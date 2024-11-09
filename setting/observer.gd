##
## std/setting/observer.gd
##
## `StdSettingsObserver` is a type which listens to changes to the specified settings
## properties.
##

class_name StdSettingsObserver
extends Resource

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Config := preload("../config/config.gd")

# -- DEFINITION ---------------------------------------------------------------------- #


## `PropertyCallable` is a simple `StdSettingsObserver` which defers to the provided
## callable. The callable's signature must match
## `StdSettingsObserver.handle_value_change`.
class PropertyCallable:
	extends StdSettingsObserver

	var callable: Callable

	func _handle_value_change(
		_config: Config, property: StdSettingsProperty, value: Variant
	) -> void:
		assert(callable is Callable, "invalid config: missing callable")
		callable.call(property, value)


# -- CONFIGURATION ------------------------------------------------------------------- #

## should_call_on_value_loaded controls whether this observer will be called when one of
## the matching properties is first loaded from disk.
@export var should_call_on_value_loaded: bool = true

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_settings_properties returns the list of 'SettingsProperty' instances for which
## this observer should be notified on changes to.
func get_settings_properties() -> Array[StdSettingsProperty]:
	return _get_settings_properties()


## handle_value_change is called when a property that this observer is registered for
## has changed.
func handle_value_change(
	config: Config, property: StdSettingsProperty, value: Variant
) -> void:
	return _handle_value_change(config, property, value)


## mount_observer_node creates a 'Node' which should be added to the scene tree for the
## purpose of providing a hook to the observer. If the returned node is null, then no
## node will be added.
func mount_observer_node() -> Node:
	return _mount_observer_node()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(false, "unimplemented")
	return []


func _handle_value_change(
	_config: Config, _property: StdSettingsProperty, _value
) -> void:
	assert(false, "unimplemented")


func _mount_observer_node() -> Node:
	return null
