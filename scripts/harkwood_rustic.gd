extends "res://scripts/harkwood_game.gd"
## Rustic UI presentation layer. Keeps game systems unchanged while matching Harkwood's hand-crafted world art.
const RUI = preload("res://scripts/ui/palette.gd")

const PAPER_INK = Color("302519")
const PAPER_MUTED = Color("6f5b43")
const PAPER_ACCENT = Color("775326")
const PAPER_GREEN = Color("526346")

func build_header() -> void:
	var backdrop: Panel = Panel.new()
	backdrop.position = Vector2(8, 4)
	backdrop.size = Vector2(1424, 82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", RUI.header_box())
	header.add_child(backdrop)

	var crest: TextureRect = TextureRect.new()
	crest.texture = RUI.logo_texture()
	crest.position = Vector2(20, 7)
	crest.size = Vector2(58, 69)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(crest)

	var mark: Label = RUI.label("HARKWOOD", 31, RUI.PAPER, true)
	mark.position = Vector2(80, 13)
	header.add_child(mark)
	var edition: Label = RUI.label("A LANTERN AGAINST THE DARK", 9, RUI.GOLD)
	edition.position = Vector2(82, 53)
	header.add_child(edition)

	var tabs: Array = [
		["hub", "Hearth", "nav_hearth", 112.0],
		["map", "Wilds", "nav_wilds", 103.0],
		["inventory", "Pack", "nav_pack", 101.0],
		["forge", "Forge", "nav_forge", 103.0],
		["market", "Exchange", "nav_exchange", 125.0],
		["journal", "Journal", "nav_journal", 110.0],
	]
	var x: float = 320.0
	for tab in tabs:
		var id: String = str(tab[0])
		var nav: Button = RUI.button(str(tab[1]), func(): request_screen(id), 48)
		nav.position = Vector2(x, 18)
		nav.size = Vector2(float(tab[3]), 50)
		nav.icon = RUI.rustic_icon(str(tab[2]))
		nav.disabled = traveling or (screen == "battle" and phase != "results")
		if screen == id:
			nav.add_theme_stylebox_override("normal", RUI.button_active_box())
			nav.add_theme_color_override("font_color", Color("ffd27a"))
		header.add_child(nav)
		x += float(tab[3]) + 6.0

	var gold_panel: Panel = Panel.new()
	gold_panel.position = Vector2(1016, 18)
	gold_panel.size = Vector2(124, 50)
	gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_panel.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	header.add_child(gold_panel)
	var gold_icon: TextureRect = RUI.icon(13, 28)
	gold_icon.position = Vector2(1028, 28)
	gold_icon.size = Vector2(30, 30)
	header.add_child(gold_icon)
	var money: Label = RUI.label(str(int(game.data.gold)), 19, RUI.GOLD, true)
	money.position = Vector2(1062, 30)
	header.add_child(money)

	var level_panel: Panel = Panel.new()
	level_panel.position = Vector2(1147, 18)
	level_panel.size = Vector2(149, 50)
	level_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_panel.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	header.add_child(level_panel)
	var level_badge: Label = RUI.label("LV. %02d" % game.level(), 15, RUI.PAPER, true)
	level_badge.position = Vector2(1160, 24)
	header.add_child(level_badge)
	var xp: ProgressBar = ProgressBar.new()
	xp.position = Vector2(1160, 50)
	xp.size = Vector2(122, 7)
	xp.max_value = game.level() * 60
	xp.value = game.level_xp()
	xp.show_percentage = false
	xp.tooltip_text = "%d / %d XP" % [game.level_xp(), game.level() * 60]
	header.add_child(xp)

	var settings: Button = RUI.button("Settings", show_settings, 48)
	settings.position = Vector2(1303, 18)
	settings.size = Vector2(126, 50)
	settings.icon = RUI.rustic_icon("nav_settings")
	header.add_child(settings)

func build_footer() -> void:
	var resource_bg: Panel = Panel.new()
	resource_bg.position = Vector2(0, 0)
	resource_bg.size = Vector2(1015, 50)
	resource_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_bg.add_theme_stylebox_override("panel", RUI.bar_box())
	footer.add_child(resource_bg)

	var row: HBoxContainer = RUI.row(footer)
	row.position = Vector2(15, 7)
	row.size = Vector2(990, 36)
	row.add_theme_constant_override("separation", 5)
	for id in DB2.MATERIALS:
		var mat: Dictionary = DB2.MATERIALS[id]
		row.add_child(RUI.icon(int(mat.icon), 25))
		row.add_child(RUI.label("%s  %d" % [str(mat.name), int(game.data.materials[id])], 12, RUI.PAPER))
		var gap: Control = Control.new()
		gap.custom_minimum_size.x = 8
		row.add_child(gap)
	row.add_child(RUI.icon(12, 25))
	row.add_child(RUI.label("Draughts  %d" % int(game.data.potions), 12, RUI.PAPER))

	var hints_bg: Panel = Panel.new()
	hints_bg.position = Vector2(1022, 0)
	hints_bg.size = Vector2(370, 50)
	hints_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints_bg.add_theme_stylebox_override("panel", RUI.bar_box())
	footer.add_child(hints_bg)
	var hint: String = "WASD / arrows · E interact · I pack · M map · C forge · J journal · F11 fullscreen"
	if screen == "battle":
		hint = "Q draught · Space pause · earned loot banks after each victory"
	var help: Label = RUI.paragraph(hint, 10, RUI.MUTED)
	help.position = Vector2(1038, 13)
	help.size = Vector2(338, 30)
	footer.add_child(help)
	var version_label: Label = RUI.label("HARKWOOD  /  PROTOTYPE 0.3", 9, RUI.GOLD)
	version_label.position = Vector2(1190, 55)
	footer.add_child(version_label)

func make_world(mode: String) -> Control:
	var node: Control = super.make_world(mode)
	var frame: Panel = Panel.new()
	frame.position = Vector2.ZERO
	frame.size = node.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 90
	frame.add_theme_stylebox_override("panel", RUI.world_frame_box())
	node.add_child(frame)
	return node

func add_scene_title(title: String, subtitle: String) -> void:
	var backdrop: Panel = Panel.new()
	backdrop.position = Vector2(18, 16)
	backdrop.size = Vector2(470, 92)
	backdrop.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(backdrop)
	var crest: TextureRect = TextureRect.new()
	crest.texture = RUI.logo_texture()
	crest.position = Vector2(16, 12)
	crest.size = Vector2(48, 60)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	backdrop.add_child(crest)
	var title_label: Label = RUI.label(title, 27, RUI.PAPER, true)
	title_label.position = Vector2(72, 14)
	backdrop.add_child(title_label)
	var caption: Label = RUI.label(subtitle, 11, RUI.GOLD)
	caption.position = Vector2(74, 54)
	backdrop.add_child(caption)

func new_sidebar(eyebrow: String, title: String, subtext: String = "") -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(1000, 0)
	panel.size = Vector2(392, 680)
	panel.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	page.add_child(panel)
	sidebar = RUI.scroll_column(panel)
	sidebar.add_theme_constant_override("separation", 13)
	sidebar.add_child(RUI.label(eyebrow, 10, RUI.GOLD))
	sidebar.add_child(RUI.paragraph(title, 27, RUI.PAPER))
	sidebar.get_child(sidebar.get_child_count() - 1).add_theme_font_override("font", RUI.title_font)
	if subtext != "":
		sidebar.add_child(RUI.paragraph(subtext, 14, RUI.MUTED))
	RUI.rule(sidebar)
	return sidebar

func build_hub() -> void:
	world = make_world("hub")
	world.station_requested.connect(request_screen)
	add_scene_title("The Lantern Hearth", "HARKWOOD  /  SANCTUARY")

	var stations: Array = [
		["forge", "Hearthforge", Vector2(198, 245), 128.0],
		["market", "Trading post", Vector2(614, 257), 138.0],
		["stash", "Your chest", Vector2(84, 475), 116.0],
		["map", "Into the wilds  ›", Vector2(781, 350), 150.0],
	]
	for station_data in stations:
		var id: String = str(station_data[0])
		var station: Button = RUI.button(str(station_data[1]), func(): world.approach(id), 38)
		station.position = station_data[2]
		station.size = Vector2(float(station_data[3]), 40)
		station.add_theme_font_size_override("font_size", 13)
		station.add_theme_stylebox_override("normal", RUI.small_sign_box())
		station.add_theme_stylebox_override("hover", RUI.button_box("hover"))
		world.add_child(station)

	var paper_panel: PanelContainer = PanelContainer.new()
	paper_panel.position = Vector2(1000, 0)
	paper_panel.size = Vector2(392, 680)
	paper_panel.add_theme_stylebox_override("panel", RUI.parchment_box())
	page.add_child(paper_panel)
	sidebar = RUI.scroll_column(paper_panel)
	sidebar.add_theme_constant_override("separation", 12)

	sidebar.add_child(RUI.label("REST, REFORGE, RETURN", 10, PAPER_ACCENT))
	var hearth_title: Label = RUI.paragraph("A little light survives.", 28, PAPER_INK)
	hearth_title.add_theme_font_override("font", RUI.title_font)
	sidebar.add_child(hearth_title)
	_paper_rule(sidebar)
	sidebar.add_child(RUI.paragraph("The hearth is yours. Gather what the woods surrender, then make something that can face them.", 14, PAPER_MUTED))

	var stats: Dictionary = game.stats()
	var portrait_row: HBoxContainer = RUI.row(sidebar)
	portrait_row.add_child(RUI.icon(1, 86, true))
	var info_col: VBoxContainer = RUI.column(portrait_row)
	info_col.add_child(RUI.label("The Wayfarer", 20, PAPER_INK, true))
	info_col.add_child(RUI.label("Level %d · %d expeditions" % [game.level(), total_clears()], 12, PAPER_MUTED))
	info_col.add_child(RUI.label("%d health   %d attack   %d armor" % [stats.health, stats.attack, stats.armor], 11, PAPER_GREEN))
	_paper_rule(sidebar)

	sidebar.add_child(RUI.label("YOUR NEXT THREAD", 10, PAPER_ACCENT))
	var next: Dictionary = next_quest()
	if next.is_empty():
		sidebar.add_child(RUI.paragraph("The Hollow Hart has fallen. The woods remain: perfect your gear, trade your finds, or begin again.", 15, PAPER_INK))
	else:
		sidebar.add_child(RUI.label(str(next.name), 18, PAPER_INK, true))
		sidebar.add_child(RUI.paragraph(str(next.text), 14, PAPER_MUTED))
		if game.quest_progress(next) >= int(next.target):
			var collect: Button = RUI.button("Collect journal reward", func(): claim(str(next.id)), 44)
			sidebar.add_child(collect)

	RUI.spacer(sidebar, 3)
	var map_button: Button = RUI.button("Open the overworld  ›", func(): request_screen("map"), 48)
	map_button.icon = RUI.rustic_icon("action_map")
	sidebar.add_child(map_button)
	var forge_button: Button = RUI.button("Craft at the Hearthforge", func(): request_screen("forge"), 46)
	forge_button.icon = RUI.rustic_icon("action_forge")
	sidebar.add_child(forge_button)
	var inspect_button: Button = RUI.button("Inspect your equipment", func(): request_screen("inventory"), 46)
	inspect_button.icon = RUI.rustic_icon("action_search")
	sidebar.add_child(inspect_button)
	sidebar.add_child(RUI.paragraph("Walk to a named station, or use the tabs above. You begin with materials for your first upgrades.", 11, PAPER_MUTED))

func _paper_rule(parent: Node) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Color(0.35, 0.25, 0.14, 0.42)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
