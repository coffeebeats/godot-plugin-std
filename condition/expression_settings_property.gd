##
## std/condition/expression_settings_property.gd
##
## StdConditionExpressionSettingsProperty is an `StdConditionExpression` implementation
## which allows/denies based on the provided `StdSettingsProperty` instances.
##

class_name StdConditionExpressionSettingsProperty
extends StdConditionExpression

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

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _setup() -> void:
	assert(allow or block, "invalid state; missing at least one settings property")

	if allow:
		Signals.connect_safe(allow.value_changed, _on_settings_property_value_changed)
	if block:
		Signals.connect_safe(block.value_changed, _on_settings_property_value_changed)


func _teardown() -> void:
	if allow:
		Signals.disconnect_safe(
			allow.value_changed, _on_settings_property_value_changed
		)
	if block:
		Signals.disconnect_safe(
			block.value_changed, _on_settings_property_value_changed
		)

func _is_allowed() -> bool:
	var is_enabled := false

	if block and not block.get_value():
		is_enabled = true

	if not is_enabled and allow and allow.get_value():
		is_enabled = true
	
	return is_enabled

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_settings_property_value_changed() -> void:
	var is_enabled := _is_allowed()

	if is_enabled == _is_enabled:
		return

	_is_enabled = is_enabled

	value_changed.emit(is_enabled)
