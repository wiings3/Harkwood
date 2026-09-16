extends Control
## Screen coordinator. Economy and combat rules live in independently tested cores.
const DB = preload("res://scripts/core/catalog.gd")
const State = preload("res://scripts/core/game_state.gd")
const Battle = preload("res://scripts/core/battle.gd")
const UI = preload("res://scripts/ui/palette.gd")
const World = preload("res://scripts/ui/world_view.gd")
const Sound = preload("res://scripts/ui/sound.gd")
var game = State.new()
var battle = Battle.new()
var sound: Node
var screen = "hub"
var page: Control
var header: Control
var footer: Control
var sidebar: VBoxContainer
var world: Control
var modal: Control
var toast_label: Label
var toast_time = 0.0
var render_pending = false
var selected_recipe = "iron_blade"
var selected_gear = ""
var inventory_tab = "bag"
var inventory_slot = "all"
var market_tab = "buy"
var selected_zone = "verge"
var stance = "balanced"
var battle_speed = 1.0
var paused = false
var traveling = false
var wave = 0
var phase = ""
var accumulator = 0.0
var between_time = 0.0
var run_gold = 0
var run_xp = 0
var run_loot: Dictionary = {}
var run_items: Array = []
var combat_log: Array[String] = []
var outcome = ""
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var attack_bar: ProgressBar
var hp_label: Label
var enemy_hp_label: Label
var battle_log_label: Label
var potion_button: Button
var state_label: Label
var test_mode = false
var saving_disabled = false

func _ready() -> void:
	theme = UI.initialize()
	sound = Sound.new()
	add_child(sound)
	if not test_mode:
		game.load_game()
		saving_disabled = game.load_message.begins_with("Save could not")
	sound.muted = game.data.muted
	selected_gear = game.data.equipped.get("weapon", "")
	_render()
	if not game.load_message.is_empty():
		toast(game.load_message)
	if not game.data.tutorial_seen and not test_mode:
		show_welcome()
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func _save() -> bool:
	if saving_disabled:
		toast("Saving is disabled to protect the unreadable original save. See Settings.")
		return false
	if test_mode:
		return true
	var success = game.save_game()
	if not success:
		toast("Could not save to disk. Keep the game open and check disk permissions.")
	return success

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if is_instance_valid(toast_label):
			toast_label.visible = toast_time > 0
	if screen != "battle" or paused or is_instance_valid(modal):
		return
	if phase == "between":
		between_time -= delta * battle_speed
		if between_time <= 0:
			start_wave()
	elif phase == "fighting":
		accumulator += minf(delta, 0.25) * battle_speed
		while accumulator >= 1.0 / 30.0 and phase == "fighting":
			accumulator -= 1.0 / 30.0
			for event in battle.tick(1.0 / 30.0):
				handle_battle_event(event)
		update_combat_bars()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			close_modal()
		elif screen == "battle":
			toggle_pause()
		else:
			show_settings()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(modal) or traveling:
		return
	if screen == "battle":
		if event.keycode == KEY_Q:
			use_potion()
		elif event.keycode == KEY_SPACE:
			toggle_pause()
		return
	match event.keycode:
		KEY_I: request_screen("inventory")
		KEY_M: request_screen("map")
		KEY_C: request_screen("forge")
		KEY_J: request_screen("journal")
		KEY_H: request_screen("hub")
		KEY_E:
			if screen == "hub" and is_instance_valid(world):
				world.interact()

func request_screen(destination: String) -> void:
	if traveling or (screen == "battle" and phase != "results"):
		return
	if destination == "stash":
		inventory_tab = "stash"
		destination = "inventory"
	elif destination == "inventory" and screen != "inventory":
		inventory_tab = "bag"
	screen = destination
	paused = false
	sound.play("click")
	refresh()

func refresh() -> void:
	if not render_pending:
		render_pending = true
		_render.call_deferred()

func _render() -> void:
	render_pending = false
	world = null
	for node in [header, page, footer]:
		if is_instance_valid(node):
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			node.queue_free()
	header = Control.new()
	header.size = Vector2(1440, 90)
	add_child(header)
	build_header()
	page = Control.new()
	page.position = Vector2(24, 112)
	page.size = Vector2(1392, 680)
	add_child(page)
	match screen:
		"hub": build_hub()
		"map": build_map()
		"inventory": build_inventory()
		"forge": build_forge()
		"market": build_market()
		"journal": build_journal()
		"battle": build_battle()
	footer = Control.new()
	footer.position = Vector2(24, 810)
	footer.size = Vector2(1392, 68)
	add_child(footer)
	build_footer()
	if is_instance_valid(toast_label):
		move_child(toast_label, -1)
	if is_instance_valid(modal):
		move_child(modal, -1)
		if is_instance_valid(world):
			world.active = false

func build_header() -> void:
	var mark = UI.label("HARKWOOD", 29, UI.PAPER, true)
	mark.position = Vector2(28, 22)
	header.add_child(mark)
	var edition = UI.label("A LANTERN AGAINST THE DARK", 9, UI.GOLD)
	edition.position = Vector2(30, 59)
	header.add_child(edition)
	var tabs = [["hub", "Hearth"], ["map", "Wilds"], ["inventory", "Pack"], ["forge", "Forge"], ["market", "Exchange"], ["journal", "Journal"]]
	var x = 297.0
	for tab in tabs:
		var id: String = tab[0]
		var nav = UI.button(tab[1], func(): request_screen(id), 40)
		nav.position = Vector2(x, 27)
		nav.size.x = 94 if id != "market" else 112
		nav.disabled = traveling or (screen == "battle" and phase != "results")
		if screen == id:
			nav.add_theme_stylebox_override("normal", UI.box(Color("354630"), UI.GOLD))
			nav.add_theme_color_override("font_color", UI.GOLD)
		header.add_child(nav)
		x += nav.size.x + 8
	var gold_icon = UI.icon(13, 26)
	gold_icon.position = Vector2(1000, 29)
	gold_icon.size = Vector2(32, 32)
	header.add_child(gold_icon)
	var money = UI.label(str(int(game.data.gold)), 20, UI.GOLD)
	money.position = Vector2(1040, 32)
	header.add_child(money)
	var level_badge = UI.label("LV. %02d" % game.level(), 16, UI.GREEN)
	level_badge.position = Vector2(1138, 27)
	header.add_child(level_badge)
	var xp = ProgressBar.new()
	xp.position = Vector2(1138, 53)
	xp.size = Vector2(110, 6)
	xp.max_value = game.level() * 60
	xp.value = game.level_xp()
	xp.show_percentage = false
	xp.tooltip_text = "%d / %d XP" % [game.level_xp(), game.level() * 60]
	header.add_child(xp)
	var settings = UI.button("Settings", show_settings, 38)
	settings.position = Vector2(1305, 28)
	settings.size.x = 106
	header.add_child(settings)
	var line = ColorRect.new()
	line.position = Vector2(24, 89)
	line.size = Vector2(1392, 1)
	line.color = UI.LINE
	header.add_child(line)

func build_footer() -> void:
	var row = UI.row(footer)
	row.position = Vector2(0, 4)
	row.size = Vector2(1392, 34)
	for id in DB.MATERIALS:
		var mat = DB.MATERIALS[id]
		row.add_child(UI.icon(mat.icon, 28))
		row.add_child(UI.label("%s  %d" % [mat.name, int(game.data.materials[id])], 14, UI.MUTED))
		var gap = Control.new()
		gap.custom_minimum_size.x = 16
		row.add_child(gap)
	row.add_child(UI.icon(12, 28))
	row.add_child(UI.label("Draughts  %d" % int(game.data.potions), 14, UI.MUTED))
	var hint = "WASD / arrows or click to walk  ·  E interact  ·  I pack  ·  M map  ·  C forge  ·  J journal  ·  F11 fullscreen"
	if screen == "battle":
		hint = "Q healing draught  ·  Space pause  ·  Loot is banked after each victory  ·  Retreat safely; defeat costs up to 20 gold"
	var help = UI.label(hint, 12, UI.MUTED)
	help.position = Vector2(0, 47)
	footer.add_child(help)
	var version_label = UI.label("OFFLINE PROTOTYPE  /  0.1", 10, UI.GOLD)
	version_label.position = Vector2(1192, 49)
	footer.add_child(version_label)

func new_sidebar(eyebrow: String, title: String, subtext: String = "") -> VBoxContainer:
	var panel = UI.panel(page, Rect2(1000, 0, 392, 680))
	sidebar = UI.scroll_column(panel)
	sidebar.add_theme_constant_override("separation", 13)
	sidebar.add_child(UI.label(eyebrow, 11, UI.GOLD))
	sidebar.add_child(UI.paragraph(title, 28, UI.PAPER))
	sidebar.get_child(sidebar.get_child_count() - 1).add_theme_font_override("font", UI.title_font)
	if subtext != "":
		sidebar.add_child(UI.paragraph(subtext, 14))
	UI.rule(sidebar)
	return sidebar

func add_scene_title(title: String, subtitle: String) -> void:
	var backdrop = Panel.new()
	backdrop.position = Vector2(16, 16)
	backdrop.size = Vector2(470, 78)
	backdrop.add_theme_stylebox_override("panel", UI.box(Color(0.055, 0.09, 0.07, 0.88), Color(0.3, 0.34, 0.26, 0.5)))
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(backdrop)
	var title_label = UI.label(title, 27, UI.PAPER, true)
	title_label.position = Vector2(17, 10)
	backdrop.add_child(title_label)
	var caption = UI.label(subtitle, 12, UI.GOLD)
	caption.position = Vector2(19, 49)
	backdrop.add_child(caption)

func make_world(mode: String) -> Control:
	var node = World.new()
	node.mode = mode
	if mode == "hub":
		node.background_path = "res://assets/art/hub.png"
	elif mode == "map":
		node.background_path = "res://assets/art/overworld.png"
	elif selected_zone == "quarry":
		node.background_path = "res://assets/art/quarry.png"
	elif selected_zone == "hollow":
		node.background_path = "res://assets/art/hollow.png"
	else:
		node.background_path = "res://assets/art/forest.png"
	node.size = Vector2(980, 680)
	page.add_child(node)
	return node

func build_hub() -> void:
	world = make_world("hub")
	world.station_requested.connect(request_screen)
	add_scene_title("The Lantern Hearth", "HARKWOOD  /  SANCTUARY")
	var stations = [
		["forge", "Hearthforge", Vector2(198, 245)],
		["market", "Trading post", Vector2(614, 257)],
		["stash", "Your chest", Vector2(84, 475)],
		["map", "Into the wilds  ›", Vector2(781, 350)]]
	for info in stations:
		var id: String = info[0]
		var station = UI.button(info[1], func(): world.approach(id), 35)
		station.position = info[2]
		station.add_theme_font_size_override("font_size", 13)
		station.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.10, 0.07, 0.88), UI.GOLD))
		world.add_child(station)
	new_sidebar("REST, REFORGE, RETURN", "A little light survives.", "The hearth is yours. Gather what the woods surrender, then make something that can face them.")
	var stats = game.stats()
	var portrait_row = UI.row(sidebar)
	portrait_row.add_child(UI.icon(1, 92, true))
	var info = UI.column(portrait_row)
	info.add_child(UI.label("The Wayfarer", 20, UI.PAPER, true))
	info.add_child(UI.label("Level %d · %d expeditions" % [game.level(), total_clears()], 13, UI.MUTED))
	info.add_child(UI.label("%d health   %d attack   %d armor" % [stats.health, stats.attack, stats.armor], 12, UI.GREEN))
	UI.rule(sidebar)
	sidebar.add_child(UI.label("YOUR NEXT THREAD", 11, UI.GOLD))
	var next = next_quest()
	if next.is_empty():
		sidebar.add_child(UI.paragraph("The Hollow Hart has fallen. The woods remain: perfect your gear, trade your finds, or begin again.", 16))
	else:
		sidebar.add_child(UI.label(next.name, 19, UI.PAPER, true))
		sidebar.add_child(UI.paragraph(next.text, 15))
		if game.quest_progress(next) >= next.target:
			sidebar.add_child(UI.button("Collect journal reward", func(): claim(next.id)))
	UI.spacer(sidebar, 4)
	sidebar.add_child(UI.button("Open the overworld  ›", func(): request_screen("map"), 47))
	sidebar.add_child(UI.button("Craft at the Hearthforge", func(): request_screen("forge")))
	sidebar.add_child(UI.button("Inspect your equipment", func(): request_screen("inventory")))
	sidebar.add_child(UI.paragraph("Walk to a named station, or use the tabs above. You begin with materials for your first upgrades.", 12))

func build_map() -> void:
	world = make_world("map")
	add_scene_title("The wilds of Harkwood", "CHOOSE A TRAIL  /  PREPARE BEFORE DEPARTURE")
	var hub_node = UI.button("⌂", func(): request_screen("hub"), 44)
	hub_node.position = world.nodes[0] - Vector2(22, 22)
	hub_node.size = Vector2(44, 44)
	world.add_child(hub_node)
	var hub_name = UI.label("Lantern Hearth", 19, UI.PAPER, true)
	hub_name.position = Vector2(56, 537)
	world.add_child(hub_name)
	for i in range(DB.ZONES.size()):
		var zone = DB.ZONES[i]
		var id: String = zone.id
		var unlocked = game.unlocked(id)
		var node_button = UI.button(str(i + 1) if unlocked else "×", func(): select_zone(id), 44)
		node_button.position = world.nodes[i + 1] - Vector2(22, 22)
		node_button.size = Vector2(44, 44)
		if selected_zone == id:
			node_button.add_theme_stylebox_override("normal", UI.box(Color("536047"), UI.GOLD, 2))
		world.add_child(node_button)
		var title = UI.label(zone.name, 19, UI.PAPER if unlocked else UI.MUTED, true)
		title.position = world.nodes[i + 1] + Vector2(-112, 42)
		world.add_child(title)
		var zone_info = UI.label("CLEARED" if game.data.clears.get(id, 0) > 0 else ("LEVEL %d" % zone.level if unlocked else "SEALED TRAIL"), 10, UI.GOLD if unlocked else UI.MUTED)
		zone_info.position = world.nodes[i + 1] + Vector2(-40, 72)
		world.add_child(zone_info)
	var legend = UI.label("Follow the lantern trail. Clear each region to reach the next.", 14, UI.PAPER)
	legend.position = Vector2(224, 631)
	world.add_child(legend)
	var selected = DB.zone(selected_zone)
	new_sidebar("EXPEDITION  /  RECOMMENDED LV. %d" % selected.level, selected.name, selected.description)
	sidebar.add_child(UI.label("WHAT WAITS THERE", 11, UI.GOLD))
	var enemies = UI.row(sidebar)
	for id in selected.waves:
		var enemy_col = UI.column(enemies)
		enemy_col.add_child(UI.icon(DB.ENEMIES[id].art, 92, true))
	sidebar.add_child(UI.paragraph(selected.drops, 13, UI.GREEN))
	UI.rule(sidebar)
	sidebar.add_child(UI.label("COMBAT STANCE", 11, UI.GOLD))
	var stance_row = UI.row(sidebar)
	for option in ["balanced", "fierce", "guarded"]:
		var value: String = option
		var btn = UI.button(option.capitalize(), func(): stance = value; refresh(), 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		if value == stance:
			btn.add_theme_stylebox_override("normal", UI.box(Color("354630"), UI.GOLD))
		stance_row.add_child(btn)
	var descriptions = {"balanced": "Normal damage dealt and received.", "fierce": "+20% damage dealt. +20% damage taken.", "guarded": "−15% damage dealt. −25% damage taken."}
	sidebar.add_child(UI.paragraph(descriptions[stance], 12))
	sidebar.add_child(UI.label("%d healing draughts packed" % int(game.data.potions), 14, UI.PAPER))
	var depart = UI.button("Begin expedition  ›" if game.unlocked(selected_zone) else "Clear the previous region first", depart_selected, 48)
	depart.disabled = not game.unlocked(selected_zone) or traveling
	sidebar.add_child(depart)
	sidebar.add_child(UI.paragraph("3 encounters. Health carries between fights with a small recovery. All earned loot is kept if you retreat.", 12))

func select_zone(id: String) -> void:
	if traveling:
		return
	selected_zone = id
	sound.play("click")
	refresh()

func depart_selected() -> void:
	if traveling or not game.unlocked(selected_zone):
		return
	traveling = true
	sound.play("click")
	set_buttons_disabled(header, true)
	set_buttons_disabled(sidebar, true)
	set_buttons_disabled(world, true)
	var index = 1
	for i in range(DB.ZONES.size()):
		if DB.ZONES[i].id == selected_zone:
			index = i + 1
	world.route_finished.connect(begin_expedition, CONNECT_ONE_SHOT)
	world.travel(index)

func set_buttons_disabled(node: Node, disabled: bool) -> void:
	for child in node.get_children():
		if child is Button:
			child.disabled = disabled
		set_buttons_disabled(child, disabled)

func build_inventory() -> void:
	var container = UI.panel(page, Rect2(0, 0, 980, 680))
	var content = UI.column(container)
	var title_row = UI.row(content)
	var title = UI.label("The wayfarer's pack", 28, UI.PAPER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(UI.label("%d / %d carried" % [game.data.bag.size(), State.BAG_LIMIT], 13, UI.MUTED))
	var stats = game.stats()
	content.add_child(UI.label("HEALTH %d     ATTACK %d     ARMOR %d     CRIT %d%%     HASTE %d%%" % [stats.health, stats.attack, stats.armor, stats.crit * 100, stats.haste * 100], 14, UI.GREEN))
	var slots = UI.row(content)
	for slot in DB.SLOTS:
		var id = game.data.equipped.get(slot, "")
		var item = game.find_gear(id)
		var slot_panel = PanelContainer.new()
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(slot_panel)
		var col = UI.column(slot_panel)
		col.add_child(UI.label(slot.to_upper(), 10, UI.GOLD))
		var slot_row = UI.row(col)
		if not item.is_empty():
			slot_row.add_child(UI.icon(DB.ITEMS[item.id].icon, 46))
			var button = UI.button(DB.ITEMS[item.id].name, func(): selected_gear = id; inventory_tab = "bag"; refresh(), 40)
			button.add_theme_font_size_override("font_size", 11)
			button.clip_text = true
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_row.add_child(button)
		else:
			slot_row.add_child(UI.label("Empty", 15, UI.MUTED))
	var tabs = UI.row(content)
	for tab in ["bag", "stash"]:
		var value: String = tab
		var button = UI.button("Backpack" if tab == "bag" else "Storage chest", func(): inventory_tab = value; selected_gear = ""; refresh(), 35)
		if inventory_tab == tab:
			button.add_theme_color_override("font_color", UI.GOLD)
		tabs.add_child(button)
	for slot in ["all", "weapon", "head", "body", "feet"]:
		var value: String = slot
		var button = UI.button(slot.capitalize(), func(): inventory_slot = value; refresh(), 34)
		button.add_theme_font_size_override("font_size", 12)
		if inventory_slot == slot:
			button.add_theme_color_override("font_color", UI.GOLD)
		tabs.add_child(button)
	var list = UI.scroll_column(content)
	var visible_count = 0
	for item in game.data[inventory_tab]:
		if inventory_slot != "all" and DB.ITEMS[item.id].slot != inventory_slot:
			continue
		visible_count += 1
		var uid: String = item.uid
		gear_row(list, item, "EQUIPPED" if game.equipped(uid) else "Inspect", func(): selected_gear = uid; refresh(), selected_gear == uid)
	if visible_count == 0:
		list.add_child(UI.paragraph("Nothing here yet. Craft equipment, explore the woods, or change the filter.", 18))
	var selected = game.find_gear(selected_gear, inventory_tab)
	if selected.is_empty():
		new_sidebar("EQUIPMENT", "Make your own luck.", "Select a piece of equipment to inspect its rolls, compare it with your equipped item, or improve it.")
		sidebar.add_child(UI.icon(1, 240, true))
		sidebar.add_child(UI.paragraph("Common · Fine · Enchanted\nFine and Enchanted gear gain one random property. All gear can be upgraded three times.", 15))
		return
	new_sidebar("%s  /  TIER %d" % [DB.RARITIES[int(selected.quality)].to_upper(), DB.ITEMS[selected.id].tier], game.gear_name(selected))
	sidebar.add_child(UI.icon(DB.ITEMS[selected.id].icon, 102))
	sidebar.add_child(UI.paragraph(DB.stats_text(game.gear_stats(selected)), 15, UI.QUALITY[int(selected.quality)]))
	var current = game.find_gear(game.data.equipped.get(DB.ITEMS[selected.id].slot, ""))
	if not current.is_empty() and current.uid != selected.uid:
		sidebar.add_child(UI.paragraph("Equipped: " + DB.ITEMS[current.id].name + "\n" + DB.stats_text(game.gear_stats(current)), 12))
	if inventory_tab == "stash":
		var take = UI.button("Move to backpack", func(): perform(game.transfer(selected.uid, false), "Moved to your backpack."))
		take.disabled = game.data.bag.size() >= State.BAG_LIMIT
		sidebar.add_child(take)
	else:
		sidebar.add_child(UI.button("Unequip" if game.equipped(selected.uid) else "Equip this item", func(): perform(game.equip(selected.uid), "Equipment updated.")))
		var upgrade = UI.button("Upgrade +%d   ·   %d gold" % [int(selected.rank) + 1, game.upgrade_price(selected)], func(): perform(game.upgrade(selected.uid), "Reforged. This item is stronger.", "forge"))
		upgrade.disabled = selected.rank >= 3 or not game.can_pay(game.upgrade_cost(selected), game.upgrade_price(selected))
		if selected.rank >= 3:
			upgrade.text = "Fully upgraded  +3"
		sidebar.add_child(upgrade)
		if selected.rank < 3:
			sidebar.add_child(UI.paragraph("Upgrade cost: " + cost_text(game.upgrade_cost(selected)) + ". +12% base stats per rank.", 12))
		var stash_btn = UI.button("Move to storage", func(): perform(game.transfer(selected.uid, true), "Stored safely."), 36)
		stash_btn.disabled = game.equipped(selected.uid)
		sidebar.add_child(stash_btn)
		var salvage_btn = UI.button("Salvage for iron & hide", func(): confirm_salvage(selected), 36)
		salvage_btn.disabled = game.equipped(selected.uid)
		sidebar.add_child(salvage_btn)
		sidebar.add_child(UI.label("Exchange guide price: %d gold" % game.item_value(selected), 12, UI.GOLD))

func gear_row(parent: Node, item: Dictionary, action: String, callback: Callable, selected: bool = false) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color("2a382c") if selected else UI.INK, UI.GOLD if selected else UI.LINE))
	parent.add_child(panel)
	var row = UI.row(panel)
	row.add_child(UI.icon(DB.ITEMS[item.id].icon, 57))
	var info = UI.column(row)
	info.add_child(UI.paragraph(game.gear_name(item), 15, UI.QUALITY[int(item.quality)]))
	info.add_child(UI.paragraph(DB.stats_text(game.gear_stats(item)), 12))
	var button = UI.button(action, callback, 37)
	button.custom_minimum_size.x = 96
	button.add_theme_font_size_override("font_size", 12)
	row.add_child(button)

func build_forge() -> void:
	var panel = UI.panel(page, Rect2(0, 0, 980, 680))
	var col = UI.column(panel)
	col.add_child(UI.label("The Hearthforge", 29, UI.PAPER, true))
	col.add_child(UI.paragraph("Wood, iron, and a little stubbornness. Every craft rolls its own quality.", 15))
	col.add_child(UI.label("65%% Common   ·   27%% Fine   ·   8%% Enchanted     /     Unlocked: Tier %d" % game.crafting_tier(), 12, UI.GOLD))
	var list = UI.scroll_column(col)
	for id in DB.ITEMS:
		var recipe = DB.ITEMS[id]
		if recipe.tier == 0:
			continue
		var recipe_id: String = id
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color("29392c") if selected_recipe == id else UI.INK, UI.GOLD if selected_recipe == id else UI.LINE))
		list.add_child(card)
		var row = UI.row(card)
		row.add_child(UI.icon(recipe.icon, 59))
		var description = UI.column(row)
		description.add_child(UI.label(recipe.name, 17, UI.PAPER, true))
		description.add_child(UI.label("Tier %d · %s" % [recipe.tier, DB.stats_text(recipe.stats)], 12, UI.GREEN))
		description.add_child(UI.label(cost_text(recipe.cost) + "  ·  %d gold" % recipe.gold, 12, UI.MUTED))
		var inspect_btn = UI.button("View recipe" if recipe.tier <= game.crafting_tier() else "Locked", func(): selected_recipe = recipe_id; refresh(), 36)
		inspect_btn.add_theme_font_size_override("font_size", 12)
		row.add_child(inspect_btn)
	var recipe = DB.ITEMS[selected_recipe]
	new_sidebar("CRAFTING  /  TIER %d" % recipe.tier, recipe.name)
	sidebar.add_child(UI.icon(recipe.icon, 138))
	sidebar.add_child(UI.paragraph(DB.stats_text(recipe.stats), 16, UI.GREEN))
	sidebar.add_child(UI.paragraph("Base stats shown. Fine and Enchanted rolls increase these values and add a random property.", 12))
	UI.rule(sidebar)
	for id in recipe.cost:
		var count = int(game.data.materials[id])
		sidebar.add_child(UI.label("%s   %d / %d" % [DB.MATERIALS[id].name, count, recipe.cost[id]], 14, UI.GREEN if count >= recipe.cost[id] else UI.RED))
	sidebar.add_child(UI.label("Gold   %d / %d" % [int(game.data.gold), recipe.gold], 14, UI.GOLD if game.data.gold >= recipe.gold else UI.RED))
	var button = UI.button("Craft equipment", craft_selected, 47)
	button.disabled = not game.can_craft(selected_recipe)
	sidebar.add_child(button)
	if recipe.tier > game.crafting_tier():
		sidebar.add_child(UI.paragraph("Clear the %s to unlock this recipe." % ("Mosslight Verge" if recipe.tier == 2 else "Briarstone Quarry"), 13, UI.RED))
	elif game.data.bag.size() >= State.BAG_LIMIT:
		sidebar.add_child(UI.paragraph("Your backpack is full. Store or salvage something first.", 13, UI.RED))
	sidebar.add_child(UI.button("Brew draught   ·   3 gold", func(): perform(game.brew_potion(), "A healing draught is ready.", "heal"), 36))
	sidebar.add_child(UI.paragraph("Draught recipe: 2 heartwood + 1 resin. Restores 50% maximum health in combat.", 12))

func craft_selected() -> void:
	var item = game.craft(selected_recipe)
	if item.is_empty():
		toast("Not enough materials, or the backpack is full.")
		return
	selected_gear = item.uid
	_save()
	sound.play("forge")
	refresh()
	var body = open_modal("Fresh from the forge", DB.RARITIES[int(item.quality)].to_upper() + " CRAFT")
	body.add_child(UI.icon(DB.ITEMS[item.id].icon, 135))
	body.add_child(UI.paragraph(game.gear_name(item), 24, UI.QUALITY[int(item.quality)]))
	body.add_child(UI.paragraph(DB.stats_text(game.gear_stats(item)), 17, UI.GREEN))
	var row = UI.row(body)
	row.add_child(UI.button("Equip now", func(): game.equip(item.uid); _save(); close_modal(); refresh()))
	row.add_child(UI.button("Keep in backpack", close_modal))

func build_market() -> void:
	var panel = UI.panel(page, Rect2(0, 0, 980, 680))
	var col = UI.column(panel)
	col.add_child(UI.label("The Lantern Exchange", 29, UI.PAPER, true))
	col.add_child(UI.paragraph("LOCAL SIMULATION · These are NPC offers and simulated buyers, not other players.", 13, UI.GOLD))
	var tabs = UI.row(col)
	for tab in ["buy", "sell", "listings", "materials"]:
		var value: String = tab
		var button = UI.button("My listings" if tab == "listings" else tab.capitalize(), func(): market_tab = value; refresh(), 36)
		if market_tab == tab:
			button.add_theme_color_override("font_color", UI.GOLD)
		tabs.add_child(button)
	var list = UI.scroll_column(col)
	match market_tab:
		"buy":
			for offer in game.data.offers:
				var uid: String = offer.item.uid
				gear_row(list, offer.item, "Buy · %dg" % offer.price, func(): perform(game.buy_offer(uid), "Purchased and placed in your pack."))
			if game.data.offers.is_empty():
				list.add_child(UI.paragraph("The stalls are empty. Stock refreshes when you complete an expedition.", 17))
		"sell":
			var count = 0
			for item in game.data.bag:
				if not game.equipped(item.uid):
					count += 1
					gear_row(list, item, "List item", func(): show_listing(item))
			if count == 0:
				list.add_child(UI.paragraph("No unequipped gear to list. Craft an extra piece or unequip an item in your pack.", 17))
		"listings":
			for listing in game.data.listings:
				var uid: String = listing.item.uid
				gear_row(list, listing.item, "Cancel · %dg" % listing.price, func(): perform(game.cancel_listing(uid), "Listing withdrawn. Your item was returned."))
			if game.data.listings.is_empty():
				list.add_child(UI.paragraph("You have no active listings. List spare equipment from the Sell tab.", 17))
		"materials":
			for id in DB.MATERIALS:
				var mat = DB.MATERIALS[id]
				var key: String = id
				var card = PanelContainer.new()
				list.add_child(card)
				var row = UI.row(card)
				row.add_child(UI.icon(mat.icon, 58))
				var info = UI.column(row)
				info.add_child(UI.label(mat.name, 19, UI.PAPER, true))
				info.add_child(UI.label("Owned: %d · %d gold each" % [int(game.data.materials[id]), mat.value], 13, UI.MUTED))
				var sell = UI.button("Sell 1", func(): perform(game.sell_material(key, 1), "Material sold."), 35)
				sell.disabled = game.data.materials[id] < 1
				row.add_child(sell)
				var sell_five = UI.button("Sell 5", func(): perform(game.sell_material(key, 5), "Materials sold."), 35)
				sell_five.disabled = game.data.materials[id] < 5
				row.add_child(sell_five)
	new_sidebar("THE TRADING POST", "Good steel finds a home.", "Buy a new roll, turn spare materials into gold, or offer your crafted gear for sale.")
	sidebar.add_child(UI.icon(13, 85))
	sidebar.add_child(UI.label("%d gold available" % int(game.data.gold), 22, UI.GOLD, true))
	UI.rule(sidebar)
	sidebar.add_child(UI.paragraph("Listings lock the item out of your inventory. Cancel any time to get it back. A 5% fee is taken only when it sells.", 14))
	sidebar.add_child(UI.paragraph("Simulated buyers check listings after each completed expedition. Guide price or lower sells reliably; high prices may not sell.", 14))
	sidebar.add_child(UI.label("%d / 8 listings · %d sales" % [game.data.listings.size(), int(game.data.sales)], 13, UI.GREEN))
	sidebar.add_child(UI.button("Buy healing draught  ·  12 gold", func(): perform(game.buy_potion(), "Draught purchased.", "heal")))
	sidebar.add_child(UI.paragraph("Real player trading is not connected in this build. Local progress will remain separate from future online characters.", 12, UI.GOLD))

func show_listing(item: Dictionary) -> void:
	var body = open_modal("Offer your handiwork", "LOCAL EXCHANGE")
	body.add_child(UI.paragraph(game.gear_name(item), 20, UI.QUALITY[int(item.quality)]))
	body.add_child(UI.paragraph("Guide price: %d gold. Maximum: %d gold. The item is held until sold or withdrawn." % [game.item_value(item), game.item_value(item) * 3], 15))
	var price = SpinBox.new()
	price.min_value = 1
	price.max_value = game.item_value(item) * 3
	price.step = 1
	price.value = game.item_value(item)
	price.suffix = "gold"
	body.add_child(price)
	body.add_child(UI.button("Create listing", func():
		var success = game.list_item(item.uid, int(price.value))
		close_modal()
		perform(success, "Your item is listed. Buyers visit after completed expeditions.")
	))

func build_journal() -> void:
	var panel = UI.panel(page, Rect2(0, 0, 980, 680))
	var content = UI.column(panel)
	content.add_child(UI.label("Threads in the dark", 30, UI.PAPER, true))
	content.add_child(UI.paragraph("Not every journey needs a prophecy. Sometimes a better blade is enough.", 15))
	var list = UI.scroll_column(content)
	for quest in DB.QUESTS:
		var id: String = quest.id
		var claimed = id in game.data.quests
		var progress = mini(game.quest_progress(quest), quest.target)
		var panel_row = PanelContainer.new()
		list.add_child(panel_row)
		var row = UI.row(panel_row)
		row.add_child(UI.icon(15, 65))
		var info = UI.column(row)
		info.add_child(UI.label(quest.name, 21, UI.MUTED if claimed else UI.PAPER, true))
		info.add_child(UI.paragraph(quest.text, 14))
		info.add_child(UI.paragraph("Reward: %d gold · %s" % [quest.gold, cost_text(quest.materials)], 12, UI.GOLD))
		var button = UI.button("Collected" if claimed else ("Collect reward" if progress >= quest.target else "%d / %d" % [progress, quest.target]), func(): claim(id), 40)
		button.disabled = claimed or progress < quest.target
		row.add_child(button)
	new_sidebar("FIELD NOTES", "The wood remembers.", "Harkwood was built around a single hearth. Beyond its lanterns, the roots have begun walking.")
	sidebar.add_child(UI.icon(7, 205, true))
	sidebar.add_child(UI.paragraph("Follow the old trail from the Mosslight Verge to Briarstone, then seek the Hollow Hart beneath the elder trees.", 15))
	UI.rule(sidebar)
	sidebar.add_child(UI.label("%d creatures defeated" % int(game.data.kills), 15, UI.GREEN))
	sidebar.add_child(UI.label("%d items crafted" % int(game.data.crafted), 15, UI.GREEN))
	sidebar.add_child(UI.label("%d / %d journal rewards collected" % [game.data.quests.size(), DB.QUESTS.size()], 15, UI.GREEN))
	sidebar.add_child(UI.paragraph("Build tip: armor reduces damage, haste speeds up attacks, critical hits deal 175% damage, and leech restores health on each hit.", 12))

func begin_expedition() -> void:
	traveling = false
	if not game.unlocked(selected_zone):
		return
	screen = "battle"
	phase = "fighting"
	wave = 0
	run_gold = 0
	run_xp = 0
	run_loot = {}
	run_items = []
	combat_log.clear()
	paused = false
	outcome = ""
	battle.rng.randomize()
	start_wave(true)

func start_wave(first: bool = false) -> void:
	var zone = DB.zone(selected_zone)
	var hp = -1.0 if first else minf(game.stats().health, battle.player_hp + game.stats().health * 0.15)
	battle.begin(game.stats(), zone.waves[wave], hp, stance)
	phase = "fighting"
	accumulator = 0
	append_log("%s approaches." % battle.enemy.name)
	refresh()

func build_battle() -> void:
	world = make_world("battle")
	world.enemy_art(battle.enemy.art)
	var zone = DB.zone(selected_zone)
	add_scene_title(zone.name, "ENCOUNTER %d / %d   ·   %s STANCE" % [wave + 1, zone.waves.size(), stance.to_upper()])
	var foe_title = UI.label(battle.enemy.name, 23, UI.PAPER, true)
	foe_title.position = Vector2(567, 191)
	world.add_child(foe_title)
	var hero_title = UI.label("The Wayfarer", 23, UI.PAPER, true)
	hero_title.position = Vector2(154, 191)
	world.add_child(hero_title)
	player_bar = make_bar(world, Rect2(147, 233, 237, 13), battle.player.health, UI.GREEN)
	enemy_bar = make_bar(world, Rect2(566, 233, 274, 13), battle.enemy.health, UI.RED)
	hp_label = UI.label("", 12, UI.PAPER)
	hp_label.position = Vector2(155, 252)
	world.add_child(hp_label)
	enemy_hp_label = UI.label("", 12, UI.PAPER)
	enemy_hp_label.position = Vector2(573, 252)
	world.add_child(enemy_hp_label)
	var status_panel = UI.panel(world, Rect2(22, 566, 936, 93), Color(0.06, 0.1, 0.07, 0.9))
	var status_col = UI.column(status_panel)
	state_label = UI.label("", 16, UI.GOLD)
	status_col.add_child(state_label)
	status_col.add_child(UI.label("Loot banked: %d gold · %d XP · %d equipment drops" % [run_gold, run_xp, run_items.size()], 13, UI.PAPER))
	new_sidebar("AUTO-COMBAT", "Steel meets the wild.", "Your equipment does the fighting. Watch your health, choose when to heal, and know when to turn back.")
	sidebar.add_child(UI.label("NEXT ATTACK", 11, UI.GOLD))
	attack_bar = ProgressBar.new()
	attack_bar.show_percentage = false
	attack_bar.max_value = 1
	attack_bar.custom_minimum_size.y = 7
	sidebar.add_child(attack_bar)
	potion_button = UI.button("", use_potion, 45)
	sidebar.add_child(potion_button)
	var controls = UI.row(sidebar)
	controls.add_child(UI.button("Resume" if paused else "Pause", toggle_pause, 37))
	controls.add_child(UI.button("Speed %dx" % int(battle_speed), func(): battle_speed = 2.0 if battle_speed == 1.0 else 1.0; refresh(), 37))
	controls.add_child(UI.button("Retreat", confirm_retreat, 37))
	UI.rule(sidebar)
	sidebar.add_child(UI.label("THE ENCOUNTER", 11, UI.GOLD))
	battle_log_label = UI.paragraph("\n".join(combat_log), 13)
	battle_log_label.custom_minimum_size.y = 195
	sidebar.add_child(battle_log_label)
	sidebar.add_child(UI.paragraph("The Hollow Hart enrages below 40% health. Draughts restore half your maximum health and have a 6-second cooldown.", 12))
	update_combat_bars()
	if phase == "results":
		show_results_panel()

func make_bar(parent: Node, rect: Rect2, maximum: float, tint: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = maximum
	bar.show_percentage = false
	var fill = UI.box(tint.darkened(0.2), tint, 0, 3)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func update_combat_bars() -> void:
	if not is_instance_valid(player_bar):
		return
	player_bar.value = battle.player_hp
	enemy_bar.value = battle.enemy_hp
	hp_label.text = "%d / %d HP" % [ceili(battle.player_hp), battle.player.health]
	enemy_hp_label.text = "%d / %d HP" % [ceili(battle.enemy_hp), battle.enemy.health]
	attack_bar.value = 1.0 - battle.player_clock / battle.interval()
	potion_button.text = "Healing draught [Q]  ·  %d" % int(game.data.potions)
	if battle.potion_cooldown > 0:
		potion_button.text += "  ·  %.1fs" % battle.potion_cooldown
	potion_button.disabled = phase != "fighting" or paused or game.data.potions <= 0 or battle.potion_cooldown > 0 or battle.player_hp >= battle.player.health
	state_label.text = "Preparing the next encounter... +15% health" if phase == "between" else ("Expedition concluded" if phase == "results" else ("Paused — take your time" if paused else "Fighting automatically  ·  %dx speed" % int(battle_speed)))
	if battle.enemy_id == "elder" and battle.enemy_hp < battle.enemy.health * 0.4 and phase == "fighting":
		state_label.text = "THE HOLLOW HART IS ENRAGED  ·  +25% enemy damage"

func handle_battle_event(event: Dictionary) -> void:
	match event.type:
		"hit":
			if is_instance_valid(world):
				world.hit(event.actor)
				floating_text("%d%s" % [event.damage, "!" if event.crit else ""], event.actor != "player", UI.GOLD if event.crit else (UI.PAPER if event.actor == "player" else UI.RED))
			sound.play("hit" if event.actor == "player" else "hurt")
			append_log("%s hits for %d%s" % ["You" if event.actor == "player" else battle.enemy.name, event.damage, " — critical!" if event.crit else "."])
		"won":
			var reward = game.reward_enemy(battle.enemy_id)
			run_gold += reward.gold
			run_xp += reward.xp
			for id in reward.materials:
				run_loot[id] = int(run_loot.get(id, 0)) + reward.materials[id]
			if reward.gear != "":
				run_items.append(reward.gear)
			append_log("Victory. +%d gold, +%d XP." % [reward.gold, reward.xp])
			var zone = DB.zone(selected_zone)
			if wave + 1 >= zone.waves.size():
				run_gold += game.complete_zone(selected_zone)
				end_expedition("victory")
			else:
				wave += 1
				phase = "between"
				between_time = 1.6
				_save()
				update_combat_bars()
		"lost":
			var penalty = mini(20, floori(game.data.gold * 0.1))
			game.data.gold = int(game.data.gold) - penalty
			append_log("Rescued by a lantern-keeper. −%d gold." % penalty)
			end_expedition("defeat")

func end_expedition(result: String) -> void:
	phase = "results"
	outcome = result
	paused = false
	battle.status = "finished"
	_save()
	sound.play("win" if result == "victory" else ("lose" if result == "defeat" else "click"))
	refresh()

func show_results_panel() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.04, 0.03, 0.78)
	overlay.size = world.size
	world.add_child(overlay)
	var panel = UI.panel(world, Rect2(152, 110, 676, 454))
	var col = UI.column(panel)
	col.add_child(UI.label("EXPEDITION COMPLETE" if outcome == "victory" else "BACK FROM THE BRINK", 11, UI.GOLD))
	var titles = {"victory": "A little further into the dark.", "defeat": "The hearth still burns for you.", "retreat": "Live to walk another trail."}
	if selected_zone == "hollow" and outcome == "victory":
		titles.victory = "The Hollow Hart has fallen."
	col.add_child(UI.paragraph(titles[outcome], 29, UI.PAPER))
	col.get_child(col.get_child_count() - 1).add_theme_font_override("font", UI.title_font)
	col.add_child(UI.paragraph("Your earned loot is safe. Return to the hearth to craft, equip and claim journal rewards." if outcome != "defeat" else "You lost 10% of your gold, capped at 20. Your equipment and gathered materials are safe. Try upgrading or choosing Guarded stance.", 15))
	UI.rule(col)
	col.add_child(UI.label("%d GOLD     %d EXPERIENCE" % [run_gold, run_xp], 20, UI.GOLD))
	col.add_child(UI.paragraph(cost_text(run_loot) if not run_loot.is_empty() else "No materials gathered this time.", 16, UI.GREEN))
	if not run_items.is_empty():
		col.add_child(UI.paragraph("Equipment found: " + ", ".join(run_items), 13, UI.QUALITY[2]))
	if outcome == "victory":
		col.add_child(UI.paragraph("New recipes and trails unlock after first clears. Check your journal for unclaimed rewards.", 13))
	var buttons = UI.row(col)
	buttons.add_child(UI.button("Return to the hearth", func(): request_screen("hub"), 44))
	buttons.add_child(UI.button("Open journal", func(): request_screen("journal"), 44))
	buttons.add_child(UI.button("Travel again", func(): request_screen("map"), 44))
	set_buttons_disabled(sidebar, true)

func append_log(text: String) -> void:
	combat_log.append(text)
	while combat_log.size() > 7:
		combat_log.pop_front()
	if is_instance_valid(battle_log_label):
		battle_log_label.text = "\n".join(combat_log)

func floating_text(text: String, on_player: bool, color: Color) -> void:
	var label = UI.label(text, 33, color, true)
	label.add_theme_color_override("font_outline_color", UI.INK)
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(265 if on_player else 694, 327)
	world.add_child(label)
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 62, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func use_potion() -> void:
	if screen != "battle" or phase != "fighting" or paused or is_instance_valid(modal) or int(game.data.potions) <= 0:
		return
	var amount = battle.heal()
	if amount <= 0:
		return
	game.data.potions = int(game.data.potions) - 1
	_save()
	sound.play("heal")
	floating_text("+%d" % amount, true, UI.GREEN)
	append_log("Draught restores %d health." % amount)
	update_combat_bars()

func toggle_pause() -> void:
	if phase not in ["fighting", "between"]:
		return
	paused = not paused
	refresh()

func confirm_retreat() -> void:
	if phase == "results":
		return
	var body = open_modal("Head for the lanterns?", "RETREAT")
	body.add_child(UI.paragraph("Keep everything earned from defeated enemies. You will not receive the region's completion bonus or unlock its next trail.", 17))
	body.add_child(UI.button("Retreat with my loot", func(): close_modal(); end_expedition("retreat")))

func claim(id: String) -> void:
	perform(game.claim_quest(id), "Journal reward collected.", "win")

func confirm_salvage(item: Dictionary) -> void:
	var body = open_modal("Return it to the forge?", "SALVAGE EQUIPMENT")
	body.add_child(UI.paragraph("Salvaging permanently consumes " + game.gear_name(item) + ". You receive %d iron and %d hide." % [maxi(1, DB.ITEMS[item.id].tier), maxi(1, DB.ITEMS[item.id].tier)], 16))
	body.add_child(UI.button("Salvage this item", func(): close_modal(); perform(game.salvage(item.uid), "Reclaimed iron and hide.", "forge")))

func perform(success: bool, message: String, cue: String = "click") -> void:
	if success:
		_save()
		sound.play(cue)
		toast(message)
		refresh()
	else:
		toast("Cannot do that yet. Check your gold, materials, equipment or backpack space.")

func toast(message: String) -> void:
	if not is_instance_valid(toast_label):
		toast_label = UI.paragraph("", 15, UI.GOLD)
		toast_label.position = Vector2(300, 92)
		toast_label.size = Vector2(1045, 22)
		toast_label.add_theme_color_override("font_outline_color", UI.INK)
		toast_label.add_theme_constant_override("outline_size", 5)
		add_child(toast_label)
	toast_label.text = message
	toast_label.visible = true
	toast_time = 6.0
	move_child(toast_label, -1)

func open_modal(title: String, eyebrow: String = "HARKWOOD") -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(570, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.GOLD))
	center.add_child(panel)
	var col = UI.column(panel)
	col.custom_minimum_size.x = 540
	col.add_theme_constant_override("separation", 17)
	col.add_child(UI.label(eyebrow, 11, UI.GOLD))
	col.add_child(UI.label(title, 28, UI.PAPER, true))
	UI.rule(col)
	var body = UI.column(col)
	UI.spacer(col, 2)
	col.add_child(UI.button("Close  [Esc]", close_modal, 36))
	if is_instance_valid(world):
		world.active = false
	return body

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.visible = false
		modal.queue_free()
		modal = null
	if is_instance_valid(world):
		world.active = true

func show_welcome() -> void:
	var body = open_modal("A lantern against the dark.", "WELCOME TO HARKWOOD")
	body.add_child(UI.paragraph("A hand-drawn RPG about what you bring back, and what you make of it.", 19, UI.PAPER))
	body.add_child(UI.paragraph("1. Craft a Hearthforged blade with your starting materials.\n\n2. Equip it, then choose a trail on the Wilds map.\n\n3. Watch automatic battles, heal with Q, and bring back loot.\n\n4. Claim journal rewards, improve your gear, and face the Hollow Hart.", 16))
	body.add_child(UI.paragraph("Trading is a local NPC simulation in this prototype. Your progress saves automatically. No account or internet needed.", 13, UI.GOLD))
	body.add_child(UI.button("Enter Harkwood", func(): game.data.tutorial_seen = true; _save(); close_modal(), 46))

func show_settings() -> void:
	if traveling:
		return
	var body = open_modal("By the fireside", "SETTINGS & HELP")
	var audio_btn = UI.button("Enable sound" if sound.muted else "Mute sound", func():
		sound.muted = not sound.muted
		game.data.muted = sound.muted
		_save()
		show_settings()
	)
	body.add_child(audio_btn)
	body.add_child(UI.button("Save progress now", func():
		if _save(): toast("Progress saved.")
	))
	body.add_child(UI.paragraph("WASD / arrows or click: walk in the hub\nE: interact with a nearby station\nI: pack · M: wilds · C: forge · J: journal · H: hearth\nQ: heal in combat · Space: pause · F11: fullscreen", 14))
	body.add_child(UI.paragraph("Saves: user://harkwood_save.json\nA previous valid save is kept as .bak. Closing during an expedition returns you to the hub with already banked loot.", 12))
	if saving_disabled:
		body.add_child(UI.paragraph("The existing save was unreadable. Saving is disabled until you choose New journey. Your original files have not been changed.", 13, UI.RED))
	body.add_child(UI.button("New journey…", confirm_new_game, 36))

func confirm_new_game() -> void:
	var body = open_modal("Leave this journey behind?", "START OVER")
	body.add_child(UI.paragraph("This replaces your active character and progression. The current save and backup will be copied to timestamped archive files first. This action never touches other projects.", 17))
	body.add_child(UI.button("Archive this save and start anew", func():
		if not test_mode:
			var stamp = str(Time.get_unix_time_from_system()).replace(".", "-")
			for path in [game.save_path, game.save_path + ".bak"]:
				if FileAccess.file_exists(path):
					if DirAccess.copy_absolute(path, path + ".archive-" + stamp) != OK:
						toast("Could not archive the save. Your current journey is unchanged.")
						return
		game.new_game()
		saving_disabled = false
		game.data.tutorial_seen = true
		sound.muted = false
		phase = ""
		paused = false
		screen = "hub"
		selected_gear = ""
		selected_zone = "verge"
		_save()
		close_modal()
		refresh()
	))

func cost_text(cost: Dictionary) -> String:
	var pieces: PackedStringArray = []
	for id in cost:
		pieces.append("%d %s" % [cost[id], DB.MATERIALS[id].name])
	return " · ".join(pieces)

func total_clears() -> int:
	var total = 0
	for count in game.data.clears.values():
		total += int(count)
	return total

func next_quest() -> Dictionary:
	for quest in DB.QUESTS:
		if quest.id not in game.data.quests:
			return quest
	return {}
