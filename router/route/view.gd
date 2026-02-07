##
## router/route/view.gd
##
## StdRouteView is a route that renders its scene in the configured content area. Top-
## level views render in the router's content root, while nested views render in the
## parent scene's `StdRouteContainer` node with ViewType.VIEW_TYPE_CONTENT.
##

@tool
class_name StdRouteView
extends StdRouteRenderable
