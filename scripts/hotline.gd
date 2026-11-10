extends Node
## Voice bridge. Web: window.hotline via JavaScriptBridge (see CONTRACT.md).
## Desktop: a scripted MOCK conversation so the game is testable without a key.

signal status(npc: String, status: String, message: String)
signal speech(npc: String, who: String, text: String, final: bool)
signal speaking(npc: String, on: bool)
signal volume(level: float)
signal tool(npc: String, name: String, args: Dictionary)
signal lookup(npc: String, query: String, status: String, summary: String)

var is_web := OS.has_feature("web")
var active_npc := ""
var in_call := false
var _js: JavaScriptObject = null

# mock state
var _mock_queue: Array = []   # [time, event]
var _mock_t := 0.0
var _mock_speaking := false
var _mb_t := 0.0

const MOCK_ITEM := {"maple": "milk", "clucky": "egg", "juniper": "flower"}

func _js_obj() -> JavaScriptObject:
	if not is_web:
		return null
	if _js == null:
		var ok = JavaScriptBridge.eval("typeof window.hotline !== 'undefined'", true)
		if ok:
			_js = JavaScriptBridge.get_interface("hotline")
	return _js

func has_key() -> bool:
	var js := _js_obj()
	if js == null:
		return not is_web
	return bool(js.hasKey())

func prewarm(npc: String) -> void:
	var js := _js_obj()
	if js:
		js.prewarm(npc)

func start(npc: String, context_json: String) -> void:
	active_npc = npc
	in_call = true
	var js := _js_obj()
	if js:
		js.start(npc, context_json)
	elif not is_web:
		_mock_start(npc, context_json)
	else:
		_emit({"type": "status", "npc": npc, "status": "error", "message": "voice bridge not loaded"})

func stop() -> void:
	if not in_call:
		return
	var js := _js_obj()
	if js:
		js.stop()
	elif not is_web:
		_mock_queue.clear()
		_mock_speaking = false
		_emit({"type": "status", "npc": active_npc, "status": "ended", "message": ""})
	in_call = false

func inform(text: String) -> void:
	print("[hotline.inform] ", text)
	var js := _js_obj()
	if js:
		js.inform(text)

func _process(delta: float) -> void:
	var js := _js_obj()
	if js:
		var raw = js.drain()
		if raw is String and raw != "" and raw != "[]":
			var arr = JSON.parse_string(raw)
			if arr is Array:
				for ev in arr:
					if ev is Dictionary:
						_emit(ev)
	elif not is_web:
		_mock_tick(delta)

func _emit(ev: Dictionary) -> void:
	var npc: String = str(ev.get("npc", active_npc))
	match str(ev.get("type", "")):
		"status":
			var st := str(ev.get("status", ""))
			if st == "ended" or st == "error":
				in_call = false
			status.emit(npc, st, str(ev.get("message", "")))
		"speech":
			speech.emit(npc, str(ev.get("who", "npc")), str(ev.get("text", "")), bool(ev.get("final", false)))
		"speaking":
			speaking.emit(npc, bool(ev.get("on", false)))
		"volume":
			volume.emit(float(ev.get("level", 0.0)))
		"lookup":
			lookup.emit(npc, str(ev.get("query", "")), str(ev.get("status", "")), str(ev.get("summary", "")))
		"tool":
			var args = ev.get("args", {})
			tool.emit(npc, str(ev.get("name", "")), args if args is Dictionary else {})

# ---------------- MOCK ----------------
func _mock_start(npc: String, context_json: String) -> void:
	_mock_queue.clear()
	_mock_t = 0.0
	var ctx = JSON.parse_string(context_json)
	var item: String = MOCK_ITEM.get(npc, "egg")
	var have_quest := false
	var have := 0
	if ctx is Dictionary:
		for q in ctx.get("quests", []):
			if q["npc"] == npc and not q["done"]:
				have_quest = true
				item = q["item"]
		have = int(ctx.get("inventory", {}).get(item, 0))
	_mb_t = 0.0
	var push := func(dt: float, ev: Dictionary):
		_mb_t += dt
		ev["npc"] = npc
		_mock_queue.append([_mb_t, ev])
	push.call(0.0, {"type": "status", "status": "connecting"})
	push.call(0.9, {"type": "status", "status": "live"})
	var say := func(line: String):
		push.call(0.3, {"type": "speaking", "on": true})
		var words := line.split(" ")
		var acc := ""
		for i in words.size():
			acc += ("" if i == 0 else " ") + words[i]
			push.call(0.12, {"type": "speech", "who": "npc", "text": acc, "final": i == words.size() - 1})
		push.call(0.4, {"type": "speaking", "on": false})
	var player_says := func(line: String):
		var words := line.split(" ")
		var acc := ""
		push.call(0.6, {"type": "speech", "who": "player", "text": "", "final": false})
		for i in words.size():
			acc += ("" if i == 0 else " ") + words[i]
			push.call(0.15, {"type": "speech", "who": "player", "text": acc, "final": i == words.size() - 1})
	say.call("Oh! Hi there, friend! It's so good to see you today!")
	push.call(0.1, {"type": "tool", "name": "emote", "args": {"kind": "happy"}})
	push.call(0.2, {"type": "tool", "name": "animate", "args": {"kind": "jump"}})
	if have_quest:
		player_says.call("I brought your %s!" % item)
		push.call(0.3, {"type": "tool", "name": "complete_quest", "args": {"item": item}})
		say.call("Let me check your pockets... you're a star!")
		push.call(0.1, {"type": "tool", "name": "emote", "args": {"kind": "love"}})
		push.call(0.1, {"type": "tool", "name": "animate", "args": {"kind": "dance"}})
	else:
		player_says.call("Hey! What's the tallest tree in the world?")
		push.call(0.3, {"type": "lookup", "query": "tallest tree in the world", "status": "start"})
		push.call(1.8, {"type": "lookup", "query": "tallest tree in the world", "status": "done", "summary": "Hyperion, a coast redwood in California, is about 116 m tall: the tallest known living tree."})
		say.call("Ooh, I looked it up! A redwood called Hyperion, 116 meters tall!")
		push.call(0.1, {"type": "tool", "name": "give_item", "args": {"item": "seed_tomato", "count": 2}})
		say.call("Actually yes! Could you bring me 3 %s? I'll pay you in bells!" % item)
		push.call(0.1, {"type": "tool", "name": "emote", "args": {"kind": "idea"}})
		push.call(0.1, {"type": "tool", "name": "give_quest", "args": {"item": item, "count": 3, "title": "3 %s for %s" % [item, npc.capitalize()], "reward": 300}})
		push.call(0.4, {"type": "tool", "name": "animate", "args": {"kind": "spin"}})
		say.call("Here's a little something for the road, too!")
		push.call(0.1, {"type": "tool", "name": "gift", "args": {"bells": 50}})
	if npc == "juniper" and OS.get_environment("HV_MOCK_R3") != "":
		player_says.call("Can you help me water my crops?")
		push.call(0.2, {"type": "tool", "name": "help_farm", "args": {"action": "water"}})
		say.call("Sure! Let me show you how it works, too.")
		push.call(0.1, {"type": "tool", "name": "teach", "args": {"title": "Watering crops", "steps": ["Face a planted seed", "Press F to water", "Dark soil means it's growing"], "fact": "A tomato is about 95% water."}})
		push.call(0.1, {"type": "tool", "name": "show_me", "args": {"topic": "harvest"}})
		push.call(0.1, {"type": "tool", "name": "follow", "args": {}})
	say.call("Okay, see you around!")
	push.call(0.8, {"type": "tool", "name": "end_conversation", "args": {}})
	push.call(0.3, {"type": "status", "status": "ended"})

func _mock_tick(delta: float) -> void:
	if _mock_queue.is_empty():
		return
	_mock_t += delta
	while not _mock_queue.is_empty() and _mock_queue[0][0] <= _mock_t:
		var ev: Dictionary = _mock_queue.pop_front()[1]
		if ev["type"] == "speaking":
			_mock_speaking = ev["on"]
		_emit(ev)
	if _mock_speaking:
		volume.emit(0.35 + 0.35 * sin(_mock_t * 17.0) * sin(_mock_t * 5.3))
