extends "res://scripts/harkwood_game.gd"
## Node-based presentation controller.
## All persistent HUD/screen layout lives in scenes/ui/*.tscn and is editable in Godot.

const HUB_SCENE = preload("res://scenes/ui/screens/hub_screen.tscn")
const MAP_SCENE = preload("res://scenes/ui/screens/map_screen.tscn")
const INVENTORY_SCENE = preload("res://scenes/ui/screens/inventory_screen.tscn")
const FORGE_SCENE = preload("res://scenes/ui/screens/forge_screen.tscn")
const MARKET_SCENE = preload("res://scenes/ui/screens/market_screen.tscn")
const JOURNAL_SCENE = preload("res://scenes/ui/screens/journal_screen.tscn")
const BATTLE_SCENE = preload("res://scenes/ui/screens/battle_screen.tscn")
const MODAL_SCENE = preload("res://scenes/ui/modal.tscn")
const RESULTS_SCENE = preload("res://scenes/ui/results_panel.tscn")
const LIST_ROW_SCENE = preload("res://scenes/ui/list_row.tscn")
const TEXT_LINE_SCENE = preload("res://scenes/ui/text_line.tscn")
const ACTION_BUTTON_SCENE = preload("res://scenes/ui/action_button.tscn")
const ICON_BLOCK_SCENE = preload("res://scenes/ui/icon_block.tscn")
const NUMBER_INPUT_SCENE = preload("res://scenes/ui/number_input.tscn")

@onready var hud: Control = $HUD
var screen_root: Control

func _ready() -> void:
	# Parent sets up state, save data, sound, theme and then calls _render().
	super._ready()

func _render() -> void:
	render_pending = false
	world = null
	header = hud.get_node("Header")
	page = hud.get_node("Page")
	footer = hud.get_node("Footer")
	toast_label = hud.get_node("Toast")
	_clear_children(page)
	_bind_header()
	_bind_footer()
	match screen:
		"hub": _build_hub_scene()
		"map": _build_map_scene()
		"inventory": _build_inventory_scene()
		"forge": _build_forge_scene()
		"market": _build_market_scene()
		"journal": _build_journal_scene()
		"battle": _build_battle_scene()
	if is_instance_valid(modal):
		hud.move_child(modal, -1)
		if is_instance_valid(world):
			world.active = false

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _connect_once(button: BaseButton, callback: Callable) -> void:
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection.callable)
	button.pressed.connect(callback)

func _bind_header() -> void:
	var disabled := traveling or (screen == "battle" and phase != "results")
	var nav := {
		"Hearth": "hub", "Wilds": "map", "Pack": "inventory",
		"Forge": "forge", "Exchange": "market", "Journal": "journal"
	}
	for node_name in nav:
		var button: Button = header.get_node(node_name)
		var destination: String = nav[node_name]
		_connect_once(button, func(): request_screen(destination))
		button.disabled = disabled
		button.remove_theme_color_override("font_color")
		if screen == destination:
			button.add_theme_color_override("font_color", UI2.GOLD)
	var gold_icon: TextureRect = header.get_node("GoldIcon")
	gold_icon.texture = UI2.atlas(13)
	var gold_label: Label = header.get_node("Gold")
	gold_label.text = str(int(game.data.gold))
	gold_label.add_theme_color_override("font_color", UI2.GOLD)
	var level_label: Label = header.get_node("Level")
	level_label.text = "LV. %02d" % game.level()
	level_label.add_theme_color_override("font_color", UI2.GREEN)
	var xp: ProgressBar = header.get_node("XP")
	xp.max_value = game.level() * 60
	xp.value = game.level_xp()
	xp.tooltip_text = "%d / %d XP" % [game.level_xp(), game.level() * 60]
	_connect_once(header.get_node("Settings"), show_settings)

func _bind_footer() -> void:
	var resources: HBoxContainer = footer.get_node("Resources")
	var ids := ["wood", "hide", "iron", "amber", "core"]
	var names := ["Wood", "Hide", "Iron", "Amber", "Core"]
	for i in range(ids.size()):
		var id: String = ids[i]
		var icon: TextureRect = resources.get_node(names[i] + "Icon")
		icon.texture = UI2.atlas(DB2.MATERIALS[id].icon)
		var label: Label = resources.get_node(names[i])
		label.text = "%s  %d" % [DB2.MATERIALS[id].name, int(game.data.materials[id])]
		label.add_theme_color_override("font_color", UI2.MUTED)
	resources.get_node("DraughtIcon").texture = UI2.atlas(12)
	resources.get_node("Draughts").text = "Draughts  %d" % int(game.data.potions)
	var help: Label = footer.get_node("Help")
	help.text = "Q healing draught  ·  Space pause  ·  Loot is banked after each victory  ·  Retreat safely; defeat costs up to 20 gold" if screen == "battle" else "WASD / arrows or click to walk  ·  E interact  ·  I pack  ·  M map  ·  C forge  ·  J journal  ·  F11 fullscreen"
	help.add_theme_color_override("font_color", UI2.MUTED)
	var version: Label = footer.get_node("Version")
	version.text = "PROTOTYPE  /  0.2"
	version.add_theme_color_override("font_color", UI2.GOLD)

func _instantiate_screen(scene: PackedScene) -> Control:
	screen_root = scene.instantiate()
	page.add_child(screen_root)
	return screen_root

func _style_heading(label: Label) -> void:
	label.add_theme_font_override("font", UI2.title_font)
	label.add_theme_color_override("font_color", UI2.PAPER)

func _style_scene_title(root: Node) -> void:
	if root.has_node("World/SceneTitle/Title"):
		_style_heading(root.get_node("World/SceneTitle/Title"))
		root.get_node("World/SceneTitle/Subtitle").add_theme_color_override("font_color", UI2.GOLD)

func _build_hub_scene() -> void:
	var root := _instantiate_screen(HUB_SCENE)
	world = root.get_node("World")
	world.mode = "hub"
	world.background_path = "res://assets/art/hub.png"
	world.station_requested.connect(request_screen)
	_style_scene_title(root)
	var station_map := {
		"Hearthforge": "forge", "TradingPost": "market", "Chest": "stash", "Wilds": "map"
	}
	for node_name in station_map:
		var destination: String = station_map[node_name]
		_connect_once(world.get_node(node_name), func(): world.approach(destination))
	var content: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	content.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	_style_heading(content.get_node("Heading"))
	content.get_node("Intro").add_theme_color_override("font_color", UI2.MUTED)
	content.get_node("Player/Portrait").texture = UI2.atlas(1, true)
	_style_heading(content.get_node("Player/Info/Name"))
	var stats: Dictionary = game.stats()
	content.get_node("Player/Info/Progress").text = "Level %d · %d expeditions" % [game.level(), total_clears()]
	content.get_node("Player/Info/Progress").add_theme_color_override("font_color", UI2.MUTED)
	content.get_node("Player/Info/Stats").text = "%d health   %d attack   %d armor" % [stats.health, stats.attack, stats.armor]
	content.get_node("Player/Info/Stats").add_theme_color_override("font_color", UI2.GREEN)
	content.get_node("ThreadLabel").add_theme_color_override("font_color", UI2.GOLD)
	var quest: Dictionary = next_quest()
	var quest_title: Label = content.get_node("QuestTitle")
	var quest_text: Label = content.get_node("QuestText")
	var claim: Button = content.get_node("Claim")
	if quest.is_empty():
		quest_title.text = "The Hollow Hart has fallen."
		quest_text.text = "The woods remain: perfect your gear, trade your finds, or begin again."
		claim.visible = false
	else:
		quest_title.text = str(quest.name)
		quest_text.text = str(quest.text)
		claim.visible = game.quest_progress(quest) >= int(quest.target)
		var quest_id: String = str(quest.id)
		_connect_once(claim, func(): claim_quest_from_ui(quest_id))
	_style_heading(quest_title)
	quest_text.add_theme_color_override("font_color", UI2.MUTED)
	_connect_once(content.get_node("Map"), func(): request_screen("map"))
	_connect_once(content.get_node("Forge"), func(): request_screen("forge"))
	_connect_once(content.get_node("Inventory"), func(): request_screen("inventory"))
	content.get_node("Tip").add_theme_color_override("font_color", UI2.MUTED)
	sidebar = content

func claim_quest_from_ui(id: String) -> void:
	claim(id)

func _build_map_scene() -> void:
	var root := _instantiate_screen(MAP_SCENE)
	world = root.get_node("World")
	world.mode = "map"
	world.background_path = "res://assets/art/overworld.png"
	_style_scene_title(root)
	_connect_once(world.get_node("HearthNode"), func(): request_screen("hub"))
	var zone_nodes := ["Verge", "Quarry", "Hollow"]
	var zone_name_nodes := ["VergeName", "QuarryName", "HollowName"]
	var zone_info_nodes := ["VergeInfo", "QuarryInfo", "HollowInfo"]
	for i in range(DB2.ZONES.size()):
		var zone: Dictionary = DB2.ZONES[i]
		var id: String = str(zone.id)
		var unlocked: bool = game.unlocked(id)
		var button: Button = world.get_node(zone_nodes[i])
		button.text = str(i + 1) if unlocked else "×"
		button.disabled = not unlocked
		_connect_once(button, func(): select_zone(id))
		var title: Label = world.get_node(zone_name_nodes[i])
		title.text = str(zone.name)
		title.add_theme_color_override("font_color", UI2.PAPER if unlocked else UI2.MUTED)
		_style_heading(title)
		var info: Label = world.get_node(zone_info_nodes[i])
		info.text = "CLEARED" if game.data.clears.get(id, 0) > 0 else ("LEVEL %d" % zone.level if unlocked else "SEALED TRAIL")
		info.add_theme_color_override("font_color", UI2.GOLD if unlocked else UI2.MUTED)
	var selected: Dictionary = DB2.zone(selected_zone)
	var content: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	content.get_node("Eyebrow").text = "EXPEDITION  /  RECOMMENDED LV. %d" % selected.level
	content.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	content.get_node("Title").text = str(selected.name)
	_style_heading(content.get_node("Title"))
	content.get_node("Description").text = str(selected.description)
	content.get_node("Description").add_theme_color_override("font_color", UI2.MUTED)
	content.get_node("EnemyLabel").add_theme_color_override("font_color", UI2.GOLD)
	for i in range(3):
		content.get_node("Enemies/Enemy%d" % [i + 1]).texture = UI2.atlas(DB2.ENEMIES[selected.waves[i]].art, true)
	content.get_node("Drops").text = str(selected.drops)
	content.get_node("Drops").add_theme_color_override("font_color", UI2.GREEN)
	content.get_node("StanceLabel").add_theme_color_override("font_color", UI2.GOLD)
	var descriptions := {"balanced": "Normal damage dealt and received.", "fierce": "+20% damage dealt. +20% damage taken.", "guarded": "−15% damage dealt. −25% damage taken."}
	for option in ["balanced", "fierce", "guarded"]:
		var button: Button = content.get_node("Stances/" + option.capitalize())
		var value: String = option
		_connect_once(button, func(): stance = value; refresh())
		button.remove_theme_color_override("font_color")
		if stance == option:
			button.add_theme_color_override("font_color", UI2.GOLD)
	content.get_node("StanceDescription").text = descriptions[stance]
	content.get_node("Draughts").text = "%d healing draughts packed" % int(game.data.potions)
	var depart: Button = content.get_node("Depart")
	depart.text = "Begin expedition  ›" if game.unlocked(selected_zone) else "Clear the previous region first"
	depart.disabled = not game.unlocked(selected_zone) or traveling
	_connect_once(depart, depart_selected)
	sidebar = content

func _build_inventory_scene() -> void:
	var root := _instantiate_screen(INVENTORY_SCENE)
	var content: VBoxContainer = root.get_node("Main/Content")
	_style_heading(content.get_node("TitleRow/Title"))
	content.get_node("TitleRow/Carry").text = "%d / %d carried" % [game.data.bag.size(), State.BAG_LIMIT]
	content.get_node("TitleRow/Carry").add_theme_color_override("font_color", UI2.MUTED)
	var stats: Dictionary = game.stats()
	content.get_node("Stats").text = "HEALTH %d     ATTACK %d     ARMOR %d     CRIT %d%%     HASTE %d%%" % [stats.health, stats.attack, stats.armor, stats.crit * 100, stats.haste * 100]
	content.get_node("Stats").add_theme_color_override("font_color", UI2.GREEN)
	for slot in DB2.SLOTS:
		var button: Button = content.get_node("Equipment/" + slot.capitalize())
		var uid: String = str(game.data.equipped.get(slot, ""))
		var item: Dictionary = game.find_gear(uid)
		button.text = slot.to_upper() + "\n" + ("Empty" if item.is_empty() else DB2.ITEMS[item.id].name)
		button.disabled = item.is_empty()
		if not item.is_empty():
			_connect_once(button, func(): selected_gear = uid; inventory_tab = "bag"; refresh())
	for tab in ["bag", "stash"]:
		var button: Button = content.get_node("Tabs/" + ("Bag" if tab == "bag" else "Stash"))
		var value: String = tab
		_connect_once(button, func(): inventory_tab = value; selected_gear = ""; refresh())
		button.remove_theme_color_override("font_color")
		if inventory_tab == tab: button.add_theme_color_override("font_color", UI2.GOLD)
	for filter in ["all", "weapon", "head", "body", "feet"]:
		var button: Button = content.get_node("Tabs/" + filter.capitalize())
		var value: String = filter
		_connect_once(button, func(): inventory_slot = value; refresh())
		button.remove_theme_color_override("font_color")
		if inventory_slot == filter: button.add_theme_color_override("font_color", UI2.GOLD)
	var list: VBoxContainer = content.get_node("Scroll/List")
	var visible_count := 0
	for item in game.data[inventory_tab]:
		if inventory_slot != "all" and DB2.ITEMS[item.id].slot != inventory_slot:
			continue
		visible_count += 1
		var candidate: Dictionary = item
		var uid: String = str(candidate.uid)
		_add_gear_row(list, candidate, "EQUIPPED" if game.equipped(uid) else "Inspect", func(): selected_gear = uid; refresh(), selected_gear == uid)
	if visible_count == 0:
		_add_text(list, "Nothing here yet. Craft equipment, explore the woods, or change the filter.", 18)
	_bind_inventory_sidebar(root)

func _bind_inventory_sidebar(root: Node) -> void:
	var content: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	sidebar = content
	content.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	var selected: Dictionary = game.find_gear(selected_gear, inventory_tab)
	var icon: TextureRect = content.get_node("Icon")
	var stats_label: Label = content.get_node("Stats")
	var compare: Label = content.get_node("Compare")
	var primary: Button = content.get_node("Primary")
	var upgrade: Button = content.get_node("Upgrade")
	var storage: Button = content.get_node("Storage")
	var salvage: Button = content.get_node("Salvage")
	var value_label: Label = content.get_node("Value")
	for node in [compare, primary, upgrade, storage, salvage, value_label]: node.visible = false
	if selected.is_empty():
		content.get_node("Eyebrow").text = "EQUIPMENT"
		content.get_node("Title").text = "Make your own luck."
		_style_heading(content.get_node("Title"))
		icon.texture = UI2.atlas(1, true)
		stats_label.text = "Select a piece of equipment to inspect its rolls, compare it with your equipped item, or improve it."
		stats_label.add_theme_color_override("font_color", UI2.MUTED)
		return
	content.get_node("Eyebrow").text = "%s  /  TIER %d" % [DB2.RARITIES[int(selected.quality)].to_upper(), DB2.ITEMS[selected.id].tier]
	content.get_node("Title").text = game.gear_name(selected)
	_style_heading(content.get_node("Title"))
	icon.texture = UI2.atlas(DB2.ITEMS[selected.id].icon)
	stats_label.text = DB2.stats_text(game.gear_stats(selected))
	stats_label.add_theme_color_override("font_color", UI2.QUALITY[int(selected.quality)])
	var current: Dictionary = game.find_gear(game.data.equipped.get(DB2.ITEMS[selected.id].slot, ""))
	if not current.is_empty() and current.uid != selected.uid:
		compare.visible = true
		compare.text = "Equipped: " + DB2.ITEMS[current.id].name + "\n" + DB2.stats_text(game.gear_stats(current))
	if inventory_tab == "stash":
		primary.visible = true
		primary.text = "Move to backpack"
		primary.disabled = game.data.bag.size() >= State.BAG_LIMIT
		_connect_once(primary, func(): perform(game.transfer(selected.uid, false), "Moved to your backpack."))
	else:
		primary.visible = true
		primary.text = "Unequip" if game.equipped(selected.uid) else "Equip this item"
		_connect_once(primary, func(): perform(game.equip(selected.uid), "Equipment updated."))
		upgrade.visible = true
		upgrade.text = "Fully upgraded  +3" if selected.rank >= 3 else "Upgrade +%d   ·   %d gold" % [int(selected.rank) + 1, game.upgrade_price(selected)]
		upgrade.disabled = selected.rank >= 3 or not game.can_pay(game.upgrade_cost(selected), game.upgrade_price(selected))
		_connect_once(upgrade, func(): perform(game.upgrade(selected.uid), "Reforged. This item is stronger.", "forge"))
		storage.visible = true
		storage.disabled = game.equipped(selected.uid)
		_connect_once(storage, func(): perform(game.transfer(selected.uid, true), "Stored safely."))
		salvage.visible = true
		salvage.disabled = game.equipped(selected.uid)
		_connect_once(salvage, func(): confirm_salvage(selected))
		value_label.visible = true
		value_label.text = "Exchange guide price: %d gold" % game.item_value(selected)
		value_label.add_theme_color_override("font_color", UI2.GOLD)

func _build_forge_scene() -> void:
	var root := _instantiate_screen(FORGE_SCENE)
	var content: VBoxContainer = root.get_node("Main/Content")
	_style_heading(content.get_node("Title"))
	content.get_node("Intro").add_theme_color_override("font_color", UI2.MUTED)
	content.get_node("Odds").text = "65%% Common   ·   27%% Fine   ·   8%% Enchanted     /     Unlocked: Tier %d" % game.crafting_tier()
	content.get_node("Odds").add_theme_color_override("font_color", UI2.GOLD)
	var list: VBoxContainer = content.get_node("Scroll/List")
	for id in DB2.ITEMS:
		var recipe: Dictionary = DB2.ITEMS[id]
		if recipe.tier == 0: continue
		var recipe_id: String = id
		_add_recipe_row(list, recipe_id, recipe)
	var recipe: Dictionary = DB2.ITEMS[selected_recipe]
	var side: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	sidebar = side
	side.get_node("Eyebrow").text = "CRAFTING  /  TIER %d" % recipe.tier
	side.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	side.get_node("Title").text = str(recipe.name)
	_style_heading(side.get_node("Title"))
	side.get_node("Icon").texture = UI2.atlas(recipe.icon)
	side.get_node("Stats").text = DB2.stats_text(recipe.stats)
	side.get_node("Stats").add_theme_color_override("font_color", UI2.GREEN)
	side.get_node("Description").add_theme_color_override("font_color", UI2.MUTED)
	var costs: VBoxContainer = side.get_node("Costs")
	for id in recipe.cost:
		var owned := int(game.data.materials[id])
		var needed := int(recipe.cost[id])
		_add_text(costs, "%s   %d / %d" % [DB2.MATERIALS[id].name, owned, needed], 14, UI2.GREEN if owned >= needed else UI2.RED)
	_add_text(costs, "Gold   %d / %d" % [int(game.data.gold), int(recipe.gold)], 14, UI2.GOLD if game.data.gold >= recipe.gold else UI2.RED)
	var craft: Button = side.get_node("Craft")
	craft.disabled = not game.can_craft(selected_recipe)
	_connect_once(craft, craft_selected)
	var warning: Label = side.get_node("Warning")
	warning.visible = false
	if recipe.tier > game.crafting_tier():
		warning.visible = true
		warning.text = "Clear the %s to unlock this recipe." % ("Mosslight Verge" if recipe.tier == 2 else "Briarstone Quarry")
		warning.add_theme_color_override("font_color", UI2.RED)
	elif game.data.bag.size() >= State.BAG_LIMIT:
		warning.visible = true
		warning.text = "Your backpack is full. Store or salvage something first."
		warning.add_theme_color_override("font_color", UI2.RED)
	_connect_once(side.get_node("Brew"), func(): perform(game.brew_potion(), "A healing draught is ready.", "heal"))
	side.get_node("DraughtTip").add_theme_color_override("font_color", UI2.MUTED)

func _add_recipe_row(parent: Node, recipe_id: String, recipe: Dictionary) -> void:
	var row: PanelContainer = LIST_ROW_SCENE.instantiate()
	parent.add_child(row)
	row.get_node("Row/Icon").texture = UI2.atlas(recipe.icon)
	var title: Label = row.get_node("Row/Info/Title")
	title.text = str(recipe.name)
	_style_heading(title)
	row.get_node("Row/Info/Subtitle").text = "Tier %d · %s" % [recipe.tier, DB2.stats_text(recipe.stats)]
	row.get_node("Row/Info/Subtitle").add_theme_color_override("font_color", UI2.GREEN)
	var meta: Label = row.get_node("Row/Info/Meta")
	meta.visible = true
	meta.text = cost_text(recipe.cost) + "  ·  %d gold" % recipe.gold
	meta.add_theme_color_override("font_color", UI2.MUTED)
	var button: Button = row.get_node("Row/Action")
	button.text = "View recipe" if recipe.tier <= game.crafting_tier() else "Locked"
	_connect_once(button, func(): selected_recipe = recipe_id; refresh())

func _build_market_scene() -> void:
	var root := _instantiate_screen(MARKET_SCENE)
	var content: VBoxContainer = root.get_node("Main/Content")
	_style_heading(content.get_node("Title"))
	var online := is_instance_valid(exchange) and exchange.configured() and exchange.online_ready
	content.get_node("Intro").text = "ONLINE MARKET · Listings are shared between Harkwood players through Supabase." if online else "LOCAL SIMULATION · These are NPC offers and simulated buyers, not other players."
	content.get_node("Intro").add_theme_color_override("font_color", UI2.GOLD)
	var tab_names := ["buy", "sell", "listings", "materials"]
	for tab in tab_names:
		var button_name := "Listings" if tab == "listings" else tab.capitalize()
		var button: Button = content.get_node("Tabs/" + button_name)
		button.visible = not online or tab != "materials"
		var value: String = tab
		_connect_once(button, func():
			if online: online_market_tab = value
			else: market_tab = value
			refresh())
		button.remove_theme_color_override("font_color")
		if (online and online_market_tab == tab) or (not online and market_tab == tab): button.add_theme_color_override("font_color", UI2.GOLD)
	var list: VBoxContainer = content.get_node("Scroll/List")
	if online:
		_populate_online_market(list)
	else:
		_populate_local_market(list)
	var side: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	sidebar = side
	_style_heading(side.get_node("Title"))
	side.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	side.get_node("Description").add_theme_color_override("font_color", UI2.MUTED)
	side.get_node("GoldIcon").texture = UI2.atlas(13)
	side.get_node("Gold").text = "%d gold available" % int(game.data.gold)
	side.get_node("Gold").add_theme_color_override("font_color", UI2.GOLD)
	side.get_node("Stats").text = "%d / 8 listings · %d sales" % [game.data.listings.size(), int(game.data.sales)] if not online else "%d active listings" % exchange.mine.size()
	side.get_node("Stats").add_theme_color_override("font_color", UI2.GREEN)
	_connect_once(side.get_node("Potion"), func(): perform(game.buy_potion(), "Draught purchased.", "heal"))
	side.get_node("OnlineStatus").text = exchange.status if online else (exchange.status if is_instance_valid(exchange) and exchange.configured() else "Local simulation active. Add online_config.json to enable the shared player market.")
	side.get_node("OnlineStatus").add_theme_color_override("font_color", UI2.GREEN if online else UI2.MUTED)

func _populate_local_market(list: VBoxContainer) -> void:
	match market_tab:
		"buy":
			for offer in game.data.offers:
				var uid: String = offer.item.uid
				_add_gear_row(list, offer.item, "Buy · %dg" % offer.price, func(): perform(game.buy_offer(uid), "Purchased and placed in your pack."))
			if game.data.offers.is_empty(): _add_text(list, "The stalls are empty. Stock refreshes when you complete an expedition.", 17)
		"sell":
			var count := 0
			for item in game.data.bag:
				if not game.equipped(item.uid):
					count += 1
					var candidate: Dictionary = item
					_add_gear_row(list, candidate, "List item", func(): show_listing(candidate))
			if count == 0: _add_text(list, "No unequipped gear to list.", 17)
		"listings":
			for listing in game.data.listings:
				var uid: String = listing.item.uid
				_add_gear_row(list, listing.item, "Cancel · %dg" % listing.price, func(): perform(game.cancel_listing(uid), "Listing withdrawn. Your item was returned."))
			if game.data.listings.is_empty(): _add_text(list, "You have no active listings.", 17)
		"materials":
			for id in DB2.MATERIALS:
				_add_material_row(list, id)

func _populate_online_market(list: VBoxContainer) -> void:
	match online_market_tab:
		"buy":
			var visible := 0
			for listing in exchange.offers:
				if str(listing.get("seller_id", "")) == exchange.user_id: continue
				var item = listing.get("item", {})
				if not _valid_online_item(item): continue
				visible += 1
				var listing_id := str(listing.get("id", ""))
				var price := int(listing.get("price", 0))
				_add_gear_row(list, item, "Buy · %dg" % price, func(): _online_buy(listing_id))
			if visible == 0: _add_text(list, "No player listings are available right now.", 17)
		"sell":
			var count := 0
			for item in game.data.bag:
				if not game.equipped(item.uid):
					count += 1
					var candidate: Dictionary = item
					_add_gear_row(list, candidate, "List online", func(): _show_online_listing(candidate))
			if count == 0: _add_text(list, "No unequipped gear is available to list.", 17)
		"listings":
			for listing in exchange.mine:
				var item = listing.get("item", {})
				if not _valid_online_item(item): continue
				var listing_id := str(listing.get("id", ""))
				var price := int(listing.get("price", 0))
				_add_gear_row(list, item, "Cancel · %dg" % price, func(): _online_cancel(listing_id))
			if exchange.mine.is_empty(): _add_text(list, "You have no active player listings.", 17)

func _add_material_row(parent: Node, id: String) -> void:
	var mat: Dictionary = DB2.MATERIALS[id]
	var row: PanelContainer = LIST_ROW_SCENE.instantiate()
	parent.add_child(row)
	row.get_node("Row/Icon").texture = UI2.atlas(mat.icon)
	var title: Label = row.get_node("Row/Info/Title")
	title.text = str(mat.name)
	_style_heading(title)
	row.get_node("Row/Info/Subtitle").text = "Owned: %d · %d gold each" % [int(game.data.materials[id]), mat.value]
	row.get_node("Row/Info/Subtitle").add_theme_color_override("font_color", UI2.MUTED)
	var button: Button = row.get_node("Row/Action")
	button.text = "Sell 1"
	button.disabled = game.data.materials[id] < 1
	_connect_once(button, func(): perform(game.sell_material(id, 1), "Material sold."))

func _build_journal_scene() -> void:
	var root := _instantiate_screen(JOURNAL_SCENE)
	var content: VBoxContainer = root.get_node("Main/Content")
	_style_heading(content.get_node("Title"))
	content.get_node("Intro").add_theme_color_override("font_color", UI2.MUTED)
	var list: VBoxContainer = content.get_node("Scroll/List")
	for quest in DB2.QUESTS:
		_add_quest_row(list, quest)
	var side: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	sidebar = side
	side.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	_style_heading(side.get_node("Title"))
	side.get_node("Image").texture = UI2.atlas(7, true)
	side.get_node("Lore").add_theme_color_override("font_color", UI2.MUTED)
	side.get_node("Kills").text = "%d creatures defeated" % int(game.data.kills)
	side.get_node("Crafted").text = "%d items crafted" % int(game.data.crafted)
	side.get_node("Rewards").text = "%d / %d journal rewards collected" % [game.data.quests.size(), DB2.QUESTS.size()]
	for node_name in ["Kills", "Crafted", "Rewards"]: side.get_node(node_name).add_theme_color_override("font_color", UI2.GREEN)
	side.get_node("Tip").add_theme_color_override("font_color", UI2.MUTED)

func _add_quest_row(parent: Node, quest: Dictionary) -> void:
	var row: PanelContainer = LIST_ROW_SCENE.instantiate()
	parent.add_child(row)
	row.get_node("Row/Icon").texture = UI2.atlas(15)
	var claimed: bool = str(quest.id) in game.data.quests
	var progress := mini(game.quest_progress(quest), int(quest.target))
	var title: Label = row.get_node("Row/Info/Title")
	title.text = str(quest.name)
	_style_heading(title)
	if claimed: title.add_theme_color_override("font_color", UI2.MUTED)
	row.get_node("Row/Info/Subtitle").text = str(quest.text)
	row.get_node("Row/Info/Subtitle").add_theme_color_override("font_color", UI2.MUTED)
	var meta: Label = row.get_node("Row/Info/Meta")
	meta.visible = true
	meta.text = "Reward: %d gold · %s" % [quest.gold, cost_text(quest.materials)]
	meta.add_theme_color_override("font_color", UI2.GOLD)
	var button: Button = row.get_node("Row/Action")
	button.text = "Collected" if claimed else ("Collect reward" if progress >= quest.target else "%d / %d" % [progress, quest.target])
	button.disabled = claimed or progress < quest.target
	var id: String = str(quest.id)
	_connect_once(button, func(): claim(id))

func _build_battle_scene() -> void:
	var root := _instantiate_screen(BATTLE_SCENE)
	world = root.get_node("World")
	world.mode = "battle"
	world.background_path = "res://assets/art/quarry.png" if selected_zone == "quarry" else ("res://assets/art/hollow.png" if selected_zone == "hollow" else "res://assets/art/forest.png")
	world.enemy_art(battle.enemy.art)
	var zone: Dictionary = DB2.zone(selected_zone)
	root.get_node("World/SceneTitle/Title").text = str(zone.name)
	root.get_node("World/SceneTitle/Subtitle").text = "ENCOUNTER %d / %d   ·   %s STANCE" % [wave + 1, zone.waves.size(), stance.to_upper()]
	_style_scene_title(root)
	root.get_node("World/EnemyName").text = str(battle.enemy.name)
	_style_heading(root.get_node("World/EnemyName"))
	_style_heading(root.get_node("World/HeroName"))
	player_bar = root.get_node("World/PlayerHP")
	enemy_bar = root.get_node("World/EnemyHP")
	player_bar.max_value = battle.player.health
	enemy_bar.max_value = battle.enemy.health
	hp_label = root.get_node("World/PlayerHPText")
	enemy_hp_label = root.get_node("World/EnemyHPText")
	state_label = root.get_node("World/Status/Column/State")
	state_label.add_theme_color_override("font_color", UI2.GOLD)
	root.get_node("World/Status/Column/Loot").text = "Loot banked: %d gold · %d XP · %d equipment drops" % [run_gold, run_xp, run_items.size()]
	var side: VBoxContainer = root.get_node("Sidebar/Scroll/Content")
	sidebar = side
	side.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	_style_heading(side.get_node("Title"))
	side.get_node("Intro").add_theme_color_override("font_color", UI2.MUTED)
	side.get_node("AttackLabel").add_theme_color_override("font_color", UI2.GOLD)
	attack_bar = side.get_node("Attack")
	potion_button = side.get_node("Potion")
	_connect_once(potion_button, use_potion)
	_connect_once(side.get_node("Controls/Pause"), toggle_pause)
	_connect_once(side.get_node("Controls/Speed"), func(): battle_speed = 2.0 if battle_speed == 1.0 else 1.0; refresh())
	_connect_once(side.get_node("Controls/Retreat"), confirm_retreat)
	side.get_node("Controls/Pause").text = "Resume" if paused else "Pause"
	side.get_node("Controls/Speed").text = "Speed %dx" % int(battle_speed)
	battle_log_label = side.get_node("Log")
	battle_log_label.text = "\n".join(combat_log)
	battle_log_label.add_theme_color_override("font_color", UI2.MUTED)
	side.get_node("LogLabel").add_theme_color_override("font_color", UI2.GOLD)
	side.get_node("Tip").add_theme_color_override("font_color", UI2.MUTED)
	update_combat_bars()
	if phase == "results": _show_results_scene()

func _show_results_scene() -> void:
	var results: Control = RESULTS_SCENE.instantiate()
	world.add_child(results)
	var col: VBoxContainer = results.get_node("Panel/Column")
	col.get_node("Eyebrow").text = "EXPEDITION COMPLETE" if outcome == "victory" else "BACK FROM THE BRINK"
	col.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	var titles := {"victory": "A little further into the dark.", "defeat": "The hearth still burns for you.", "retreat": "Live to walk another trail."}
	if selected_zone == "hollow" and outcome == "victory": titles.victory = "The Hollow Hart has fallen."
	col.get_node("Title").text = titles[outcome]
	_style_heading(col.get_node("Title"))
	col.get_node("Description").text = "Your earned loot is safe. Return to the hearth to craft, equip and claim journal rewards." if outcome != "defeat" else "You lost 10% of your gold, capped at 20. Your equipment and gathered materials are safe."
	col.get_node("Description").add_theme_color_override("font_color", UI2.MUTED)
	col.get_node("GoldXP").text = "%d GOLD     %d EXPERIENCE" % [run_gold, run_xp]
	col.get_node("GoldXP").add_theme_color_override("font_color", UI2.GOLD)
	col.get_node("Materials").text = cost_text(run_loot) if not run_loot.is_empty() else "No materials gathered this time."
	col.get_node("Materials").add_theme_color_override("font_color", UI2.GREEN)
	var equipment: Label = col.get_node("Equipment")
	equipment.visible = not run_items.is_empty()
	if equipment.visible:
		equipment.text = "Equipment found: " + ", ".join(run_items)
		equipment.add_theme_color_override("font_color", UI2.QUALITY[2])
	col.get_node("Tip").visible = outcome == "victory"
	_connect_once(col.get_node("Buttons/Hearth"), func(): request_screen("hub"))
	_connect_once(col.get_node("Buttons/Journal"), func(): request_screen("journal"))
	_connect_once(col.get_node("Buttons/Travel"), func(): request_screen("map"))
	set_buttons_disabled(sidebar, true)

func _add_gear_row(parent: Node, item: Dictionary, action: String, callback: Callable, selected: bool = false) -> void:
	var row: PanelContainer = LIST_ROW_SCENE.instantiate()
	parent.add_child(row)
	if selected:
		row.add_theme_stylebox_override("panel", UI2.box(Color("2a382c"), UI2.GOLD))
	row.get_node("Row/Icon").texture = UI2.atlas(DB2.ITEMS[item.id].icon)
	var title: Label = row.get_node("Row/Info/Title")
	title.text = game.gear_name(item)
	title.add_theme_color_override("font_color", UI2.QUALITY[int(item.quality)])
	row.get_node("Row/Info/Subtitle").text = DB2.stats_text(game.gear_stats(item))
	row.get_node("Row/Info/Subtitle").add_theme_color_override("font_color", UI2.MUTED)
	var button: Button = row.get_node("Row/Action")
	button.text = action
	_connect_once(button, callback)

func _add_text(parent: Node, text: String, size: int = 14, color: Color = UI2.MUTED) -> Label:
	var label: Label = TEXT_LINE_SCENE.instantiate()
	parent.add_child(label)
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_button(parent: Node, text: String, callback: Callable, height: float = 42.0) -> Button:
	var button: Button = ACTION_BUTTON_SCENE.instantiate()
	parent.add_child(button)
	button.text = text
	button.custom_minimum_size.y = height
	_connect_once(button, callback)
	return button

func _add_icon(parent: Node, texture: Texture2D, height: float = 96.0) -> TextureRect:
	var icon: TextureRect = ICON_BLOCK_SCENE.instantiate()
	parent.add_child(icon)
	icon.texture = texture
	icon.custom_minimum_size.y = height
	return icon

func open_modal(title: String, eyebrow: String = "HARKWOOD") -> VBoxContainer:
	close_modal()
	modal = MODAL_SCENE.instantiate()
	hud.get_node("ModalLayer").add_child(modal)
	var col: VBoxContainer = modal.get_node("Center/Panel/Column")
	col.get_node("Eyebrow").text = eyebrow
	col.get_node("Eyebrow").add_theme_color_override("font_color", UI2.GOLD)
	col.get_node("Title").text = title
	_style_heading(col.get_node("Title"))
	_connect_once(col.get_node("Close"), close_modal)
	if is_instance_valid(world): world.active = false
	return col.get_node("Body")

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	if is_instance_valid(world): world.active = true

func toast(message: String) -> void:
	if not is_instance_valid(toast_label):
		toast_label = hud.get_node("Toast")
	toast_label.text = message
	toast_label.visible = true
	toast_label.add_theme_color_override("font_color", UI2.GOLD)
	toast_label.add_theme_color_override("font_outline_color", UI2.INK)
	toast_time = 6.0

func show_welcome() -> void:
	var body := open_modal("A lantern against the dark.", "WELCOME TO HARKWOOD")
	_add_text(body, "A hand-drawn RPG about what you bring back, and what you make of it.", 19, UI2.PAPER)
	_add_text(body, "1. Craft a Hearthforged blade with your starting materials.\n\n2. Equip it, then choose a trail on the Wilds map.\n\n3. Watch automatic battles, heal with Q, and bring back loot.\n\n4. Claim journal rewards, improve your gear, and face the Hollow Hart.", 16)
	_add_text(body, "Trading is a local NPC simulation in this prototype. Your progress saves automatically.", 13, UI2.GOLD)
	_add_button(body, "Enter Harkwood", func(): game.data.tutorial_seen = true; _save(); close_modal(), 46)

func show_settings() -> void:
	if traveling: return
	var body := open_modal("By the fireside", "SETTINGS & HELP")
	_add_button(body, "Enable sound" if sound.muted else "Mute sound", func(): sound.muted = not sound.muted; game.data.muted = sound.muted; _save(); show_settings())
	_add_text(body, "DISPLAY", 11, UI2.GOLD)
	var display_row := HBoxContainer.new()
	body.add_child(display_row)
	for preset in [[1280, 720], [1600, 900], [1920, 1080]]:
		var size := Vector2i(int(preset[0]), int(preset[1]))
		_add_button(display_row, "%d×%d" % [size.x, size.y], func(): _set_window_size(size), 36)
	_add_button(body, "Toggle fullscreen (F11)", _toggle_fullscreen, 36)
	_add_text(body, "Harkwood scales a centered 1440×900 design surface to fit the window.", 12)
	_add_button(body, "Save progress now", func(): if _save(): toast("Progress saved."))
	_add_text(body, "WASD / arrows or click: walk in the hub\nE: interact with a nearby station\nI: pack · M: wilds · C: forge · J: journal · H: hearth\nQ: heal in combat · Space: pause · F11: fullscreen", 14)
	if saving_disabled: _add_text(body, "The existing save was unreadable. Saving is disabled until you choose New journey.", 13, UI2.RED)
	_add_button(body, "New journey…", confirm_new_game, 36)

func confirm_new_game() -> void:
	var body := open_modal("Leave this journey behind?", "START OVER")
	_add_text(body, "This replaces your active character and progression. The current save and backup will be archived first.", 17)
	_add_button(body, "Archive this save and start anew", func(): _perform_new_game())

func _perform_new_game() -> void:
	if not test_mode:
		var stamp := str(Time.get_unix_time_from_system()).replace(".", "-")
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

func confirm_salvage(item: Dictionary) -> void:
	var body := open_modal("Return it to the forge?", "SALVAGE EQUIPMENT")
	_add_text(body, "Salvaging permanently consumes " + game.gear_name(item) + ". You receive %d iron and %d hide." % [maxi(1, DB2.ITEMS[item.id].tier), maxi(1, DB2.ITEMS[item.id].tier)], 16)
	_add_button(body, "Salvage this item", func(): close_modal(); perform(game.salvage(item.uid), "Reclaimed iron and hide.", "forge"))

func confirm_retreat() -> void:
	if phase == "results": return
	var body := open_modal("Head for the lanterns?", "RETREAT")
	_add_text(body, "Keep everything earned from defeated enemies. You will not receive the region's completion bonus or unlock its next trail.", 17)
	_add_button(body, "Retreat with my loot", func(): close_modal(); end_expedition("retreat"))

func show_listing(item: Dictionary) -> void:
	var body := open_modal("Offer your handiwork", "LOCAL EXCHANGE")
	_add_text(body, game.gear_name(item), 20, UI2.QUALITY[int(item.quality)])
	_add_text(body, "Guide price: %d gold. Maximum: %d gold. The item is held until sold or withdrawn." % [game.item_value(item), game.item_value(item) * 3], 15)
	var price: SpinBox = NUMBER_INPUT_SCENE.instantiate()
	body.add_child(price)
	price.min_value = 1
	price.max_value = game.item_value(item) * 3
	price.value = game.item_value(item)
	price.suffix = " gold"
	_add_button(body, "Create listing", func(): var success = game.list_item(item.uid, int(price.value)); close_modal(); perform(success, "Your item is listed. Buyers visit after completed expeditions."))

func _show_online_listing(item: Dictionary) -> void:
	if not exchange.online_ready or game.equipped(str(item.get("uid", ""))): return
	var body := open_modal("Offer your handiwork", "ONLINE EXCHANGE")
	_add_text(body, game.gear_name(item), 20, UI2.QUALITY[int(item.quality)])
	var guide := game.item_value(item)
	_add_text(body, "Guide price: %d gold. The online prototype allows up to 3× guide price." % guide, 15)
	var price: SpinBox = NUMBER_INPUT_SCENE.instantiate()
	body.add_child(price)
	price.min_value = 1
	price.max_value = guide * 3
	price.value = guide
	price.suffix = " gold"
	var uid := str(item.uid)
	_add_button(body, "Create online listing", func(): close_modal(); _online_list(uid, int(price.value), guide))

func craft_selected() -> void:
	var item = game.craft(selected_recipe)
	if item.is_empty():
		toast("Not enough materials, or the backpack is full.")
		return
	selected_gear = item.uid
	_save()
	sound.play("forge")
	refresh()
	var body := open_modal("Fresh from the forge", DB2.RARITIES[int(item.quality)].to_upper() + " CRAFT")
	_add_icon(body, UI2.atlas(DB2.ITEMS[item.id].icon), 135)
	_add_text(body, game.gear_name(item), 24, UI2.QUALITY[int(item.quality)])
	_add_text(body, DB2.stats_text(game.gear_stats(item)), 17, UI2.GREEN)
	var row := HBoxContainer.new()
	body.add_child(row)
	_add_button(row, "Equip now", func(): game.equip(item.uid); _save(); close_modal(); refresh())
	_add_button(row, "Keep in backpack", close_modal)
