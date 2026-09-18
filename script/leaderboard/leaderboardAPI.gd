extends Node

# --- Your Supabase project ---
const SUPABASE_URL := "https://xmvqtdssobedgpssouls.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_d-v4CXWbVVB8hXkVdG8YrA_tzw5HZYZ"

signal score_submitted(success: bool)
signal leaderboard_fetched(entries: Array) # [{name: String, wins: int}, ...] sorted desc

var _cached_entries: Array = []

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	])

func submit_win(player_name: String) -> void:
	var name := player_name.strip_edges()
	if name.is_empty():
		name = "Anonymous"
	name = name.left(12) # basic sanity cap

	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, resp_body: PackedByteArray):
		push_error("SUBMIT response: " + str(code) + " " + resp_body.get_string_from_utf8())
		score_submitted.emit(code == 200 or code == 201)
		req.queue_free()
	)
	var url := "%s/rest/v1/leaderboard" % SUPABASE_URL
	var body := JSON.stringify({"name": name, "score": 1})
	print("SUBMIT url: ", url)
	req.request(url, _headers(), HTTPClient.METHOD_POST, body)

func fetch_leaderboard(limit: int = 10) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		print("FETCH response: ", code, " ", body.get_string_from_utf8())
		if code == 200:
			var raw = JSON.parse_string(body.get_string_from_utf8())
			_cached_entries = _aggregate(raw)
			leaderboard_fetched.emit(_cached_entries.slice(0, limit))
		else:
			leaderboard_fetched.emit(_cached_entries.slice(0, limit))
		req.queue_free()
	)
	var url := "%s/rest/v1/leaderboard?select=name,score" % SUPABASE_URL
	req.request(url, _headers(), HTTPClient.METHOD_GET)

func _aggregate(rows) -> Array:
	if typeof(rows) != TYPE_ARRAY:
		return []
	var totals := {}
	for row in rows:
		var n = row.get("name", "Anonymous")
		totals[n] = totals.get(n, 0) + int(row.get("score", 0))
	var entries := []
	for n in totals.keys():
		entries.append({"name": n, "wins": totals[n]})
	entries.sort_custom(func(a, b): return a["wins"] > b["wins"])
	return entries
