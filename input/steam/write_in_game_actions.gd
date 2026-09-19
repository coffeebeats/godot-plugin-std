##
## std/input/steam/write_in_game_actions.gd
##
## Writes the project's Steam Input manifest and exits:
##
##   godot --headless -s addons/std/input/steam/write_in_game_actions.gd [-- <path>]
##
## `path` names the `StdInputSteamInGameActions` resource; without it, the one under
## `res://` is used. Exits 1 when it is missing, ambiguous, or the write fails.
##

extends SceneTree

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create("std/input/steam/write-in-game-actions")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _initialize() -> void:
	var manifest := _find_manifest(OS.get_cmdline_user_args())
	if not manifest:
		quit(1)
		return

	var err := manifest.write()
	if err != OK:
		_logger.error(
			"Failed to write the manifest.",
			{&"path": manifest.get_filename(), &"error": err}
		)
		quit(1)
		return

	print("wrote ", ProjectSettings.globalize_path(manifest.get_filename()))
	quit(0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _find_manifest returns the manifest `args` names or the project's one, else null.
func _find_manifest(args: PackedStringArray) -> StdInputSteamInGameActions:
	if args.size() > 1:
		_logger.error(
			"Expected at most one argument, the manifest's path.", {&"args": args}
		)
		return null

	if args.size() == 1:
		var path := ProjectSettings.localize_path(args[0])
		var manifest := ResourceLoader.load(path) as StdInputSteamInGameActions
		if not manifest:
			_logger.error("Not a StdInputSteamInGameActions resource.", {&"path": path})

		return manifest

	var found := StdInputSteamInGameActions.find_resources(
		&"StdInputSteamInGameActions"
	)
	if found.size() == 1:
		return found[0] as StdInputSteamInGameActions

	var paths := PackedStringArray()
	for resource in found:
		paths.append(resource.resource_path)

	_logger.error("Expected one manifest; name it with '-- <path>'.", {&"found": paths})

	return null
