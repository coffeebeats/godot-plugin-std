##
## std/setting/repository/observer.gd
##
## SettingsRepositoryObserver is a type which listens to changes to the specified
## settings properties.
##

class_name SettingsRepositoryObserver
extends Resource

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_settings_properties returns the list of 'SettingsProperty' instances for which
## this observer should be notified on changes to.
func get_settings_properties() -> Array[SettingsProperty]:
	return _get_settings_properties()


## handle_value_change is called when a property that this observer is registered for
## has changed.
func handle_value_change(property: SettingsProperty, value: Variant) -> void:
	return _handle_value_change(property, value)


## mount_observer_node creates a 'Node' which should be added to the scene tree for the
## purpose of providing a hook to the observer. If the returned node is null, then no
## node will be added.
func mount_observer_node() -> Node:
	return _mount_observer_node()


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[SettingsProperty]:
	assert(false, "unimplemented")
	return []


func _handle_value_change(_property: SettingsProperty, _value) -> void:
	assert(false, "unimplemented")


func _mount_observer_node() -> Node:
	return null
