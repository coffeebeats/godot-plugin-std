##
## Tests pertaining to the `StdInputSteamInGameActions` class.
##

extends GutTest

# -- INITIALIZATION ------------------------------------------------------------------ #

var manifest: StdInputSteamInGameActions = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_render_writes_sets_layers_and_localization() -> void:
	# Given: A set with a digital action.
	var menu := StdInputActionSet.new()
	menu.name = &"Menu"
	menu.actions_digital = [&"ui_accept"]

	# Given: A layer of that set with its own digital action.
	var tabbed := StdInputActionSetLayer.new()
	tabbed.name = &"MenuTabbed"
	tabbed.parent = menu
	tabbed.actions_digital = [&"ui_tab_next"]

	# When: The manifest is rendered for one language, with the layer listed first.
	var got := manifest.render([tabbed, menu], {"english": "en"})

	# Then: Sets and layers are written by type, and names fall back to identifiers.
	var want := _lines(
		[
			'"In Game Actions"',
			"{",
			'\t"actions"',
			"\t{",
			'\t\t"Menu"',
			"\t\t{",
			'\t\t\t"title"\t\t\t\t\t"#set_Menu"',
			'\t\t\t"legacy_set"\t\t\t\t\t"0"',
			'\t\t\t"Button"',
			"\t\t\t{",
			'\t\t\t\t"ui_accept"\t\t\t\t"#action_ui_accept"',
			"\t\t\t}",
			"\t\t}",
			"\t}",
			'\t"action_layers"',
			"\t{",
			'\t\t"MenuTabbed"',
			"\t\t{",
			'\t\t\t"title"\t\t\t\t\t"#layer_MenuTabbed"',
			'\t\t\t"legacy_set"\t\t\t\t\t"0"',
			'\t\t\t"set_layer"\t\t\t\t\t"1"',
			'\t\t\t"parent_set_name"\t\t\t\t\t"Menu"',
			'\t\t\t"Button"',
			"\t\t\t{",
			'\t\t\t\t"ui_tab_next"\t\t\t\t"#action_ui_tab_next"',
			"\t\t\t}",
			"\t\t}",
			"\t}",
			'\t"localization"',
			"\t{",
			'\t\t"english"',
			"\t\t{",
			'\t\t\t"set_Menu"\t\t\t\t\t"Menu"',
			'\t\t\t"action_ui_accept"\t\t\t\t\t"ui_accept"',
			'\t\t\t"layer_MenuTabbed"\t\t\t\t\t"MenuTabbed"',
			'\t\t\t"action_ui_tab_next"\t\t\t\t\t"ui_tab_next"',
			"\t\t}",
			"\t}",
			"}",
		]
	)
	assert_eq(got, want)


func test_render_writes_analog_sections() -> void:
	# Given: A set with analog actions and an absolute mouse action.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"
	gameplay.actions_analog_1d = [&"throttle"]
	gameplay.actions_analog_2d = [&"look_x"]
	gameplay.action_absolute_mouse = &"aim"

	# When: The manifest is rendered with no languages.
	var got := manifest.render([gameplay], {})

	# Then: The stick and trigger sections precede the empty localization block.
	var want := _lines(
		[
			'"In Game Actions"',
			"{",
			'\t"actions"',
			"\t{",
			'\t\t"Gameplay"',
			"\t\t{",
			'\t\t\t"title"\t\t\t\t\t"#set_Gameplay"',
			'\t\t\t"legacy_set"\t\t\t\t\t"0"',
			'\t\t\t"StickPadGyro"',
			"\t\t\t{",
			'\t\t\t\t"look_x"',
			"\t\t\t\t{",
			'\t\t\t\t\t"title"\t\t\t"#action_look_x"',
			'\t\t\t\t\t"input_mode"\t\t\t"joystick_move"',
			"\t\t\t\t}",
			'\t\t\t\t"aim"',
			"\t\t\t\t{",
			'\t\t\t\t\t"title"\t\t\t"#action_aim"',
			'\t\t\t\t\t"input_mode"\t\t\t"absolute_mouse"',
			"\t\t\t\t}",
			"\t\t\t}",
			'\t\t\t"AnalogTrigger"',
			"\t\t\t{",
			'\t\t\t\t"throttle"\t\t\t\t"#action_throttle"',
			"\t\t\t}",
			"\t\t}",
			"\t}",
			'\t"action_layers"',
			"\t{",
			"\t}",
			'\t"localization"',
			"\t{",
			"\t}",
			"}",
		]
	)
	assert_eq(got, want)


func test_render_skips_null_action_sets() -> void:
	# Given: A list holding only a null entry.
	var action_sets: Array[StdInputActionSet] = [null]

	# When: The manifest is rendered.
	var got := manifest.render(action_sets, {})

	# Then: Every block is empty.
	assert_eq(
		got,
		_lines(
			[
				'"In Game Actions"',
				"{",
				'\t"actions"',
				"\t{",
				"\t}",
				'\t"action_layers"',
				"\t{",
				"\t}",
				'\t"localization"',
				"\t{",
				"\t}",
				"}",
			]
		)
	)


func test_parse_script_class_reads_header(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["header", "expected"],
				[
					[
						(
							'[gd_resource type="Resource" script_class="StdInputActionSet"'
							+ ' format=3 uid="uid://c6ihq60tiqoap"]'
						),
						&"StdInputActionSet",
					],
					['[gd_resource type="Resource" format=3]', &""],
					['[gd_resource type="Resource" script_class="Unterminated', &""],
					["", &""],
				]
			)
		)
	)
) -> void:
	# Given: A text resource header.

	# When: Its script class is parsed.
	var got := StdInputSteamInGameActions._parse_script_class(params.header)

	# Then: The declared class, or nothing, is returned.
	assert_eq(got, params.expected)


func test_descendants_follows_the_class_tree() -> void:
	# Given: A class list with a chain under the base and an unrelated class.
	var classes: Array[Dictionary] = [
		{"class": &"Unrelated", "base": &"Resource"},
		{"class": &"Grandchild", "base": &"Child"},
		{"class": &"Child", "base": &"Base"},
	]

	# When: The base's descendants are listed.
	var got := StdInputSteamInGameActions._descendants(&"Base", classes)

	# Then: The whole chain is found, in discovery order, without the base itself.
	assert_eq(got, PackedStringArray([&"Child", &"Grandchild"]))


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	manifest = StdInputSteamInGameActions.new()


func after_each() -> void:
	manifest = null


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _lines joins manifest lines with the newline the generator writes after each.
func _lines(lines: PackedStringArray) -> String:
	return "\n".join(lines) + "\n"
