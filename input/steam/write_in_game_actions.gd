##
## std/input/steam/write_in_game_actions.gd
##
## Writes the project's Steam Input manifest and exits. Run it from the project root:
##
##   godot --headless -s addons/std/input/steam/write_in_game_actions.gd [-- <path>]
##
## The manifest resource, a `StdInputSteamInGameActions` or a subclass declaring a
## `class_name`, is found under `res://`; `path` names it instead when the project
## holds several. Exits 1 when none or more than one is found or the write fails.
##

extends SceneTree

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _initialize() -> void:
	var manifest := _find_manifest(OS.get_cmdline_user_args())
	if not manifest:
		quit(1)
		return

	var err := manifest.write()
	if err != OK:
		push_error("failed to write %s: %d" % [manifest.get_filename(), err])
		quit(1)
		return

	print("wrote ", manifest.get_filename())
	quit(0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _find_manifest returns the manifest named by `args`, or the one manifest resource in
## the project, or null after reporting why neither was found.
func _find_manifest(args: PackedStringArray) -> StdInputSteamInGameActions:
	if args.size() > 1:
		push_error("expected at most one argument, the manifest's path; got %s" % args)
		return null

	if args.size() == 1:
		var manifest := ResourceLoader.load(args[0]) as StdInputSteamInGameActions
		if not manifest:
			push_error("%s is not a StdInputSteamInGameActions resource" % args[0])

		return manifest

	var found := StdInputSteamInGameActions.find_resources(
		&"StdInputSteamInGameActions"
	)
	if found.size() == 1:
		return found[0] as StdInputSteamInGameActions

	var message := (
		"expected one StdInputSteamInGameActions resource under res://, found %d"
		% found.size()
	)

	if found.size() > 1:
		var paths := PackedStringArray()
		for resource in found:
			paths.append(resource.resource_path)

		message += "; name one with `-- <path>`: %s" % ", ".join(paths)

	push_error(message)

	return null
