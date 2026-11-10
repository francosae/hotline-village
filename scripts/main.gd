extends Node2D
## Builds the village, wires the voice bridge to NPCs, HUD and dialogue.

const NPCScript := preload("res://scripts/npc.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CollectibleScript := preload("res://scripts/collectible.gd")
const HudScript := preload("res://scripts/hud.gd")
const DialogueScript := preload("res://scripts/dialogue.gd")

const W := 60
const H := 40
const T := 16
const POND_C := Vector2(46, 30)
const POND_R := Vector2(6.5, 4.5)
const TALK_DIST := 36.0
const PREWARM_DIST := 80.0
const LEAVE_DIST := 110.0

var world: Node2D
var player: CharacterBody2D
var camera: Camera2D
var hud: CanvasLayer
var dialogue: CanvasLayer
var npcs := {}
var prewarmed := {}
var talking := ""
var rng := RandomNumberGenerator.new()
var solids: Array[Rect2] = []

func _ready() -> void:
	rng.seed = 7
	_build_ground()
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	_build_bounds()
	_build_pond()
	_build_houses()
	_build_fences()
	_build_trees()
	_build_flowers()
	_spawn_npcs()
	_spawn_player()
	_spawn_collectibles()
	_build_ambient()
	hud = CanvasLayer.new()
	hud.set_script(HudScript)
	add_child(hud)
	dialogue = CanvasLayer.new()
	dialogue.set_script(DialogueScript)
	add_child(dialogue)
	Hotline.status.connect(_on_status)
	Hotline.speech.connect(func(n, who, text, fin): if n == talking: dialogue.on_speech(who, text, fin))
	Hotline.speaking.connect(func(n, on): if n == talking: dialogue.on_speaking(on))
	Hotline.volume.connect(func(l): dialogue.on_volume(l))
	Hotline.tool.connect(_on_tool)
	Hotline.lookup.connect(_on_lookup)
	Sfx.music_on()
	if OS.get_environment("HV_SHOT") != "":
		_shot_tour()

# ---------------- world ----------------
func _is_path(x: int, y: int) -> bool:
	return (y >= 19 and y <= 20 and x >= 2 and x <= W - 3) or (x >= 29 and x <= 30 and y >= 2 and y <= H - 3) \
		or (y >= 13 and y <= 18 and x >= 14 and x <= 15) or (y >= 13 and y <= 18 and x >= 44 and x <= 45)

func _in_pond(x: float, y: float) -> bool:
	var d := Vector2((x - POND_C.x) / POND_R.x, (y - POND_C.y) / POND_R.y)
	return d.length() < 1.0

func _build_ground() -> void:
	var grass := Art.ground_image(Art.GROUND["grass_path"])
	var dirt := Art.ground_image(Art.GROUND["path_path"])
	var water := Art.ground_image(Art.GROUND["water_path"])
	var img := Image.create(W * T, H * T, false, Image.FORMAT_RGBA8)
	var regions: Array = Art.GROUND["grass"]
	var weights: Array = Art.GROUND["grass_weights"]
	var total := 0
	for w in weights:
		total += w
	for y in H:
		for x in W:
			var r := rng.randi() % total
			var idx := 0
			while r >= weights[idx]:
				r -= weights[idx]
				idx += 1
			img.blit_rect(grass, regions[0], Vector2i(x * T, y * T))
			if idx != 0:
				img.blend_rect(grass, regions[idx], Vector2i(x * T, y * T))
			if _is_path(x, y):
				img.blend_rect(dirt, Art.GROUND["path"], Vector2i(x * T, y * T))
			if _in_pond(x + 0.5, y + 0.5):
				img.blit_rect(water, Art.GROUND["water"], Vector2i(x * T, y * T))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.z_index = -10
	add_child(s)

func _solid(pos: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.position = pos
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	c.shape = r
	b.add_child(c)
	add_child(b)
	solids.append(Rect2(pos - size * 0.5, size))

func _build_bounds() -> void:
	_solid(Vector2(W * T * 0.5, -8), Vector2(W * T, 16))
	_solid(Vector2(W * T * 0.5, H * T + 8), Vector2(W * T, 16))
	_solid(Vector2(-8, H * T * 0.5), Vector2(16, H * T))
	_solid(Vector2(W * T + 8, H * T * 0.5), Vector2(16, H * T))

func _build_pond() -> void:
	var b := StaticBody2D.new()
	var poly := CollisionPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2((POND_C.x + cos(a) * (POND_R.x - 0.6)) * T, (POND_C.y + sin(a) * (POND_R.y - 0.6)) * T))
	poly.polygon = pts
	b.add_child(poly)
	add_child(b)
	solids.append(Rect2((POND_C - POND_R) * T, POND_R * 2 * T))
	for p in [Vector2(44, 29), Vector2(48.5, 31.5), Vector2(46, 32.5)]:
		_prop("lily", p * T, false)

func _prop(id: String, pos: Vector2, solid := true) -> Sprite2D:
	var d: Dictionary = Art.PROPS[id]
	var s := Sprite2D.new()
	s.texture = Art.prop(id)
	s.position = pos
	s.offset = Vector2(0, -d["region"].size.y * 0.5 + 2)
	world.add_child(s)
	var sz: Vector2 = d["solid"]
	if solid and sz != Vector2.ZERO:
		var b := StaticBody2D.new()
		var c := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = sz
		c.shape = r
		c.position = Vector2(0, -sz.y * 0.5)
		b.add_child(c)
		s.add_child(b)
		solids.append(Rect2(pos - Vector2(sz.x * 0.5, sz.y), sz))
	return s

func _house(base: Vector2) -> void:
	var h := Node2D.new()
	h.position = base
	world.add_child(h)
	for i in 2:
		var w := Sprite2D.new()
		w.texture = Art.prop("house_wall")
		w.centered = false
		w.position = Vector2(-32 + i * 32, -32)
		h.add_child(w)
	var r := Sprite2D.new()
	r.texture = Art.prop("house_roof")
	r.centered = false
	r.position = Vector2(-32, -72)
	h.add_child(r)
	_solid(base + Vector2(0, -14), Vector2(64, 28))

func _build_houses() -> void:
	_house(Vector2(14.5 * T, 12.5 * T))
	_house(Vector2(44.5 * T, 12.5 * T))
	_prop("coop", Vector2(8 * T, 31 * T))
	_prop("chest", Vector2(17.5 * T, 13 * T))

func _build_fences() -> void:
	# Juniper's garden (bottom middle-left)
	for i in 3:
		_prop("fence_h", Vector2((19.5 + i * 3) * T, 26 * T))
		_prop("fence_h", Vector2((19.5 + i * 3) * T, 35 * T))
	for y in range(27, 35):
		if y != 30 and y != 31:
			_prop("fence_post", Vector2(17.5 * T, y * T + 8))
			_prop("fence_post", Vector2(27.5 * T, y * T + 8))
	for y in range(28, 34):
		for x in [20, 22, 24]:
			if rng.randf() < 0.7:
				_prop("sunflower" if rng.randf() < 0.3 else ["flower_p", "flower_y", "flower_b", "sprout"][rng.randi() % 4], Vector2(x * T + 8, y * T + 8), false)

func _free(pos: Vector2, margin := 14.0) -> bool:
	var tx := pos.x / T
	var ty := pos.y / T
	if _is_path(int(tx), int(ty)) or _in_pond(tx, ty):
		return false
	if _in_pond(tx + 1, ty) or _in_pond(tx - 1, ty) or _in_pond(tx, ty + 1) or _in_pond(tx, ty - 1):
		return false
	for r in solids:
		if r.grow(margin).has_point(pos):
			return false
	for n in npcs.values():
		if n.position.distance_to(pos) < 30:
			return false
	if pos.distance_to(Vector2(30 * T, 22 * T)) < 30:
		return false
	if Rect2(17 * T, 25 * T, 11 * T, 11 * T).has_point(pos):
		return false
	return true

func _build_trees() -> void:
	var kinds := ["tree_big", "tree_small", "tree_fruit", "tree_big"]
	# border ring
	for x in range(0, W * T + 1, 26):
		for y in [12.0, H * T - 2.0]:
			_prop(kinds[rng.randi() % 4], Vector2(x + rng.randf_range(-4, 4), y))
	for y in range(30, H * T - 20, 26):
		for x in [8.0, W * T - 8.0]:
			_prop(kinds[rng.randi() % 4], Vector2(x, y + rng.randf_range(-4, 4)))
	# scattered
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(40, W * T - 40), rng.randf_range(50, H * T - 40))
		if _free(p, 22):
			_prop(kinds[rng.randi() % 4] if rng.randf() < 0.65 else ["bush", "bush_berry", "rock"][rng.randi() % 3], p)
			placed += 1

func _build_flowers() -> void:
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(30, W * T - 30), rng.randf_range(30, H * T - 30))
		if _free(p, 4):
			_prop(["flower_p", "flower_y", "flower_y2", "flower_b", "sprout", "sprout"][rng.randi() % 6], p, false)
			placed += 1

func _spawn_npcs() -> void:
	var spots := {"maple": Vector2(17 * T, 16 * T), "clucky": Vector2(10.5 * T, 33 * T), "juniper": Vector2(23 * T, 31 * T)}
	for id in spots:
		var n := StaticBody2D.new()
		n.set_script(NPCScript)
		n.setup(id)
		n.position = spots[id]
		n.name = id
		world.add_child(n)
		npcs[id] = n

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = Vector2(30 * T, 22 * T)
	world.add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(4, 4)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = W * T
	camera.limit_bottom = H * T
	player.add_child(camera)

func _spawn_collectibles() -> void:
	for item in GameState.ITEMS:
		for i in 3:
			var tries := 0
			while tries < 200:
				tries += 1
				var p := Vector2(rng.randf_range(40, W * T - 40), rng.randf_range(50, H * T - 40))
				if _free(p, 10):
					var c := Area2D.new()
					c.set_script(CollectibleScript)
					c.item = item
					c.position = p
					c.picked.connect(_on_picked)
					world.add_child(c)
					solids.append(Rect2(p - Vector2(6, 6), Vector2(12, 12)))
					break

func _build_ambient() -> void:
	var petals := CPUParticles2D.new()
	petals.amount = 40
	petals.lifetime = 7.0
	petals.preprocess = 7.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(220, 10)
	petals.position = Vector2(20, -110)
	petals.local_coords = false
	petals.direction = Vector2(-0.4, 1)
	petals.spread = 20
	petals.gravity = Vector2(0, 4)
	petals.initial_velocity_min = 10
	petals.initial_velocity_max = 20
	petals.angular_velocity_min = -90
	petals.angular_velocity_max = 90
	petals.scale_amount_min = 1.0
	petals.scale_amount_max = 2.0
	petals.color = Color("#ffc4d6")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.1, 0.85, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	petals.color_ramp = g
	petals.z_index = 30
	camera.add_child(petals)
	var flies := CPUParticles2D.new()
	flies.amount = 14
	flies.lifetime = 5.0
	flies.preprocess = 5.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(170, 95)
	flies.local_coords = false
	flies.spread = 180
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 3
	flies.initial_velocity_max = 8
	flies.orbit_velocity_min = -0.1
	flies.orbit_velocity_max = 0.1
	flies.color = Color("#fff9b0")
	flies.color_ramp = g
	flies.scale_amount_min = 1.0
	flies.scale_amount_max = 1.5
	flies.z_index = 30
	camera.add_child(flies)

# ---------------- interaction ----------------
func _process(_delta: float) -> void:
	var nearest := ""
	var nd := 1e9
	for id in npcs:
		var d: float = player.position.distance_to(npcs[id].position)
		if d < PREWARM_DIST and not prewarmed.get(id, false):
			prewarmed[id] = true
			Hotline.prewarm(id)
		elif d > PREWARM_DIST * 1.5:
			prewarmed[id] = false
		if d < nd:
			nd = d
			nearest = id
	for id in npcs:
		npcs[id].set_near(id == nearest and nd < TALK_DIST and talking == "")
	if talking != "" and player.position.distance_to(npcs[talking].position) > LEAVE_DIST:
		_hang_up()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: Key = e.physical_keycode
		if k == KEY_E or k == KEY_SPACE:
			if talking == "":
				_try_talk()
		elif k == KEY_ESCAPE and talking != "":
			_hang_up()

func _try_talk() -> void:
	if talking != "":
		return
	var best := ""
	var bd := TALK_DIST
	for id in npcs:
		var d: float = player.position.distance_to(npcs[id].position)
		if d < bd:
			bd = d
			best = id
	if best == "":
		for c in world.get_children():
			if c is Area2D and c.get("active") and player.position.distance_to(c.position) < 22:
				c.pickup()
				return
		return
	talking = best
	npcs[best].hide_prompt()
	npcs[best].animate("jump")
	dialogue.open_for(best)
	Hotline.start(best, GameState.context_json(best))

func _hang_up() -> void:
	if talking == "":
		return
	Hotline.stop()
	talking = ""
	dialogue.close()

func _on_status(n: String, st: String, msg: String) -> void:
	if n != talking:
		return
	dialogue.on_status(st, msg)
	if st == "ended":
		talking = ""
		dialogue.close()
	elif st == "error":
		var was := talking
		await get_tree().create_timer(2.5).timeout
		if talking == was:
			talking = ""
			dialogue.close()

func _on_tool(n: String, tname: String, args: Dictionary) -> void:
	var npc = npcs.get(n)
	match tname:
		"emote":
			if npc: npc.emote(str(args.get("kind", "happy")))
		"animate":
			if npc: npc.animate(str(args.get("kind", "jump")))
		"give_quest":
			var item := str(args.get("item", "egg"))
			if not Art.ITEMS.has(item):
				Hotline.inform("Unknown item '%s'. Valid items: %s, plant_tree" % [item, ", ".join(GameState.ITEMS)])
				return
			var q := GameState.add_quest(n, item, int(args.get("count", 3)), str(args.get("title", "Bring %s" % item)), int(args.get("reward", 200)))
			hud.toast("New quest!  %s" % q["title"], Color("#ff9f43"))
			Sfx.play("quest")
			if npc: Fx.burst(world, npc.position + Vector2(0, -20), "sparkle")
		"complete_quest":
			var item := str(args.get("item", ""))
			var r := GameState.try_complete(n, item)
			if r["ok"]:
				var q: Dictionary = r["quest"]
				hud.toast("Quest complete!  +%d bells" % int(q["reward"]), Color("#3aa35b"))
				Sfx.play("jingle", 0.0, -2.0)
				if npc: Fx.burst(world, npc.position + Vector2(0, -16), "confetti")
				Hotline.inform("Quest complete: player handed over %d %s and received %d bells. They now have %d bells." % [int(q["count"]), item, int(q["reward"]), GameState.bells])
			elif (r["quest"] as Dictionary).is_empty():
				Hotline.inform("There is no active quest for %s. Player has %d %s." % [item, int(r["have"]), item])
				Sfx.play("error")
			else:
				Hotline.inform("Player only has %d/%d %s. The quest is not complete yet." % [int(r["have"]), int(r["need"]), item])
				hud.toast("Not enough %s yet  (%d/%d)" % [item, int(r["have"]), int(r["need"])], Color("#e07a5f"))
				Sfx.play("error")
		"give_item":
			var item := str(args.get("item", ""))
			var cnt := clampi(int(args.get("count", 1)), 1, 20)
			if not Art.ITEMS.has(item) or item == "plant_tree":
				Hotline.inform("Can't give '%s': unknown item." % item)
				return
			GameState.add_item(item, cnt)
			hud.toast("Got %d %s!" % [cnt, Art.item_name(item)], Color("#7bc96f"))
			Sfx.play("pickup", 0.05, -2.0)
			if npc:
				Fx.burst(world, npc.position + Vector2(0, -14), "sparkle")
				Fx.float_text(world, player.position + Vector2(0, -18), "+%d %s" % [cnt, Art.item_name(item)])
			Hotline.inform("Player received %d %s and now has %d." % [cnt, item, GameState.count(item)])
		"gift":
			var b := int(args.get("bells", 0))
			if b > 0:
				GameState.add_bells(b)
				hud.toast("+%d bells!" % b, Color("#f4b400"))
				if npc: Fx.burst(world, npc.position + Vector2(0, -16), "sparkle")
		"end_conversation":
			await get_tree().create_timer(1.2).timeout
			if talking == n:
				_hang_up()

func _on_lookup(n: String, query: String, st: String, summary: String) -> void:
	var npc = npcs.get(n)
	match st:
		"start":
			if npc: npc.emote("book")
			dialogue.show_lookup(Art.NPC_NAMES.get(n, n), query)
			Sfx.play("talk", 0.1, -8.0)
		"done":
			if npc:
				npc.emote("idea")
				Fx.burst(world, npc.position + Vector2(0, -20), "sparkle")
			dialogue.show_learned(Art.NPC_NAMES.get(n, n), query, summary)
			Sfx.play("quest", 0.05, -6.0)
		_:
			if npc: npc.emote("sad")
			dialogue.lookup_failed(Art.NPC_NAMES.get(n, n))

func _on_picked(item: String, pos: Vector2) -> void:
	GameState.add_item(item, 1)
	Sfx.play("pickup", 0.12)
	Fx.burst(world, pos + Vector2(0, -8), "pop")
	Fx.float_text(world, pos + Vector2(0, -10), "+1 %s" % item)
	for q in GameState.active_quests():
		if q["item"] == item:
			var have := GameState.count(item)
			if have <= int(q["count"]) and have == int(q["count"]):
				hud.toast("Got all %d %s! Go see %s" % [int(q["count"]), item, Art.NPC_NAMES.get(q["npc"], q["npc"])], Color("#3aa35b"))
			if Hotline.in_call:
				Hotline.inform("Player picked up a %s and now has %d/%d %s for the quest '%s'." % [item, mini(have, int(q["count"])), int(q["count"]), item, q["title"]])
			break

# ---------------- screenshot tour (HV_SHOT=1) ----------------
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/hv_%s.png" % name)
	print("[shot] /tmp/hv_%s.png" % name)

func _shot_tour() -> void:
	await get_tree().create_timer(1.5).timeout
	await _shot("1_village")
	player.position = npcs["maple"].position + Vector2(-20, 14)
	await get_tree().create_timer(1.2).timeout
	await _shot("2_near_maple")
	_try_talk()
	await get_tree().create_timer(3.2).timeout
	await _shot("3_dialogue")
	await get_tree().create_timer(2.6).timeout
	await _shot("3b_lookup")
	await get_tree().create_timer(2.4).timeout
	await _shot("3c_learned")
	await get_tree().create_timer(6.5).timeout
	await _shot("4_quest")
	await get_tree().create_timer(5.0).timeout
	GameState.add_item("milk", 3)
	GameState.add_item("egg", 1)
	player.position = npcs["juniper"].position + Vector2(-14, 16)
	await get_tree().create_timer(1.5).timeout
	await _shot("5_garden")
	player.position = npcs["maple"].position + Vector2(-20, 14)
	await get_tree().create_timer(1.0).timeout
	_try_talk()
	await get_tree().create_timer(5.2).timeout
	await _shot("6_complete")
	get_tree().quit()
