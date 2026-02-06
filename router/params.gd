##
## router/params.gd
##
## StdRouteParams is a base class for type-safe, serializable route parameters. Extends
## `StdConfigItem` to inherit automatic serialization via property reflection.
## Parameters are defined as standalone classes and attached to routes via the `params`
## export property.
##
## The route's params instance serves as a frozen schema: calling `clone()` produces a
## mutable copy that can be populated and passed to navigation methods. For example:
##
## ```gd
## class_name SettingsMenuParams
## extends StdRouteParams
##
## var tab: int = 0
## var scroll_position: float = 0.0
## ```
##
## Then attach an instance to a route's `params` export in the inspector. Navigate with:
##
## ```gd
## var p := route.params.clone() as SettingsMenuParams
## p.tab = 2
## route.push(p)
## ```
##

class_name StdRouteParams
extends StdConfigItem

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return &"route_params"
