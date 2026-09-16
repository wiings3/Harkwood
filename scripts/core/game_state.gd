class_name HarkState
extends RefCounted
## Offline authority. No client save will be importable into a future live economy.
const DB = preload("res://scripts/core/catalog.gd")
const BAG_LIMIT = 80
var data: Dictionary = {}
var rng = RandomNumberGenerator.new()
var save_path = "user://harkwood_save.json"
var load_message = ""

func _init() -> void:
	rng.randomize()
	new_game()

func new_game() -> void:
	data = {"version": 1, "gold": 65, "xp": 0, "potions": 3,
		"materials": {"wood": 8, "hide": 8, "iron": 4, "amber": 0, "core": 0},
		"bag": [], "stash": [], "equipped": {}, "clears": {},
		"crafted": 0, "kills": 0, "quests": [], "listings": [], "offers": [],
		"sales": 0, "muted": false, "tutorial_seen": false}
	for id in ["worn_blade", "traveler_coat"]:
		var item = make_gear(id, 0)
		data.bag.append(item)
		data.equipped[DB.ITEMS[id].slot] = item.uid
	refresh_offers()

func make_gear(id: String, quality: int = -1) -> Dictionary:
	if not DB.ITEMS.has(id):
		return {}
	if quality < 0:
		var roll = rng.randf()
		quality = 2 if roll < 0.08 else (1 if roll < 0.35 else 0)
	var affixes: Array = []
	if quality > 0:
		affixes.append(rng.randi_range(0, DB.AFFIXES.size() - 1))
	return {"uid": Crypto.new().generate_random_bytes(16).hex_encode(), "id": id,
		"quality": clampi(quality, 0, 2), "rank": 0, "affixes": affixes}

func level() -> int:
	var current = 1
	var remaining = int(data.xp)
	while remaining >= current * 60 and current < 30:
		remaining -= current * 60
		current += 1
	return current

func level_xp() -> int:
	var current = level()
	return int(data.xp) - (current - 1) * current * 30

func find_gear(uid: String, collection: String = "bag") -> Dictionary:
	for item in data[collection]:
		if item.uid == uid:
			return item
	return {}

func gear_stats(item: Dictionary) -> Dictionary:
	var result = DB.ITEMS[item.id].stats.duplicate(true)
	var multiplier = DB.QUALITY_MULT[int(item.quality)] * (1.0 + float(item.rank) * 0.12)
	for key in result:
		result[key] = float(result[key]) * multiplier
	for index in item.affixes:
		var affix = DB.AFFIXES[int(index)]
		result[affix.stat] = float(result.get(affix.stat, 0.0)) + affix.value
	return result

func gear_name(item: Dictionary) -> String:
	var title = DB.ITEMS[item.id].name
	if int(item.quality) > 0:
		title = DB.RARITIES[int(item.quality)] + " " + title
	if not item.affixes.is_empty():
		title += " " + DB.AFFIXES[int(item.affixes[0])].name
	if int(item.rank) > 0:
		title += " +%d" % int(item.rank)
	return title

func stats() -> Dictionary:
	var result = {"health": 80.0 + (level() - 1) * 8, "attack": 6.0 + (level() - 1) * 1.5,
		"armor": 0.0, "crit": 0.05, "haste": 0.0, "leech": 0.0}
	for uid in data.equipped.values():
		var item = find_gear(uid)
		if item.is_empty():
			continue
		var additions = gear_stats(item)
		for key in additions:
			result[key] = float(result.get(key, 0.0)) + additions[key]
	result.crit = minf(result.crit, 0.65)
	result.haste = minf(result.haste, 1.5)
	return result

func equipped(uid: String) -> bool:
	return uid in data.equipped.values()

func equip(uid: String) -> bool:
	var item = find_gear(uid)
	if item.is_empty():
		return false
	var slot = DB.ITEMS[item.id].slot
	if equipped(uid):
		data.equipped.erase(slot)
	else:
		data.equipped[slot] = uid
	return true

func unlocked(zone_id: String) -> bool:
	var zone = DB.zone(zone_id)
	return not zone.is_empty() and (zone.unlock == "" or int(data.clears.get(zone.unlock, 0)) > 0)

func crafting_tier() -> int:
	if data.clears.get("quarry", 0) > 0:
		return 3
	if data.clears.get("verge", 0) > 0:
		return 2
	return 1

func can_pay(cost: Dictionary, gold: int = 0) -> bool:
	if gold < 0 or int(data.gold) < gold:
		return false
	for key in cost:
		if int(cost[key]) < 0 or int(data.materials.get(key, 0)) < int(cost[key]):
			return false
	return true

func pay(cost: Dictionary, gold: int = 0) -> bool:
	if not can_pay(cost, gold):
		return false
	data.gold = int(data.gold) - gold
	for key in cost:
		data.materials[key] = int(data.materials[key]) - int(cost[key])
	return true

func can_craft(id: String) -> bool:
	if not DB.ITEMS.has(id) or data.bag.size() >= BAG_LIMIT:
		return false
	var recipe = DB.ITEMS[id]
	return recipe.tier > 0 and recipe.tier <= crafting_tier() and can_pay(recipe.cost, recipe.gold)

func craft(id: String) -> Dictionary:
	if not can_craft(id):
		return {}
	var recipe = DB.ITEMS[id]
	pay(recipe.cost, recipe.gold)
	var item = make_gear(id)
	data.bag.append(item)
	data.crafted = int(data.crafted) + 1
	return item

func item_value(item: Dictionary) -> int:
	var def = DB.ITEMS[item.id]
	return maxi(4, roundi((def.gold + 8 + def.tier * 8) * DB.QUALITY_MULT[int(item.quality)] * (1 + 0.2 * item.rank)))

func upgrade_cost(item: Dictionary) -> Dictionary:
	return {"iron": (int(item.rank) + 1) * 2, "wood": int(item.rank) + 2}

func upgrade_price(item: Dictionary) -> int:
	return (int(item.rank) + 1) * 15

func upgrade(uid: String) -> bool:
	var item = find_gear(uid)
	if item.is_empty() or int(item.rank) >= 3:
		return false
	if not pay(upgrade_cost(item), upgrade_price(item)):
		return false
	item.rank = int(item.rank) + 1
	return true

func salvage(uid: String) -> bool:
	var item = find_gear(uid)
	if item.is_empty() or equipped(uid):
		return false
	var tier = maxi(1, DB.ITEMS[item.id].tier)
	data.materials.iron = int(data.materials.iron) + tier
	data.materials.hide = int(data.materials.hide) + tier
	data.bag.erase(item)
	return true

func transfer(uid: String, to_stash: bool) -> bool:
	var source = "bag" if to_stash else "stash"
	var target = "stash" if to_stash else "bag"
	var item = find_gear(uid, source)
	if item.is_empty() or equipped(uid) or (not to_stash and data.bag.size() >= BAG_LIMIT):
		return false
	data[source].erase(item)
	data[target].append(item)
	return true

func sell_material(id: String, count: int) -> bool:
	if not DB.MATERIALS.has(id) or count <= 0 or int(data.materials[id]) < count:
		return false
	data.materials[id] = int(data.materials[id]) - count
	data.gold = int(data.gold) + DB.MATERIALS[id].value * count
	return true

func buy_potion() -> bool:
	if int(data.gold) < 12 or int(data.potions) >= 99:
		return false
	data.gold = int(data.gold) - 12
	data.potions = int(data.potions) + 1
	return true

func brew_potion() -> bool:
	if int(data.potions) >= 99 or not pay({"wood": 2, "amber": 1}, 3):
		return false
	data.potions = int(data.potions) + 1
	return true

func grant_materials(materials: Dictionary) -> void:
	for id in materials:
		data.materials[id] = int(data.materials.get(id, 0)) + int(materials[id])

func reward_enemy(id: String) -> Dictionary:
	var enemy = DB.ENEMIES[id]
	data.xp = int(data.xp) + enemy.xp
	data.gold = int(data.gold) + enemy.gold
	data.kills = int(data.kills) + 1
	grant_materials(enemy.loot)
	var result = {"gold": enemy.gold, "xp": enemy.xp, "materials": enemy.loot.duplicate(true), "gear": ""}
	if rng.randf() < 0.16 or id == "elder":
		var pool: Array = []
		for item_id in DB.ITEMS:
			if DB.ITEMS[item_id].tier == crafting_tier():
				pool.append(item_id)
		var item = make_gear(pool[rng.randi_range(0, pool.size() - 1)], 2 if id == "elder" else -1)
		data["stash" if data.bag.size() >= BAG_LIMIT else "bag"].append(item)
		result.gear = gear_name(item)
	return result

func complete_zone(id: String) -> int:
	var zone = DB.zone(id)
	data.clears[id] = int(data.clears.get(id, 0)) + 1
	data.gold = int(data.gold) + zone.reward
	resolve_local_sales()
	refresh_offers()
	return zone.reward

func quest_progress(quest: Dictionary) -> int:
	match quest.counter:
		"crafted": return int(data.crafted)
		"equipped": return data.equipped.size()
		_: return int(data.clears.get(quest.counter, 0))

func claim_quest(id: String) -> bool:
	if id in data.quests:
		return false
	for quest in DB.QUESTS:
		if quest.id == id and quest_progress(quest) >= quest.target:
			data.quests.append(id)
			data.gold = int(data.gold) + quest.gold
			grant_materials(quest.materials)
			return true
	return false

func refresh_offers() -> void:
	data.offers.clear()
	var tier = crafting_tier()
	for id in DB.ITEMS:
		if DB.ITEMS[id].tier == tier:
			var item = make_gear(id, 1)
			data.offers.append({"item": item, "price": item_value(item) * 2})

func buy_offer(uid: String) -> bool:
	if data.bag.size() >= BAG_LIMIT:
		return false
	for offer in data.offers:
		if offer.item.uid == uid and int(data.gold) >= int(offer.price):
			data.gold = int(data.gold) - int(offer.price)
			data.bag.append(offer.item)
			data.offers.erase(offer)
			return true
	return false

func list_item(uid: String, price: int) -> bool:
	var item = find_gear(uid)
	if item.is_empty() or equipped(uid) or data.listings.size() >= 8 or price < 1:
		return false
	if price > item_value(item) * 3:
		return false
	data.bag.erase(item)
	data.listings.append({"item": item, "price": price})
	return true

func cancel_listing(uid: String) -> bool:
	for listing in data.listings:
		if listing.item.uid == uid:
			data["stash" if data.bag.size() >= BAG_LIMIT else "bag"].append(listing.item)
			data.listings.erase(listing)
			return true
	return false

func resolve_local_sales() -> void:
	# A deliberately local stand-in. No real users, accounts, or network calls.
	for listing in data.listings.duplicate():
		var fair = item_value(listing.item)
		if listing.price <= fair or (listing.price <= fair * 1.5 and rng.randf() < 0.4):
			data.gold = int(data.gold) + int(listing.price) - ceili(listing.price * 0.05)
			data.listings.erase(listing)
			data.sales = int(data.sales) + 1

func save_game() -> bool:
	var temp_path = save_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(save_path) and valid_save(_read_save(save_path)):
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(temp_path, save_path) == OK

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4_000_000:
		return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

func load_game() -> bool:
	load_message = ""
	for path in [save_path, save_path + ".bak"]:
		var candidate = _read_save(path)
		if valid_save(candidate):
			data = candidate
			if path.ends_with(".bak"):
				load_message = "Recovered your previous save from backup."
			return true
	if FileAccess.file_exists(save_path):
		load_message = "Save could not be read. Your original files were left untouched."
	return false

func valid_save(candidate: Variant) -> bool:
	if not candidate is Dictionary or candidate.get("version", 0) != 1:
		return false
	for key in ["gold", "xp", "potions", "crafted", "kills", "sales"]:
		if not candidate.get(key) is float and not candidate.get(key) is int:
			return false
		if candidate[key] < 0 or candidate[key] > 100_000_000 or not is_finite(float(candidate[key])):
			return false
	for key in ["bag", "stash", "quests", "offers", "listings"]:
		if not candidate.get(key) is Array:
			return false
	for key in ["materials", "equipped", "clears"]:
		if not candidate.get(key) is Dictionary:
			return false
	for key in ["muted", "tutorial_seen"]:
		if not candidate.get(key) is bool:
			return false
	for id in DB.MATERIALS:
		var count = candidate.materials.get(id, -1)
		if not (count is float or count is int) or count < 0 or count > 100_000_000:
			return false
	for id in candidate.clears:
		var count = candidate.clears[id]
		if DB.zone(id).is_empty() or not (count is float or count is int) or count < 0:
			return false
	var owned: Dictionary = {}
	for item in candidate.bag + candidate.stash:
		if not _valid_item(item) or owned.has(item.uid):
			return false
		owned[item.uid] = true
	for offer in candidate.listings + candidate.offers:
		if not offer is Dictionary or not _valid_item(offer.get("item")):
			return false
		if not (offer.get("price") is float or offer.get("price") is int) or offer.price < 1 or offer.price > 1_000_000:
			return false
		if owned.has(offer.item.uid):
			return false
		owned[offer.item.uid] = true
	for slot in candidate.equipped:
		if not slot in DB.SLOTS or not candidate.equipped[slot] is String:
			return false
		var found = false
		for item in candidate.bag:
			if item.uid == candidate.equipped[slot] and DB.ITEMS[item.id].slot == slot:
				found = true
		if not found:
			return false
	return true

func _valid_item(item: Variant) -> bool:
	if not item is Dictionary or not item.get("uid") is String or item.uid.length() != 32:
		return false
	if not item.get("id") is String or not DB.ITEMS.has(item.id):
		return false
	for key in ["quality", "rank"]:
		if not (item.get(key) is float or item.get(key) is int):
			return false
		if item[key] != int(item[key]):
			return false
	if item.quality < 0 or item.quality > 2 or item.rank < 0 or item.rank > 3 or not item.get("affixes") is Array:
		return false
	for affix in item.affixes:
		if not (affix is float or affix is int) or affix < 0 or affix >= DB.AFFIXES.size() or affix != int(affix):
			return false
	return item.affixes.size() <= 1
