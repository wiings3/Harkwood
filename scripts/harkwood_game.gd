extends "res://scripts/main.gd"
## V0.2 integration layer: responsive display controls, richer loot, and optional live exchange.
const EnhancedState = preload("res://scripts/core/game_state_v2.gd")
const ExchangeClient = preload("res://scripts/online/marketplace_client.gd")
const UI2 = preload("res://scripts/ui/palette.gd")
const DB2 = preload("res://scripts/core/catalog.gd")
var exchange: HarkMarketplaceClient
var online_market_tab := "buy"

func _ready() -> void:
	game = EnhancedState.new()
	exchange = ExchangeClient.new()
	add_child(exchange)
	exchange.changed.connect(_on_exchange_changed)
	exchange.wallet_changed.connect(_on_online_wallet_changed)
	super._ready()
	if exchange.configured():
		exchange.call_deferred("start", int(game.data.gold), int(game.data.get("online_gold_anchor", -1)))

func request_screen(destination: String) -> void:
	var requested := destination
	super.request_screen(destination)
	if requested == "market" and is_instance_valid(exchange) and exchange.configured():
		exchange.call_deferred("start", int(game.data.gold), int(game.data.get("online_gold_anchor", -1)))

func build_footer() -> void:
	super.build_footer()
	if is_instance_valid(footer) and footer.get_child_count() > 0:
		var last = footer.get_child(footer.get_child_count() - 1)
		if last is Label:
			last.text = "PROTOTYPE  /  0.2"

func build_market() -> void:
	if not is_instance_valid(exchange) or not exchange.configured():
		super.build_market()
		if is_instance_valid(sidebar):
			sidebar.add_child(UI2.paragraph("Online Exchange support is installed. It activates automatically when online_config.json is added.", 12, UI2.GOLD))
		return
	_build_online_market()

func _build_online_market() -> void:
	var panel = UI2.panel(page, Rect2(0, 0, 980, 680))
	var col = UI2.column(panel)
	col.add_child(UI2.label("The Lantern Exchange", 29, UI2.PAPER, true))
	col.add_child(UI2.paragraph("ONLINE MARKET · Listings are shared between Harkwood players through Supabase.", 13, UI2.GOLD))
	if not exchange.online_ready:
		col.add_child(UI2.paragraph(exchange.status, 18, UI2.MUTED))
		col.add_child(UI2.paragraph("The rest of Harkwood remains playable while the exchange connects.", 14))
		new_sidebar("THE TRADING POST", "Lighting the market…", "Anonymous authentication keeps the prototype frictionless. A later account system can link the same online identity.")
		sidebar.add_child(UI2.button("Try connection again", func(): exchange.start(int(game.data.gold), int(game.data.get("online_gold_anchor", -1))), 42))
		return
	var tabs = UI2.row(col)
	for tab in ["buy", "sell", "listings"]:
		var value: String = tab
		var caption: String = "My listings" if value == "listings" else value.capitalize()
		var button = UI2.button(caption, func(): online_market_tab = value; refresh(), 36)
		if online_market_tab == tab:
			button.add_theme_color_override("font_color", UI2.GOLD)
		tabs.add_child(button)
	var list = UI2.scroll_column(col)
	match online_market_tab:
		"buy":
			var visible := 0
			for listing in exchange.offers:
				if str(listing.get("seller_id", "")) == exchange.user_id:
					continue
				var item = listing.get("item", {})
				if not _valid_online_item(item):
					continue
				visible += 1
				var listing_id := str(listing.get("id", ""))
				var price := int(listing.get("price", 0))
				gear_row(list, item, "Buy · %dg" % price, func(): _online_buy(listing_id))
			if visible == 0:
				list.add_child(UI2.paragraph("No player listings are available right now.", 17))
		"sell":
			var count := 0
			for item in game.data.bag:
				if not game.equipped(item.uid):
					count += 1
					var candidate: Dictionary = item
					gear_row(list, candidate, "List online", func(): _show_online_listing(candidate))
			if count == 0:
				list.add_child(UI2.paragraph("No unequipped gear is available to list.", 17))
		"listings":
			for listing in exchange.mine:
				var item = listing.get("item", {})
				if not _valid_online_item(item):
					continue
				var listing_id := str(listing.get("id", ""))
				var price := int(listing.get("price", 0))
				gear_row(list, item, "Cancel · %dg" % price, func(): _online_cancel(listing_id))
			if exchange.mine.is_empty():
				list.add_child(UI2.paragraph("You have no active player listings.", 17))
	new_sidebar("LIVE PLAYER MARKET", "Good steel travels.", "Gear listed here can be bought by another Harkwood player. A 5% fee is removed from completed sales.")
	sidebar.add_child(UI2.icon(13, 85))
	sidebar.add_child(UI2.label("%d gold available" % int(game.data.gold), 22, UI2.GOLD, true))
	sidebar.add_child(UI2.paragraph(exchange.status, 12, UI2.GREEN))
	UI2.rule(sidebar)
	sidebar.add_child(UI2.label("%d active listings" % exchange.mine.size(), 13, UI2.GREEN))
	sidebar.add_child(UI2.button("Refresh player listings", func(): exchange.refresh_market(), 40))
	sidebar.add_child(UI2.paragraph("Prototype note: combat still runs locally, so the live economy is not cheat-resistant yet. The server does make purchases atomic to prevent two buyers taking the same listing.", 11, UI2.GOLD))

func _show_online_listing(item: Dictionary) -> void:
	if not exchange.online_ready or game.equipped(str(item.get("uid", ""))):
		return
	var body = open_modal("Offer your handiwork", "ONLINE EXCHANGE")
	body.add_child(UI2.paragraph(game.gear_name(item), 20, UI2.QUALITY[int(item.quality)]))
	var guide := game.item_value(item)
	body.add_child(UI2.paragraph("Guide price: %d gold. The online prototype allows up to 3× guide price." % guide, 15))
	var price = SpinBox.new()
	price.min_value = 1
	price.max_value = guide * 3
	price.step = 1
	price.value = guide
	price.suffix = " gold"
	body.add_child(price)
	var uid := str(item.uid)
	body.add_child(UI2.button("Create online listing", func():
		close_modal()
		_online_list(uid, int(price.value), guide)
	))

func _online_list(uid: String, price: int, guide: int) -> void:
	var item := game.find_gear(uid)
	if item.is_empty() or game.equipped(uid):
		toast("That item is no longer available to list.")
		return
	var result: Dictionary = await exchange.create_listing(item, price, guide)
	if not bool(result.get("ok", false)):
		toast("Listing failed: " + str(result.get("error", "Unknown error")))
		return
	var current := game.find_gear(uid)
	if not current.is_empty():
		game.data.bag.erase(current)
	_save()
	toast("Listed for %d gold on the player exchange." % price)
	refresh()

func _online_buy(listing_id: String) -> void:
	var result: Dictionary = await exchange.buy_listing(listing_id)
	if not bool(result.get("ok", false)):
		toast("Purchase failed: " + str(result.get("error", "Unknown error")))
		return
	var payload = result.get("data", {})
	if not payload is Dictionary or not _valid_online_item(payload.get("item", {})):
		toast("The server returned an invalid item. No local item was added.")
		return
	_restore_online_item(payload.item)
	_save()
	toast("Purchased from another player.")
	refresh()

func _online_cancel(listing_id: String) -> void:
	var result: Dictionary = await exchange.cancel_listing(listing_id)
	if not bool(result.get("ok", false)):
		toast("Could not cancel listing: " + str(result.get("error", "Unknown error")))
		return
	var payload = result.get("data", {})
	if payload is Dictionary and _valid_online_item(payload.get("item", {})):
		_restore_online_item(payload.item)
		_save()
	toast("Listing withdrawn and item returned.")
	refresh()

func _restore_online_item(raw_item: Dictionary) -> void:
	var item := raw_item.duplicate(true)
	item.erase("guide_price")
	var uid := str(item.get("uid", ""))
	if not _find_any_gear(uid).is_empty():
		item.uid = Crypto.new().generate_random_bytes(16).hex_encode()
	game.data["stash" if game.data.bag.size() >= 80 else "bag"].append(item)

func _find_any_gear(uid: String) -> Dictionary:
	for collection in ["bag", "stash"]:
		var found := game.find_gear(uid, collection)
		if not found.is_empty():
			return found
	return {}

func _valid_online_item(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if not DB2.ITEMS.has(str(value.get("id", ""))):
		return false
	if str(value.get("uid", "")).is_empty():
		return false
	var quality := int(value.get("quality", -1))
	var rank := int(value.get("rank", -1))
	if quality < 0 or quality >= DB2.RARITIES.size() or rank < 0 or rank > 3:
		return false
	if not value.get("affixes", []) is Array:
		return false
	for affix in value.get("affixes", []):
		if int(affix) < 0 or int(affix) >= DB2.AFFIXES.size():
			return false
	return true

func _on_online_wallet_changed(value: int) -> void:
	if value < 0:
		return
	game.data.gold = value
	game.data.online_gold_anchor = value
	_save()
	if screen == "market":
		refresh()

func _on_exchange_changed() -> void:
	if screen == "market" and not render_pending:
		refresh()

func show_settings() -> void:
	if traveling:
		return
	var body = open_modal("By the fireside", "SETTINGS & HELP")
	var audio_btn = UI2.button("Enable sound" if sound.muted else "Mute sound", func():
		sound.muted = not sound.muted
		game.data.muted = sound.muted
		_save()
		show_settings()
	)
	body.add_child(audio_btn)
	body.add_child(UI2.label("DISPLAY", 11, UI2.GOLD))
	var display_row = UI2.row(body)
	for preset in [[1280, 720], [1600, 900], [1920, 1080]]:
		var size := Vector2i(int(preset[0]), int(preset[1]))
		display_row.add_child(UI2.button("%d×%d" % [size.x, size.y], func(): _set_window_size(size), 36))
	body.add_child(UI2.button("Toggle fullscreen (F11)", _toggle_fullscreen, 36))
	body.add_child(UI2.paragraph("Harkwood now scales a centered 1440×900 design surface to fit the window. 16:9 displays use small side margins instead of leaving the game pinned in a corner.", 12))
	if is_instance_valid(exchange):
		body.add_child(UI2.label("EXCHANGE", 11, UI2.GOLD))
		body.add_child(UI2.paragraph(exchange.status if exchange.configured() else "Local simulation active. Add online_config.json to enable the shared player market.", 12, UI2.GREEN if exchange.online_ready else UI2.MUTED))
	body.add_child(UI2.button("Save progress now", func():
		if _save(): toast("Progress saved.")
	))
	body.add_child(UI2.paragraph("WASD / arrows or click: walk in the hub\nE: interact with a nearby station\nI: pack · M: wilds · C: forge · J: journal · H: hearth\nQ: heal in combat · Space: pause · F11: fullscreen", 14))
	body.add_child(UI2.paragraph("Saves: user://harkwood_save.json\nA previous valid save is kept as .bak. Closing during an expedition returns you to the hub with already banked loot.", 12))
	if saving_disabled:
		body.add_child(UI2.paragraph("The existing save was unreadable. Saving is disabled until you choose New journey. Your original files have not been changed.", 13, UI2.RED))
	body.add_child(UI2.button("New journey…", confirm_new_game, 36))

func _set_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_index := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen_index)
	var centered := usable.position + (usable.size - size) / 2
	DisplayServer.window_set_position(centered)
	toast("Display set to %d×%d." % [size.x, size.y])

func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
