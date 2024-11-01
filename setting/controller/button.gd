##
## std/setting/controller/button.gd
##
## SettingsButtonController allows for synchronizing a button with the specified
## 'SettingsRepository'. Note that this implementation requires that the button is set
## to use 'toggle_mode', as the toggle state is interpreted as a boolean value.
##

class_name SettingsButtonController
extends "controller.gd"

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a 'SettingsBoolProperty' to scope changes to.
@export var property: SettingsBoolProperty = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _exit_tree() -> void:
    if _target.toggled.is_connected(_on_BaseButton_toggled):
        _target.value_changed.disconnect(_on_BaseButton_toggled)

func _enter_tree() -> void:
    assert(_target is BaseButton, "invalid target type, expected a BaseButton node")
    assert(_target.toggle_mode, "invalid state; expected toggle button")
    assert(
        property is SettingsBoolProperty,
        "invalid configuration; missing property: property",
    )

    if not _target.toggled.is_connected(_on_BaseButton_toggled):
        _target.toggled.connect(_on_BaseButton_toggled)

func _ready() -> void:
    var value: float = property.get_value_from_config(_repository.config)
    assert(value is float, "invalid value type from property")

    _target.value = value

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_BaseButton_toggled(value: bool) -> void:
    property.set_value_on_config(_repository.config, value)

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
