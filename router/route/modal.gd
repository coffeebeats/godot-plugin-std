##
## router/route/modal.gd
##
## StdRouteModal is an overlay route that renders on top of content. Modals are
## typically used for dialogs, pause menus, settings screens, and other UI that should
## appear above the main content while optionally blocking interaction with the view
## below.
##
## Modal configuration controls the StdRouterOverlay wrapper created by the router,
## including backdrop appearance and close trigger behavior.
##

@tool
class_name StdRouteModal
extends StdRouteRenderable

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Overlay")

## backdrop_mouse_filter controls how the overlay handles mouse input. Set to
## MOUSE_FILTER_STOP to block input to nodes behind the overlay.
@export var backdrop_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP

## close_on_backdrop is a bitmask of mouse buttons that close the modal when clicking
## the backdrop. Use MouseButtonMask values (e.g., MOUSE_BUTTON_MASK_LEFT).
@export_flags("Left:1", "Right:2", "Middle:4") var close_on_backdrop: int = 0

## close_action is the input action that closes the modal. If empty, no action will
## trigger close. Defaults to "ui_cancel" for standard escape-to-close behavior.
@export var close_action: StringName = &"ui_cancel"
