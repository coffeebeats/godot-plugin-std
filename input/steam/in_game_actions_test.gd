##
## Tests pertaining to the `StdInputSteamInGameActions` class.
##

extends GutTest

# -- DEFINITIONS --------------------------------------------------------------------- #


## _LabelsBySet names an action after the set it's written for.
class _LabelsBySet:
	extends StdInputSteamInGameActions

	func _get_action_display_name(
		action_set_name: StringName,
		action_name: StringName,
		_locale: StringName = &"",
	) -> String:
		return "%s %s" % [action_set_name, action_name]


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
			'\t\t\t\t"ui_accept"\t\t\t\t"#action_Menu_ui_accept"',
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
			'\t\t\t\t"ui_tab_next"\t\t\t\t"#action_MenuTabbed_ui_tab_next"',
			"\t\t\t}",
			"\t\t}",
			"\t}",
			'\t"localization"',
			"\t{",
			'\t\t"english"',
			"\t\t{",
			'\t\t\t"set_Menu"\t\t\t\t\t"Menu"',
			'\t\t\t"action_Menu_ui_accept"\t\t\t\t\t"ui_accept"',
			'\t\t\t"layer_MenuTabbed"\t\t\t\t\t"MenuTabbed"',
			'\t\t\t"action_MenuTabbed_ui_tab_next"\t\t\t\t\t"ui_tab_next"',
			"\t\t}",
			"\t}",
			"}",
		]
	)
	assert_eq(got, want)


func test_render_writes_analog_sections() -> void:
	# Given: A set with a trigger and a stick.
	var gameplay := StdInputActionSet.new()
	gameplay.name = &"Gameplay"
	gameplay.actions_analog_1d = [&"throttle"]
	gameplay.actions_analog_2d = [&"look"]

	# Given: The stick's directional actions beside another digital action.
	gameplay.actions_digital = StdInputActionSet.list_analog_2d_actions(&"look")
	gameplay.actions_digital.append(&"fire")

	# Given: An absolute mouse action.
	gameplay.action_absolute_mouse = &"aim"

	# When: The manifest is rendered with no languages.
	var got := manifest.render([gameplay], {})

	# Then: The sections precede the localization, and buttons skip the directions.
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
			'\t\t\t\t"look"',
			"\t\t\t\t{",
			'\t\t\t\t\t"title"\t\t\t"#action_Gameplay_look"',
			'\t\t\t\t\t"input_mode"\t\t\t"joystick_move"',
			"\t\t\t\t}",
			'\t\t\t\t"aim"',
			"\t\t\t\t{",
			'\t\t\t\t\t"title"\t\t\t"#action_Gameplay_aim"',
			'\t\t\t\t\t"input_mode"\t\t\t"absolute_mouse"',
			"\t\t\t\t}",
			"\t\t\t}",
			'\t\t\t"AnalogTrigger"',
			"\t\t\t{",
			'\t\t\t\t"throttle"\t\t\t\t"#action_Gameplay_throttle"',
			"\t\t\t}",
			'\t\t\t"Button"',
			"\t\t\t{",
			'\t\t\t\t"fire"\t\t\t\t"#action_Gameplay_fire"',
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


func test_render_with_a_layer_with_no_parent_is_an_error() -> void:
	# Given: A set and a layer with no parent.
	var menu := _make_action_set(&"Menu", [&"ui_accept"])
	var nav := _make_layer(&"Nav", null, [&"ui_cancel"])

	# When: The manifest is rendered.
	manifest.render([menu, nav], {"english": "en"})

	# Then: The missing parent is reported.
	assert_engine_error("missing parent action set")


func test_render_with_a_repeated_name_is_an_error() -> void:
	# Given: A set with a `Nav` layer.
	var menu := _make_action_set(&"Menu", [&"ui_accept"])
	var nav := _make_layer(&"Nav", menu, [&"ui_cancel"])

	# When: The manifest is rendered with a second set called `Menu`.
	manifest.render([menu, nav, _make_action_set(&"Menu", [])], {"english": "en"})

	# Then: The repeated set name is reported.
	assert_engine_error("duplicate name: Menu")

	# When: The manifest is rendered with a `Nav` layer under another set.
	var gameplay := _make_action_set(&"Gameplay", [])
	var nav_gameplay := _make_layer(&"Nav", gameplay, [])
	manifest.render([menu, gameplay, nav, nav_gameplay], {"english": "en"})

	# Then: The repeated layer name is reported, though the parents differ.
	assert_engine_error("duplicate name: Nav")


func test_render_gives_an_action_a_label_per_set() -> void:
	# Given: Two sets holding the same action, and a manifest naming it per set.
	var menu := StdInputActionSet.new()
	menu.name = &"Menu"
	menu.actions_digital = [&"ui_accept"]

	var splash := StdInputActionSet.new()
	splash.name = &"Splash"
	splash.actions_digital = [&"ui_accept"]

	var labels := _LabelsBySet.new()

	# When: The manifest is rendered for one language.
	var got := labels.render([menu, splash], {"english": "en"})

	# Then: Each set titles the action with its own key.
	assert_true(got.contains('"ui_accept"\t\t\t\t"#action_Menu_ui_accept"'))
	assert_true(got.contains('"ui_accept"\t\t\t\t"#action_Splash_ui_accept"'))

	# Then: Each key has that set's label.
	assert_true(got.contains('"action_Menu_ui_accept"\t\t\t\t\t"Menu ui_accept"'))
	assert_true(got.contains('"action_Splash_ui_accept"\t\t\t\t\t"Splash ui_accept"'))


func test_render_ignores_holds() -> void:
	# Given: A set with a digital action.
	var menu := StdInputActionSet.new()
	menu.name = &"Menu"
	menu.actions_digital = [&"ui_accept"]

	# Given: A layer of that set with a digital action.
	var tabbed := StdInputActionSetLayer.new()
	tabbed.name = &"MenuTabbed"
	tabbed.parent = menu
	tabbed.actions_digital = [&"ui_tab_next"]

	# Given: The manifest rendered before either declares a hold.
	var want := manifest.render([menu, tabbed], {"english": "en"})

	# Given: A hold on the set's action.
	var confirm := StdInputActionHold.new()
	confirm.action = &"ui_accept"
	confirm.duration = 0.5
	menu.holds = [confirm]

	# Given: A hold on the layer, over an action neither declares.
	var charge := StdInputActionHold.new()
	charge.action = &"ui_charge"
	tabbed.holds = [charge]

	# When: The manifest is rendered again.
	var got := manifest.render([menu, tabbed], {"english": "en"})

	# Then: The holds change nothing.
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


func test_match_steam_language_prefers_the_closest_locale(
	params = use_parameters(
		(
			ParameterFactory
			. named_parameters(
				["locale", "expected"],
				[
					["en_US", "english"],
					["pt_BR", "brazilian"],
					["pt", "portuguese"],
					["pt_PT", "portuguese"],
					["pt_AO", "portuguese"],
					["es_ES", "spanish"],
					["es", "spanish"],
					["es_MX", "latam"],
					["es_AR", "spanish"],
					["zh_TW", "tchinese"],
					["no", "norwegian"],
					["nb_NO", "norwegian"],
					["uk", "ukrainian"],
					["xx", ""],
				]
			)
		)
	)
) -> void:
	# Given: A Godot locale.

	# When: It is matched against Steam's languages.
	var got := StdInputSteamInGameActions._match_steam_language(params.locale)

	# Then: The closest language, or nothing, is returned.
	assert_eq(got, params.expected)


func test_resolve_locales_derives_sorted_languages_with_overrides() -> void:
	# Given: Loaded locales, one of them unmapped.
	var loaded := PackedStringArray(["uk", "en_US", "pt_BR", "xx"])

	# Given: An override for a language no catalogue covers.
	var overrides := {"french": "fr"}

	# When: The languages are resolved.
	var got := StdInputSteamInGameActions._resolve_locales(loaded, overrides)

	# Then: English is seeded, matches carry their loaded locale, and names are sorted.
	assert_eq(got.keys(), ["brazilian", "english", "french", "ukrainian"])
	assert_eq(got["english"], "en_US")
	assert_eq(got["brazilian"], "pt_BR")
	assert_eq(got["french"], "fr")


func test_resolve_locales_seeds_english_when_nothing_is_loaded() -> void:
	# Given: No loaded locales and no overrides.

	# When: The languages are resolved.
	var got := StdInputSteamInGameActions._resolve_locales(PackedStringArray(), {})

	# Then: English alone is written.
	assert_eq(got, {"english": "en"})


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


## _make_action_set returns a set called `id` declaring the digital `actions`.
func _make_action_set(id: StringName, actions: Array[StringName]) -> StdInputActionSet:
	var action_set := StdInputActionSet.new()
	action_set.name = id
	action_set.actions_digital = actions
	return action_set


## _make_layer returns a layer called `id` under `parent`, declaring the digital
## `actions`.
func _make_layer(
	id: StringName, parent: StdInputActionSet, actions: Array[StringName]
) -> StdInputActionSetLayer:
	var layer := StdInputActionSetLayer.new()
	layer.name = id
	layer.parent = parent
	layer.actions_digital = actions
	return layer


## _lines joins manifest lines with the newline the generator writes after each.
func _lines(lines: PackedStringArray) -> String:
	return "\n".join(lines) + "\n"
