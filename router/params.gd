##
## router/params.gd
##
## A base class for type-safe, serializable route parameters. Extends `StdConfigItem` to
## inherit automatic serialization via property reflection. Typed params are typically
## defined as inner classes on typed handles. For example:
##
## ```gd
## class_name SettingsMenuHandle
## extends StdRouteHandle
##
## class Params:
##   extends StdRouteParams
##
## 	 var tab: int = 0
## 	 var scroll_position: float = 0.0
##
## 	 func _init(p_tab: int = 0, p_scroll: float = 0.0) -> Params:
## 		var p := Params.new()
## 		p.tab = p_tab
## 		p.scroll_position = p_scroll
## 		return p
## ```
##
## Standalone `StdRouteParams` classes are also supported for shared parameter types
## used by multiple routes.
##

class_name StdRouteParams
extends StdConfigItem

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return &"route_params"
