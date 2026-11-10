extends Node
## Round 3 villager commands: follow / stay / go_to / help_farm / show_me / teach (+ give_quest.lesson).
## Listens to Hotline.tool directly (main's dispatch ignores unknown tools). Child of the Farm node.

const SPEED := 48.0
const T := 16
const PLACES := {
	"farm": Vector2(35 * T, 22 * T + 4),      # farm plot gate
	"pond": Vector2(38 * T + 4, 30 * T),
	"plaza": Vector2(30 * T, 21 * T + 8),
	"garden": Vector2(16 * T + 8, 30 * T + 8),
	"house": Vector2(14 * T + 8, 13 * T + 10),
}
const LESSONS := {
	"till": ["Tilling soil", ["Walk into the fenced farm plot", "Face a grass tile", "Press F to till it into soil"], "Tilling loosens soil so roots and water can get in."],
	"plant": ["Planting seeds", ["Face a tilled soil tile", "Press Q to pick tomato or wheat", "Press F to plant"], "Wheat is one of the oldest farmed crops, over 10,000 years!"],
	"water": ["Watering crops", ["Face a planted seed", "Press F to water it", "Dark soil means it's growing"], "Plants are mostly water: a tomato is about 95% water."],
	"harvest": ["Harvesting", ["Wait for the sparkle", "Face the ripe crop", "Press F to pick it"], "Tomatoes are botanically fruits, not vegetables."],
	"plant_tree": ["Planting a tree", ["Get a sapling from a villager", "Face open grass outside the plot", "Press F, then shake it with F for wood"], "One big tree can make oxygen for about two people."],
	"quests": ["Doing quests", ["Talk to a villager with E", "Bring what they ask for", "Talk again to hand it in for bells"], ""],
}

var main: Node2D
var farm: Node2D
var following := {}       # npc_id -> true
var targets := {}         # npc_id -> Vector2
var busy := {}            # npc_id -> true while running a job
var hop_t := {}
var card: PanelContainer
var card_layer: CanvasLayer
var card_tween: Tween

func _ready() -> void:
	farm = get_parent()
	main = farm.get_parent()
	Hotline.tool.connect(_on_tool)
	card_layer = CanvasLayer.new()
	card_layer.layer = 6
	add_child(card_layer)
	if OS.get_environment("HV_R3_TEST") != "":
		_test.call_deferred()

func _on_tool(n: String, tname: String, args: Dictionary) -> void:
	var npc = main.npcs.get(n)
	match tname:
		"follow":
			if npc:
				targets.erase(n)
				following[n] = true
				npc.emote("happy")
		"stay":
			following.erase(n)
			targets.erase(n)
		"go_to":
			var place := str(args.get("place", "plaza"))
			if npc and PLACES.has(place):
				following.erase(n)
				targets[n] = PLACES[place]
		"help_farm":
			if npc: _help_farm(n, str(args.get("action", "water")))
		"show_me":
			if npc: _show_me(n, str(args.get("topic", "water")))
		"teach":
			var steps: Array = []
			for s in args.get("steps", []):
				steps.append(str(s))
			show_lesson(str(args.get("title", "Lesson")), steps, str(args.get("fact", "")))
		"give_quest":
			var lesson := str(args.get("lesson", ""))
			if lesson != "":
				var q: Dictionary = GameState.find_quest(n, str(args.get("item", "")))
				if not q.is_empty():
					q["lesson"] = lesson
					GameState.quests_changed.emit()

# ---------------- movement ----------------
func _process(delta: float) -> void:
	for id in main.npcs:
		var npc: Node2D = main.npcs[id]
		var goal = null
		if following.has(id):
			var back: Vector2 = main.player.position - npc.position
			if back.length() > 26.0:
				goal = main.player.position - back.normalized() * 22.0
		elif targets.has(id):
			goal = targets[id]
		if goal == null:
			_settle(npc)
			continue
		var d: Vector2 = goal - npc.position
		if d.length() < 2.0:
			targets.erase(id)
			_settle(npc)
			continue
		npc.position += d.normalized() * minf(SPEED * delta, d.length())
		_walk_anim(id, npc, d, delta)

func _walk_anim(id: String, npc: Node2D, d: Vector2, delta: float) -> void:
	var spr: AnimatedSprite2D = npc.sprite
	if absf(d.x) > 0.5:
		spr.flip_h = d.x < 0 if id != "maple" else d.x > 0
	hop_t[id] = hop_t.get(id, 0.0) + delta * 12.0
	spr.position.y = -absf(sin(hop_t[id])) * 2.5
	spr.rotation = sin(hop_t[id]) * 0.08
	spr.speed_scale = 2.0

func _settle(npc: Node2D) -> void:
	var spr: AnimatedSprite2D = npc.sprite
	if spr.speed_scale != 1.0:
		spr.position.y = 0.0
		spr.rotation = 0.0
		spr.speed_scale = 1.0

func walk_to(n: String, pos: Vector2) -> void:
	following.erase(n)
	targets[n] = pos
	var guard := 0.0
	while targets.has(n) and guard < 20.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	targets.erase(n)

# ---------------- farm help ----------------
func _plot_tiles() -> Array:
	var out: Array = []
	for y in range(farm.PLOT.position.y, farm.PLOT.end.y):
		for x in range(farm.PLOT.position.x, farm.PLOT.end.x):
			out.append(Vector2i(x, y))
	return out

func _tiles_for(action: String) -> Array:
	var out: Array = []
	for t in _plot_tiles():
		var st: Dictionary = farm.tiles.get(t, {})
		match action:
			"till":
				if st.is_empty() and out.size() < 6: out.append(t)
			"water":
				if not st.is_empty() and st["crop"] != null and not st["crop"].watered: out.append(t)
			"harvest":
				if not st.is_empty() and st["crop"] != null and st["crop"].ready_to_harvest(): out.append(t)
			"plant":
				if not st.is_empty() and st["crop"] == null and out.size() < 1: out.append(t)
	return out

func _do(action: String, t: Vector2i, npc: Node2D) -> void:
	npc.animate("jump")
	match action:
		"till": farm._till(t)
		"water": farm._water(t)
		"harvest": farm._harvest(t)
		"plant":
			if GameState.count(farm._seed()) > 0: farm._plant(t)

func _help_farm(n: String, action: String) -> void:
	if busy.has(n):
		return
	busy[n] = true
	var npc: Node2D = main.npcs[n]
	await walk_to(n, PLACES["farm"])
	var tiles := _tiles_for(action)
	if tiles.is_empty():
		npc.emote("question")
		if Hotline.in_call:
			Hotline.inform("Nothing to %s on the farm right now." % action)
	for t in tiles:
		await walk_to(n, farm.tile_center(t) + Vector2(0, 10))
		_do(action, t, npc)
		await get_tree().create_timer(0.35).timeout
	if not tiles.is_empty():
		npc.emote("happy")
		if Hotline.in_call:
			Hotline.inform("Done: you %s %d farm tiles." % [action if action != "till" else "tilled", tiles.size()])
	busy.erase(n)

func _show_me(n: String, topic: String) -> void:
	var npc: Node2D = main.npcs[n]
	var l: Array = LESSONS.get(topic, LESSONS["quests"])
	if topic in ["till", "plant", "water", "harvest"] and not busy.has(n):
		busy[n] = true
		await walk_to(n, PLACES["farm"])
		var tiles := _tiles_for(topic)
		if tiles.is_empty() and topic == "till":
			tiles = []
		if not tiles.is_empty():
			await walk_to(n, farm.tile_center(tiles[0]) + Vector2(0, 10))
			_do(topic, tiles[0], npc)
		busy.erase(n)
	elif topic == "plant_tree":
		await walk_to(n, PLACES["farm"] + Vector2(-8, 40))
		npc.animate("jump")
		farm._particles(npc.position, "dust")
	npc.emote("idea")
	show_lesson(l[0], l[1], l[2])

# ---------------- lesson card ----------------
func show_lesson(title: String, steps: Array, fact: String) -> void:
	if GameState.get("lessons") is Array:
		var known := false
		for x in GameState.lessons:
			if x.get("title", "") == title:
				known = true
		if not known:
			GameState.lessons.append({"title": title, "steps": steps, "fact": fact})
			GameState.quests_changed.emit()
	if card and is_instance_valid(card):
		card.queue_free()
	card = PanelContainer.new()
	var sb := UiKit.box(UiKit.CREAM, 28, true, 4, Color("#cfe8b0"))
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 34
	sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", sb)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.offset_top = -40
	card.custom_minimum_size = Vector2(440, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	var tl := UiKit.bold(title, 30, UiKit.BROWN)
	vb.add_child(tl)
	for i in steps.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var num := PanelContainer.new()
		var ns := UiKit.box(Color("#7cc35a"), 16, false)
		ns.content_margin_left = 10
		ns.content_margin_right = 10
		ns.content_margin_top = 0
		ns.content_margin_bottom = 2
		num.add_theme_stylebox_override("panel", ns)
		num.add_child(UiKit.bold(str(i + 1), 20, Color.WHITE))
		row.add_child(num)
		var sl := UiKit.label(str(steps[i]), 21)
		row.add_child(sl)
		vb.add_child(row)
	if fact != "":
		var fp := PanelContainer.new()
		var fs := UiKit.box(Color("#fff1c9"), 16, false)
		fs.content_margin_left = 14
		fs.content_margin_right = 14
		fp.add_theme_stylebox_override("panel", fs)
		var fl := UiKit.label("Fun fact: " + fact, 18, Color("#8a6236"))
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size = Vector2(380, 0)
		fp.add_child(fl)
		vb.add_child(fp)
	# tilted green "Lesson" tag on the corner
	var tag := PanelContainer.new()
	var ts := UiKit.box(Color("#5fb14a"), 18, true)
	ts.shadow_size = 4
	ts.content_margin_left = 16
	ts.content_margin_right = 16
	ts.content_margin_top = 2
	ts.content_margin_bottom = 4
	tag.add_theme_stylebox_override("panel", ts)
	tag.add_child(UiKit.bold("Lesson", 22, Color.WHITE))
	tag.position = Vector2(-44, -54)
	tag.rotation = -0.12
	card_layer.add_child(card)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tag)
	card.add_child(holder)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	UiKit.pop_in(card, 0.7)
	Sfx.play("quest", 0.05, -4.0)
	var c := card
	get_tree().create_timer(12.0).timeout.connect(func():
		if is_instance_valid(c):
			var t := c.create_tween()
			t.tween_property(c, "scale", Vector2(0.8, 0.8), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(c, "modulate:a", 0.0, 0.18)
			t.tween_callback(c.queue_free))

# ---------------- automated check (HV_R3_TEST=1 HV_FARM_FAST=1) ----------------
func _test() -> void:
	await get_tree().create_timer(1.0).timeout
	var row := [Vector2i(33, 25), Vector2i(34, 25)]
	for t in row:
		farm._till(t)
		farm._plant(t)
	_on_tool("juniper", "help_farm", {"action": "water"})
	await get_tree().create_timer(4.0).timeout
	main.player.position = main.npcs["juniper"].position + Vector2(-30, 10)
	await get_tree().create_timer(2.5).timeout
	await farm._shot("r3_1_helpfarm")
	_on_tool("juniper", "show_me", {"topic": "harvest"})
	await get_tree().create_timer(5.0).timeout
	main.player.position = main.npcs["juniper"].position + Vector2(-30, 10)
	await get_tree().create_timer(0.8).timeout
	await farm._shot("r3_2_showme")
	_on_tool("maple", "follow", {})
	_on_tool("clucky", "go_to", {"place": "farm"})
	main.player.position = Vector2(31 * T, 26 * T)
	await get_tree().create_timer(4.0).timeout
	_on_tool("maple", "teach", {"title": "Bees and flowers", "steps": ["Bees visit flowers", "Pollen sticks to them", "Next flower gets pollinated"], "fact": "A bee visits up to 5,000 flowers a day."})
	await get_tree().create_timer(0.6).timeout
	await farm._shot("r3_3_follow_teach")
	print("[r3] lessons ", GameState.get("lessons"), " inv ", GameState.inventory)
	get_tree().quit()
