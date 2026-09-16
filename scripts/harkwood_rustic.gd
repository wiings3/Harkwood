extends "res://scripts/harkwood_game.gd"
## Presentation layer built directly from the approved Harkwood concept-art UI elements.
const RUI = preload("res://scripts/ui/palette.gd")
const PAPER_INK = Color("302519")
const PAPER_MUTED = Color("6f5b43")
const PAPER_ACCENT = Color("775326")
const PAPER_GREEN = Color("526346")

func _texture_rect(texture_name: String, rect: Rect2, parent: Node, mode: int = TextureRect.STRETCH_SCALE) -> TextureRect:
	var node := TextureRect.new()
	node.texture = RUI.tex(texture_name)
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = mode
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _exact_button(normal_name: String, active_name: String, rect: Rect2, callback: Callable, parent: Node) -> TextureButton:
	var node := RUI.texture_button(normal_name, active_name, callback)
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node

func build_header() -> void:
	var wood := Panel.new()
	wood.position = Vector2(4, 2)
	wood.size = Vector2(1432, 86)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood.add_theme_stylebox_override("panel", RUI.bar_box())
	header.add_child(wood)

	_texture_rect("header_brand_exact", Rect2(10, 3, 300, 80), header, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

	var tabs: Array = [
		["hub", "hearth", 312.0, 112.0],
		["map", "wilds", 424.0, 108.0],
		["inventory", "pack", 532.0, 106.0],
		["forge", "forge", 638.0, 108.0],
		["market", "exchange", 746.0, 122.0],
		["journal", "journal", 868.0, 116.0],
	]
	for tab in tabs:
		var id: String = str(tab[0])
		var name: String = str(tab[1])
		var selected: bool = screen == id
		var normal: String = "nav_%s_active" % name if selected else "nav_%s" % name
		var hover: String = "nav_%s_active" % name
		var nav: TextureButton = _exact_button(normal, hover, Rect2(float(tab[2]), 13, float(tab[3]), 62), func(): request_screen(id), header)
		nav.disabled = traveling or (screen == "battle" and phase != "results")

	var gold_panel := Panel.new()
	gold_panel.position = Vector2(995, 16)
	gold_panel.size = Vector2(116, 56)
	gold_panel.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	header.add_child(gold_panel)
	var gold_icon := RUI.icon(13, 26)
	gold_icon.position = Vector2(1005, 30)
	header.add_child(gold_icon)
	var money := RUI.label(str(int(game.data.gold)), 18, RUI.GOLD, true)
	money.position = Vector2(1040, 29)
	header.add_child(money)

	var level_panel := Panel.new()
	level_panel.position = Vector2(1115, 16)
	level_panel.size = Vector2(160, 56)
	level_panel.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	header.add_child(level_panel)
	var level_badge := RUI.label("LV. %02d" % game.level(), 15, RUI.PAPER, true)
	level_badge.position = Vector2(1128, 23)
	header.add_child(level_badge)
	var xp := ProgressBar.new()
	xp.position = Vector2(1128, 50)
	xp.size = Vector2(132, 8)
	xp.max_value = game.level() * 60
	xp.value = game.level_xp()
	xp.show_percentage = false
	xp.tooltip_text = "%d / %d XP" % [game.level_xp(), game.level() * 60]
	header.add_child(xp)

	_exact_button("nav_settings", "nav_settings", Rect2(1280, 14, 150, 60), show_settings, header)

func build_footer() -> void:
	_texture_rect("resource_bar_blank", Rect2(0, -2, 1015, 55), footer)
	var row := RUI.row(footer)
	row.position = Vector2(18, 7)
	row.size = Vector2(975, 38)
	row.add_theme_constant_override("separation", 5)
	for id in DB2.MATERIALS:
		var mat: Dictionary = DB2.MATERIALS[id]
		row.add_child(RUI.icon(int(mat.icon), 25))
		row.add_child(RUI.label("%s  %d" % [str(mat.name), int(game.data.materials[id])], 12, RUI.PAPER))
		var gap := Control.new()
		gap.custom_minimum_size.x = 7
		row.add_child(gap)
	row.add_child(RUI.icon(12, 25))
	row.add_child(RUI.label("Draughts  %d" % int(game.data.potions), 12, RUI.PAPER))

	_texture_rect("footer_bar_blank", Rect2(1020, -2, 372, 55), footer)
	var hint: String = "WASD / arrows · E interact · I pack · M map · C forge · J journal · F11 fullscreen"
	if screen == "battle":
		hint = "Q draught · Space pause · earned loot banks after each victory"
	var help := RUI.paragraph(hint, 10, RUI.MUTED)
	help.position = Vector2(1038, 12)
	help.size = Vector2(335, 35)
	footer.add_child(help)
	var version_label := RUI.label("HARKWOOD  /  PROTOTYPE 0.3", 9, RUI.GOLD)
	version_label.position = Vector2(1190, 55)
	footer.add_child(version_label)

func make_world(mode: String) -> Control:
	var node: Control = super.make_world(mode)
	_texture_rect("world_frame_exact", Rect2(Vector2.ZERO, node.size), node)
	return node

func add_scene_title(title: String, subtitle: String) -> void:
	if screen == "hub":
		_texture_rect("hub_title_plaque", Rect2(16, 10, 470, 95), world, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		return
	var backdrop := Panel.new()
	backdrop.position = Vector2(18, 16)
	backdrop.size = Vector2(470, 92)
	backdrop.add_theme_stylebox_override("panel", RUI.dark_panel_box())
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(backdrop)
	var title_label := RUI.label(title, 27, RUI.PAPER, true)
	title_label.position = Vector2(24, 15)
	backdrop.add_child(title_label)
	var caption: Label = RUI.label(subtitle, 11, RUI.GOLD)
	caption.position = Vector2(26, 55)
	backdrop.add_child(caption)

func new_sidebar(eyebrow: String, title: String, subtext: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
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
		["forge", "sign_hearthforge", Vector2(205, 246), Vector2(130, 55)],
		["market", "sign_trading", Vector2(610, 257), Vector2(142, 55)],
		["stash", "sign_chest", Vector2(80, 472), Vector2(124, 55)],
		["map", "sign_wilds", Vector2(770, 346), Vector2(156, 55)],
	]
	for data in stations:
		var id: String = str(data[0])
		_exact_button(str(data[1]), str(data[1]), Rect2(data[2], data[3]), func(): world.approach(id), world)

	var paper_host := Control.new()
	paper_host.position = Vector2(1000, 0)
	paper_host.size = Vector2(392, 680)
	page.add_child(paper_host)
	_texture_rect("sidebar_blank", Rect2(0, 0, 392, 680), paper_host)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(38, 42)
	scroll.size = Vector2(307, 594)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper_host.add_child(scroll)
	sidebar = RUI.column(scroll)
	sidebar.add_theme_constant_override("separation", 10)

	sidebar.add_child(RUI.label("REST, REFORGE, RETURN", 10, PAPER_ACCENT))
	var heading := RUI.paragraph("A little light survives.", 27, PAPER_INK)
	heading.add_theme_font_override("font", RUI.title_font)
	sidebar.add_child(heading)
	_paper_rule(sidebar)
	sidebar.add_child(RUI.paragraph("The hearth is yours. Gather what the woods surrender, then make something that can face them.", 13, PAPER_MUTED))

	var stats: Dictionary = game.stats()
	var portrait_row := RUI.row(sidebar)
	portrait_row.add_child(RUI.icon(1, 76, true))
	var info_col := RUI.column(portrait_row)
	info_col.add_child(RUI.label("The Wayfarer", 20, PAPER_INK, true))
	info_col.add_child(RUI.label("Level %d · %d expeditions" % [game.level(), total_clears()], 11, PAPER_MUTED))
	info_col.add_child(RUI.label("%d health   %d attack   %d armor" % [stats.health, stats.attack, stats.armor], 10, PAPER_GREEN))
	_paper_rule(sidebar)

	sidebar.add_child(RUI.label("YOUR NEXT THREAD", 10, PAPER_ACCENT))
	var next: Dictionary = next_quest()
	if next.is_empty():
		sidebar.add_child(RUI.paragraph("The Hollow Hart has fallen. The woods remain: perfect your gear, trade your finds, or begin again.", 14, PAPER_INK))
	else:
		sidebar.add_child(RUI.label(str(next.name), 17, PAPER_INK, true))
		sidebar.add_child(RUI.paragraph(str(next.text), 13, PAPER_MUTED))
		if game.quest_progress(next) >= int(next.target):
			sidebar.add_child(RUI.button("Collect journal reward", func(): claim(str(next.id)), 40))

	RUI.spacer(sidebar, 3)
	var actions := Control.new()
	actions.custom_minimum_size = Vector2(300, 158)
	sidebar.add_child(actions)
	_exact_button("action_map_exact", "action_map_hover", Rect2(0, 0, 300, 48), func(): request_screen("map"), actions)
	_exact_button("action_forge_exact", "action_forge_hover", Rect2(0, 54, 300, 48), func(): request_screen("forge"), actions)
	_exact_button("action_search_exact", "action_search_hover", Rect2(0, 108, 300, 48), func(): request_screen("inventory"), actions)
	sidebar.add_child(RUI.paragraph("Walk to a named station, or use the tabs above. You begin with materials for your first upgrades.", 10, PAPER_MUTED))

func _paper_rule(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(0.35, 0.25, 0.14, 0.42)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
