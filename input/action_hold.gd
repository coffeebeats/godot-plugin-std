##
## std/input/action_hold.gd
##
## StdInputActionHold declares that an action runs as a hold, a gesture over the
## action's press and release. A set or layer lists it in `holds`, and it's live exactly
## while that set is loaded or that layer enabled. The action stays an ordinary action,
## so a hold has no `InputMap` entry, binding or Steam manifest entry of its own.
##

@tool
class_name StdInputActionHold
extends Resource

# -- DEFINITIONS --------------------------------------------------------------------- #

## Mode is how a player performs a hold.
##
## NOTE: A settings property stores these values, so they must not be renumbered.
enum Mode {
	## HOLD is active while the input is held, and cancels on a release before the fill.
	HOLD = 0,
	## TOGGLE becomes active on a tap and stays active until a second tap of `action`, or
	## a press of `cancel_action`. With a duration it's a charge that completes on its
	## own, and with a duration of `0` it's an on/off toggle.
	TOGGLE = 1,
	## PRESS triggers on the press.
	PRESS = 2,
}

const MODE_HOLD := Mode.HOLD
const MODE_TOGGLE := Mode.TOGGLE
const MODE_PRESS := Mode.PRESS

# -- CONFIGURATION ------------------------------------------------------------------- #

## action is the name of the action the hold runs over.
@export var action: StringName = &""

## duration is how long (in seconds) the hold takes to fill. A value of `0` makes it
## active from the press, which is what a sustained action such as aiming uses.
@export var duration: float = 0.0

## cancel_action is the name of an action whose press also ends an active `MODE_TOGGLE`
## hold, beside a second tap of `action`. When empty, only that second tap ends it.
@export var cancel_action: StringName = &""

@export_group("Mode")

## mode is the `Mode` the hold runs in when no settings property chooses one.
@export var mode: Mode = MODE_HOLD

## mode_override is an optional settings property which, when set, decides the hold's
## `Mode` in place of `mode`. It lets one group of holds offer the player its own
## choice.
##
## NOTE: A destructive confirm forbids `MODE_PRESS` by naming a property whose options
## leave it out. The options must keep `MODE_TOGGLE`, the alternative to a sustained
## hold that the accessibility guidelines ask for.
@export var mode_override: StdSettingsPropertyInt = null
