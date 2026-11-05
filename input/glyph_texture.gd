##
## std/input/glyph_texture.gd
##
## StdInputGlyphTexture is a texture which draws the glyph of the origin bound to an
## action, following its player's active device, bindings and keyboard layout. Any host
## which takes a texture can show it, such as a `TextureRect`, a `Button` icon or an
## `[img]` in a `RichTextLabel`, and each redraws on the texture's `changed` signal.
##
## NOTE: A resource has no `_enter_tree`, so the texture finds its player's slot when it
## is first measured or drawn. A host calls `update` in its `_ready` to bind sooner.
##

@tool
class_name StdInputGlyphTexture
extends Texture2D

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("../event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## Fallback is what the texture draws when the active device's category has no binding
## for the action.
enum Fallback {  # gdlint:ignore=class-definitions-order
	NONE,  ## Draws nothing at the texture's size.
	OTHER_CATEGORY,  ## Draws the other device category's binding.
	HIDE,  ## Draws nothing and reports a zero size, so a host can collapse.
}

const DeviceType := StdInputDevice.DeviceType  # gdlint:ignore=constant-name
const DEVICE_TYPE_GENERIC := StdInputDevice.DEVICE_TYPE_GENERIC
const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Action")

## action_set is the action set which defines `action`.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value
		_restart()

## action is the name of the action whose glyph is drawn.
@export var action := &"":
	set(value):
		action = value
		_restart()

## binding_index is the binding (e.g. primary or secondary) drawn first. An unbound
## index is skipped, so the texture draws the next binding instead.
@export var binding_index: int = 0:
	set(value):
		binding_index = value
		_restart()

## player_id is the player whose `StdInputSlot` supplies the bindings and device.
@export var player_id: int = 1:
	set(value):
		_unbind()
		player_id = value
		_restart()

@export_group("Device")

## device_type locks the glyph to a device type; `DEVICE_TYPE_UNKNOWN` follows the
## active device, and `DEVICE_TYPE_GENERIC` locks a controller of the player's chosen
## family in `device_type_override`, else of the connected joypads' family.
@export var device_type: DeviceType = DEVICE_TYPE_UNKNOWN:
	set(value):
		device_type = value
		_restart()

## device_type_override is the player's setting for the device type whose glyphs are
## drawn, read as `device_type` is. It is the lock itself when `device_type` is
## `DEVICE_TYPE_UNKNOWN`, and a `DEVICE_TYPE_GENERIC` lock defers to it only when it
## names a controller. Any other `device_type` wins over it.
@export var device_type_override: StdSettingsPropertyInt = null:
	set(value):
		if device_type_override:
			Signals.disconnect_safe(device_type_override.value_changed, _invalidate)

		device_type_override = value

		if device_type_override:
			Signals.connect_safe(device_type_override.value_changed, _invalidate)

		_restart()

## restrict_to_device_category ignores a `device_type_override` outside the active
## device's category (i.e. keyboard vs. joypad) when `device_type` is
## `DEVICE_TYPE_UNKNOWN`. It has no effect under any other `device_type`.
@export var restrict_to_device_category: bool = false:
	set(value):
		restrict_to_device_category = value
		_restart()

@export_group("Display")

## fallback is what the texture draws when the active device's category has no binding
## for the action.
##
## NOTE: A glyph locked by `device_type` or `device_type_override` treats this as
## `NONE`, since its host asked for that category on purpose.
@export var fallback: Fallback = Fallback.OTHER_CATEGORY:
	set(value):
		fallback = value
		_restart()

## size is the height the glyph is drawn at, with its width following the glyph's own
## aspect ratio; `0` draws the glyph at its own size.
@export var size: int = 32:
	set(value):
		size = value
		_restart()

@export_group("Cycle")

## cycle_interval is the time in seconds each distinct origin bound to the action is
## shown before the glyph advances to the next, starting over from `binding_index` after
## the last; `0` shows the first alone.
@export var cycle_interval: float = 0.0:
	set(value):
		cycle_interval = value
		_restart()

## cycle_process_always is whether the cycle keeps running while the scene tree is
## paused, as a prompt in a pause menu needs; `false` freezes it with the tree.
@export var cycle_process_always: bool = true

# -- INITIALIZATION ------------------------------------------------------------------ #

## _cycle is how many times `advance` moved the glyph on since the cycle restarted.
var _cycle: int = 0

## _cycle_time is the time in seconds since the glyph last advanced on its own.
var _cycle_time: float = 0.0

## _dirty is whether the glyph must be resolved again before it's measured or drawn.
var _dirty: bool = true

## _drawn_device_type is the device type whose origin is drawn, or would be at
## `binding_index` when none is.
var _drawn_device_type: DeviceType = DEVICE_TYPE_UNKNOWN

## _drawn_index is the binding index of the origin drawn.
var _drawn_index: int = 0

## _glyph is the glyph drawn, or `null` when none is.
var _glyph: Texture2D = null

## _hidden is whether the texture reports a zero size, as `Fallback.HIDE` asks.
var _hidden: bool = false

## _slot is the slot the texture is bound to.
var _slot: StdInputSlot = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## advance moves the glyph on to the next distinct origin bound to the action, starting
## over from `binding_index` after the last. The texture calls it every
## `cycle_interval`, and a host may call it to step the glyph by hand.
func advance() -> void:
	_cycle += 1
	_invalidate()


## get_origin_label returns the localized name of the origin drawn, or of the one at
## `binding_index` when none is.
func get_origin_label() -> String:
	_refresh()

	if not _slot or not action_set or not action:
		return ""

	return _slot.get_action_origin_label(
		action_set, action, _drawn_index, _drawn_device_type
	)


## has_glyph returns whether the texture draws a glyph, which it doesn't while the
## action has no binding to draw or no slot exists for `player_id`.
func has_glyph() -> bool:
	_refresh()
	return _glyph != null


## update binds the texture to its player's slot, if it isn't bound, and redraws it
## from `binding_index`.
func update() -> void:
	_cycle = 0
	_cycle_time = 0.0
	_dirty = true
	_refresh()
	emit_changed()


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if has_glyph():
		_glyph.draw_rect(
			to_canvas_item, Rect2(pos, get_size()), false, modulate, transpose
		)


func _draw_rect(
	to_canvas_item: RID,
	rect: Rect2,
	tile: bool,
	modulate: Color,
	transpose: bool,
) -> void:
	if has_glyph():
		_glyph.draw_rect(to_canvas_item, rect, tile, modulate, transpose)


func _draw_rect_region(
	to_canvas_item: RID,
	rect: Rect2,
	src_rect: Rect2,
	modulate: Color,
	transpose: bool,
	clip_uv: bool,
) -> void:
	if not has_glyph():
		return

	# NOTE: The region is in this texture's pixels, so it's scaled to the glyph's own.
	var scale := _glyph.get_size() / get_size()

	(
		_glyph
		. draw_rect_region(
			to_canvas_item,
			rect,
			Rect2(src_rect.position * scale, src_rect.size * scale),
			modulate,
			transpose,
			clip_uv,
		)
	)


func _get_height() -> int:
	if has_glyph():
		return size if size > 0 else _glyph.get_height()

	return 0 if _hidden else size


func _get_width() -> int:
	if has_glyph():
		return roundi(_glyph.get_width() * float(_get_height()) / _glyph.get_height())

	return 0 if _hidden else size


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_locked_device_type returns the device type the glyph is locked to, or
## `DEVICE_TYPE_UNKNOWN` when it follows the active device.
func _get_locked_device_type(slot: StdInputSlot) -> DeviceType:
	var setting: DeviceType = DEVICE_TYPE_UNKNOWN
	if device_type_override:
		setting = device_type_override.get_value()

	var setting_category := StdInputDevice.get_device_category(setting)

	var locked := device_type
	match device_type:
		DEVICE_TYPE_UNKNOWN:
			if (
				not restrict_to_device_category
				or setting_category == slot.device_category
			):
				locked = setting
		DEVICE_TYPE_GENERIC:
			if setting_category == DEVICE_TYPE_GENERIC:
				locked = setting

	if locked == DEVICE_TYPE_GENERIC:
		return slot.get_joypad_device_type()

	return locked


## _get_slot returns the slot of `player_id`, connecting to its signals when first
## found, or `null` while no slot for the player is in the scene and in the editor.
func _get_slot() -> StdInputSlot:
	if is_instance_valid(_slot) and _slot.is_inside_tree():
		return _slot

	_unbind()

	if Engine.is_editor_hint():
		return null

	var slot := StdInputSlot.for_player(player_id)
	if slot:
		_set_slot_connected(slot, true)
		_slot = slot

	return _slot


## _invalidate marks the glyph to be resolved again and tells hosts to redraw it.
func _invalidate(_value: Variant = null) -> void:
	_dirty = true
	emit_changed()


## _list_glyphs returns each distinct glyph bound to the action for `type`, from
## `binding_index` on, as `[index, glyph]` pairs in binding order. An unbound index is
## skipped, as is an index whose glyph an earlier one already draws.
func _list_glyphs(slot: StdInputSlot, type: DeviceType) -> Array[Array]:
	var glyphs: Array[Array] = []
	var drawn: Array[Texture2D] = []

	# NOTE: Godot's provider counts origins only up to the first unbound index, so every
	# binding index it stores is tried as well.
	var count := maxi(
		slot.get_action_origin_count(action_set, action, type),
		StdInputDeviceActions.BindingIndex.size(),
	)

	for index in range(binding_index, count):
		var glyph := slot.get_action_glyph(
			action_set, action, index, Vector2(0, size), type
		)
		if glyph and glyph not in drawn:
			drawn.append(glyph)
			glyphs.append([index, glyph])

	return glyphs


## _refresh resolves the glyph again if anything it depends on changed since the last
## resolve, binding to the player's slot first.
func _refresh() -> void:
	if not _dirty:
		return

	_glyph = null
	_hidden = false
	_drawn_index = binding_index

	var slot := _get_slot()
	if not slot or not action_set or not action:
		_set_ticking(false)
		return

	_dirty = false

	var locked := _get_locked_device_type(slot)
	_drawn_device_type = locked if locked != DEVICE_TYPE_UNKNOWN else slot.device_type

	var glyphs := _list_glyphs(slot, _drawn_device_type)

	if not glyphs and locked == DEVICE_TYPE_UNKNOWN:
		match fallback:
			Fallback.OTHER_CATEGORY:
				var other := (
					DEVICE_TYPE_KEYBOARD
					if slot.device_category == DEVICE_TYPE_GENERIC
					else slot.get_joypad_device_type()
				)

				glyphs = _list_glyphs(slot, other)
				if glyphs:
					_drawn_device_type = other
			Fallback.HIDE:
				_hidden = true

	_set_ticking(cycle_interval > 0.0 and glyphs.size() > 1)

	if glyphs:
		var drawn: Array = glyphs[_cycle % glyphs.size()]
		_drawn_index = drawn[0]
		_glyph = drawn[1]


## _restart restarts the cycle from `binding_index` and redraws the glyph.
func _restart(_value: Variant = null) -> void:
	_cycle = 0
	_cycle_time = 0.0
	_invalidate()


## _set_slot_connected connects the texture to the signals of `slot` which can change
## its glyph, or disconnects it from them.
func _set_slot_connected(slot: StdInputSlot, connected: bool) -> void:
	for pair in [
		[slot.action_configuration_changed, _restart],
		[slot.device_activated, _restart],
		[slot.device_connected, _invalidate],
		[slot.device_disconnected, _invalidate],
		[slot.cursor_visibility_changed, _invalidate],
		[slot.origin_labels_changed, _invalidate],
		[slot.tree_exited, _invalidate],
	]:
		if connected:
			Signals.connect_safe(pair[0], pair[1])
		else:
			Signals.disconnect_safe(pair[0], pair[1])


## _set_ticking connects the cycle to the scene tree's frames, or disconnects it.
func _set_ticking(ticking: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return

	if ticking:
		Signals.ensure_connected(tree.process_frame, _on_process_frame)
	else:
		Signals.disconnect_safe(tree.process_frame, _on_process_frame)


## _tick moves the cycle on by `delta` seconds, advancing the glyph once each
## `cycle_interval` passes.
func _tick(delta: float) -> void:
	# NOTE: The ticking connection is only updated on the next resolve, so the interval
	# can have dropped to zero since.
	if cycle_interval <= 0.0:
		return

	if not cycle_process_always and (Engine.get_main_loop() as SceneTree).paused:
		return

	_cycle_time += delta
	if _cycle_time < cycle_interval:
		return

	# NOTE: A frame longer than the interval advances the glyph once and drops the
	# surplus, rather than catching up a step per frame afterwards.
	_cycle_time = fmod(_cycle_time, cycle_interval)
	advance()


## _unbind disconnects the texture from its slot, so the next resolve looks it up.
func _unbind() -> void:
	if is_instance_valid(_slot):
		_set_slot_connected(_slot, false)

	_slot = null


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_process_frame() -> void:
	_tick((Engine.get_main_loop() as SceneTree).root.get_process_delta_time())
