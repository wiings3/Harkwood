class_name HarkMarketplaceClient
extends Node
## Small Supabase REST/Auth client. It stays dormant until res://online_config.json exists.
signal changed
signal status_changed(text: String)
signal wallet_changed(value: int)

const CONFIG_PATH = "res://online_config.json"
const SESSION_PATH = "user://harkwood_online_session.json"
var base_url := ""
var api_key := ""
var access_token := ""
var refresh_token := ""
var user_id := ""
var online_ready := false
var busy := false
var status := "Offline"
var offers: Array = []
var mine: Array = []

func _init() -> void:
	_load_config()
	_load_session()

func configured() -> bool:
	return not base_url.is_empty() and not api_key.is_empty()

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		base_url = str(parsed.get("url", "")).trim_suffix("/")
		api_key = str(parsed.get("publishable_key", ""))

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		access_token = str(parsed.get("access_token", ""))
		refresh_token = str(parsed.get("refresh_token", ""))
		user_id = str(parsed.get("user_id", ""))

func _save_session() -> void:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"access_token": access_token, "refresh_token": refresh_token, "user_id": user_id}))

func start(local_gold: int, gold_anchor: int) -> void:
	if not configured() or busy:
		return
	busy = true
	_set_status("Connecting to the Lantern Exchange…")
	if not await _authenticate():
		busy = false
		_set_status("Online sign-in failed. Local exchange remains available after removing online_config.json.")
		return
	var ensured := await _rpc("hark_ensure_profile", {"p_initial_gold": maxi(0, local_gold)})
	if not ensured.ok:
		busy = false
		_set_status("Exchange profile could not be loaded.")
		return
	var payload = ensured.data
	var server_gold := local_gold
	var created := false
	if payload is Dictionary:
		server_gold = int(payload.get("gold", local_gold))
		created = bool(payload.get("created", false))
	if not created and gold_anchor >= 0:
		var delta := local_gold - gold_anchor
		if delta != 0:
			var synced := await _rpc("hark_apply_wallet_delta", {"p_delta": delta})
			if synced.ok and synced.data is Dictionary:
				server_gold = int(synced.data.get("gold", server_gold))
	online_ready = true
	busy = false
	wallet_changed.emit(server_gold)
	_set_status("Online · %s" % user_id.left(8))
	await refresh_market()

func _authenticate() -> bool:
	if not refresh_token.is_empty():
		var refreshed := await _http(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)
		if refreshed.ok and _adopt_auth(refreshed.data):
			return true
	access_token = ""
	refresh_token = ""
	user_id = ""
	var signup := await _http(HTTPClient.METHOD_POST, "/auth/v1/signup", {}, false)
	return signup.ok and _adopt_auth(signup.data)

func _adopt_auth(payload: Variant) -> bool:
	if not payload is Dictionary:
		return false
	var token := str(payload.get("access_token", ""))
	var refresh := str(payload.get("refresh_token", ""))
	var user = payload.get("user", {})
	if token.is_empty() or refresh.is_empty() or not user is Dictionary:
		return false
	var id := str(user.get("id", ""))
	if id.is_empty():
		return false
	access_token = token
	refresh_token = refresh
	user_id = id
	_save_session()
	return true

func refresh_market() -> void:
	if not online_ready or busy:
		return
	busy = true
	var market := await _http(HTTPClient.METHOD_GET, "/rest/v1/hark_market_listings?select=id,seller_id,item,price,created_at&status=eq.active&order=created_at.desc&limit=50", null, true)
	var own := await _http(HTTPClient.METHOD_GET, "/rest/v1/hark_market_listings?select=id,seller_id,item,price,created_at&seller_id=eq.%s&status=eq.active&order=created_at.desc" % user_id, null, true)
	var wallet := await _rpc("hark_wallet", {})
	if market.ok and market.data is Array:
		offers = market.data
	if own.ok and own.data is Array:
		mine = own.data
	if wallet.ok and wallet.data is Dictionary:
		wallet_changed.emit(int(wallet.data.get("gold", 0)))
	busy = false
	changed.emit()

func create_listing(item: Dictionary, price: int, guide_price: int) -> Dictionary:
	if not online_ready or busy:
		return {"ok": false, "error": "Exchange is busy."}
	busy = true
	var payload := item.duplicate(true)
	payload["guide_price"] = guide_price
	var result := await _rpc("hark_create_listing", {"p_item": payload, "p_price": price})
	busy = false
	if result.ok:
		await refresh_market()
	return result

func buy_listing(listing_id: String) -> Dictionary:
	if not online_ready or busy:
		return {"ok": false, "error": "Exchange is busy."}
	busy = true
	var result := await _rpc("hark_buy_listing", {"p_listing": listing_id})
	busy = false
	if result.ok and result.data is Dictionary:
		wallet_changed.emit(int(result.data.get("gold", 0)))
		await refresh_market()
	return result

func cancel_listing(listing_id: String) -> Dictionary:
	if not online_ready or busy:
		return {"ok": false, "error": "Exchange is busy."}
	busy = true
	var result := await _rpc("hark_cancel_listing", {"p_listing": listing_id})
	busy = false
	if result.ok:
		await refresh_market()
	return result

func _rpc(name: String, payload: Dictionary) -> Dictionary:
	return await _http(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + name, payload, true)

func _http(method: int, path: String, body: Variant, authenticated_request: bool) -> Dictionary:
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["apikey: " + api_key, "Content-Type: application/json", "Accept: application/json"])
	if authenticated_request and not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	var payload := "" if body == null else JSON.stringify(body)
	var error := request.request(base_url + path, headers, method, payload)
	if error != OK:
		request.queue_free()
		return {"ok": false, "code": 0, "error": "Request could not start (%d)." % error, "data": null}
	var response: Array = await request.request_completed
	request.queue_free()
	var code := int(response[1])
	var bytes: PackedByteArray = response[3]
	var text := bytes.get_string_from_utf8()
	var parsed: Variant = null
	if not text.is_empty():
		parsed = JSON.parse_string(text)
	var ok := code >= 200 and code < 300
	var message := ""
	if not ok:
		if parsed is Dictionary:
			message = str(parsed.get("message", parsed.get("error_description", parsed.get("error", "HTTP %d" % code))))
		else:
			message = "HTTP %d" % code
	return {"ok": ok, "code": code, "error": message, "data": parsed}

func _set_status(value: String) -> void:
	status = value
	status_changed.emit(value)
	changed.emit()
