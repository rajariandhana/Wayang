extends Node

# --- Your Supabase project ---
const SUPABASE_URL := "https://xmvqtdssobedgpssouls.supabase.co"
const SUPABASE_ANON_KEY := "sb_publishable_d-v4CXWbVVB8hXkVdG8YrA_tzw5HZYZ"

signal score_submitted(success: bool)
signal leaderboard_fetched(entries: Array) # [{name: String, wins: int}, ...] sorted desc

## Matches the LineEdit's max_length on the win screen's name entry.
const NAME_MAX_LENGTH := 12

var _cached_entries: Array = []

func _ready() -> void:
	# The win screen submits and fetches while the results menu has the tree
	# paused. HTTPRequest drives its transfer from internal processing, which
	# pause halts, so without this a request fired from there never completes -
	# the board sits on "Loading..." and submitted scores are never sent.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _new_request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(req)
	return req

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % SUPABASE_ANON_KEY,
		"Authorization: Bearer %s" % SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	])

func submit_win(player_name: String) -> void:
	var req := _new_request()
	req.request_completed.connect(func(_r, code, _h, resp_body: PackedByteArray):
		push_error("SUBMIT response: " + str(code) + " " + resp_body.get_string_from_utf8())
		score_submitted.emit(code == 200 or code == 201)
		req.queue_free()
	)
	var url := "%s/rest/v1/leaderboard" % SUPABASE_URL
	var body := JSON.stringify({"name": resolve_name(player_name), "score": 1})
	print("SUBMIT url: ", url)
	req.request(url, _headers(), HTTPClient.METHOD_POST, body)

func fetch_leaderboard(limit: int = 10) -> void:
	var req := _new_request()
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

## Trims the player's entry to a sane length, and gives anyone who submitted
## a blank name their own "Anonymous_1234" row rather than collapsing every
## skipped prompt onto a single shared "Anonymous" entry.
func resolve_name(player_name: String) -> String:
	var name := player_name.strip_edges().left(NAME_MAX_LENGTH)
	if name.is_empty():
		name = "Anonymous_%04d" % randi_range(0, 9999)
	return name

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
