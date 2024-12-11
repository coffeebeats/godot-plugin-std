##
## std/feature/condition.gd
##
## StdCondition is an abstract base class for nodes which conditionally place target
## nodes within the scene.
##

class_name StdCondition
extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## condition_changed is emitted when one of the condition's property dependencies has
## changed.
signal condition_changed(value: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## allow is a settings property which defines what the "allow" condition evaluates to.
@export var allow: StdSettingsPropertyBool = null

## block is a settings property which defines what the "block" condition evaluates to.
## Note that if both `block` and `allow` evaluate to `true`, `block` takes priority and
## the condition fails.
@export var block: StdSettingsPropertyBool = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_enabled: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
	assert(allow or block, "invalid state; missing at least one settings property")

	if allow:
		Signals.connect_safe(allow.value_changed, _on_settings_property_value_changed)
	if block:
		Signals.connect_safe(block.value_changed, _on_settings_property_value_changed)

	_on_settings_property_value_changed()

func _exit_tree() -> void:
	if allow:
		Signals.disconnect_safe(allow.value_changed, _on_settings_property_value_changed)
	if block:
		Signals.disconnect_safe(block.value_changed, _on_settings_property_value_changed)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _on_allow() -> void:
	pass

func _on_block() -> void:
	pass

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_settings_property_value_changed() -> void:
	var is_enabled := false

	if block and not block.get_value():
		is_enabled = true

	if not is_enabled and allow and allow.get_value():
		is_enabled = true

	if is_enabled != _is_enabled:
		_is_enabled = is_enabled
		condition_changed.emit(_is_enabled)
