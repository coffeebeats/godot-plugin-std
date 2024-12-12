##
## std/condition/expression_feature.gd
##
## StdConditionExpressionFeature is an `StdConditionExpression` implementation which
## checks for the presence of an application feature.
##

class_name StdConditionExpressionFeature
extends StdConditionExpression


# -- CONFIGURATION ------------------------------------------------------------------- #

## feature is the name of an application feature to check during evaluation.
@export var feature: StringName = ""

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

func _is_allowed() -> bool:
	return OS.has_feature(feature)
