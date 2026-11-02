##
## std/input/action_hold.gd
##
## StdInputActionHold declares that an action runs as a hold, a gesture over the
## action's press and release. A set or layer lists it in `holds`, and a `StdInputSlot`
## runs it and reports it through its `action_hold_*` signals.
##

@tool
class_name StdInputActionHold
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #

## Mode is how a player performs a hold.
##
## NOTE: A settings property stores these values, so they must not be renumbered.
enum Mode {
	## INHERIT makes no choice, so a settings property holding it defers to the hold's next
	## source of a mode, and `mode` holding it runs as `HOLD`. It's `0` because that's
	## what a `StdSettingsPropertyInt` reads when no default is set and nothing is stored.
	INHERIT = 0,
	## HOLD is active while the input is held, and cancels on a release before the fill.
	HOLD = 1,
	## TOGGLE becomes active on a tap and stays active until a second tap of `action`, or
	## a press of `cancel_action`. With a duration it's a charge that completes on its
	## own, and with a duration of `0` it's an on/off toggle.
	TOGGLE = 2,
	## PRESS triggers on the press. A sustained action has no press form, so at a duration
	## of `0` it runs as `HOLD`.
	PRESS = 3,
}

const MODE_INHERIT := Mode.INHERIT
const MODE_HOLD := Mode.HOLD
const MODE_TOGGLE := Mode.TOGGLE
const MODE_PRESS := Mode.PRESS

# -- CONFIGURATION ------------------------------------------------------------------- #

## action is the name of the action the hold runs over, which the sets active with this
## hold must declare.
@export var action: StringName = &""

## duration is how long (in seconds) the hold takes to fill. A value of `0` makes it
## active from the press, which is what a sustained action such as aiming uses.
@export var duration: float = 0.0

## cancel_action is the name of an action whose press also ends an active `MODE_TOGGLE`
## hold, beside a second tap of `action`. When empty, only that second tap ends it.
##
## NOTE: The sets active with this hold must declare it, or nothing can press it.
@export var cancel_action: StringName = &""

@export_group("Mode")

## mode is the `Mode` the hold runs in when no settings property chooses one, neither
## its `mode_override` nor the `StdInputSlot`'s `hold_confirm_mode_property` or
## `hold_sustain_mode_property`.
@export var mode: Mode = MODE_HOLD

## mode_override is an optional settings property which, while it holds anything but
## `MODE_INHERIT`, decides the hold's `Mode` over the slot's properties and `mode`. It
## lets one group of holds offer the player its own choice.
##
## NOTE: The property should default to `MODE_INHERIT` and offer it, since any other
## default overrides a player's general setting. The game's default goes in `mode`.
##
## NOTE: The options must keep `MODE_TOGGLE`, the alternative to a sustained hold that
## Game Accessibility Guidelines and Xbox XAG 107 ask for. Nothing checks this.
@export var mode_override: StdSettingsPropertyInt = null

## allow_press defines whether the hold can run in `MODE_PRESS`. A destructive confirm
## sets this to `false`, so `MODE_PRESS` runs as `MODE_TOGGLE`, whichever source chose
## it, and a tap can't skip `duration`.
##
## NOTE: In `MODE_TOGGLE`, a stray tap still triggers the hold once it fills, unless a
## second tap of `action` or a press of `cancel_action` ends it first.
@export var allow_press: bool = true
