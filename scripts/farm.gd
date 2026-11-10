extends Node2D
## Farming: fenced plot (till / plant / water / harvest) + tree planting. Added as a child of main.
## F acts on the faced tile (E too when no villager/pickup is near). Q switches seed.

const CropScript := preload("res://scripts/crop.gd")
const TreeScript := preload("res://scripts/tree_sapling.gd")
const T := 16
const DIRT := "res://assets/sprout/Tilesets/Tilled Dirt.png"
const FENCES := "res://assets/sprout/Tilesets/Fences.png"
# Inner plot tiles (fence ring sits one tile outside). Right of the main path, left of the pond.
const PLOT := Rect2i(32, 23, 6, 6)
const GATE := [34, 35]   # gap in the top fence (faces the path)
const SEEDS := {"seed_wheat": "wheat", "seed_tomato": "tomato"}
const DRY := Color(1, 1, 1)
const WET := Color(0.62, 0.5, 0.46)

var main: Node2D
var soil_layer: Node2D
var tiles := {}       # Vector2i -> {"soil": Sprite2D, "crop": Node2D or null}
var trees: Array = []
var seed_sel := "seed_tomato"
var stage_time := 12.0
var tree_time := 20.0
var hint_panel: PanelContainer
var hint_label: Label
var cursor: Node2D
var cur_action := {}

func _ready() -> void:
	main = get_parent()
	if OS.get_environment("HV_FARM_FAST") != "":
		stage_time = 1.5
		tree_time = 4.0
	soil_layer = Node2D.new()
	soil_layer.z_index = -5
	add_child(soil_layer)
	cursor = Node2D.new()
	cursor.z_index = -4
	cursor.draw.connect(_draw_cursor)
	add_child(cursor)
	_build_hint()
	var acts := Node.new()
	acts.set_script(preload("res://scripts/npc_actions.gd"))
	acts.name = "NpcActions"
	add_child(acts)
	call_deferred("_build_plot")
	var start := {"seed_tomato": 3, "seed_wheat": 3, "sapling": 1}
	for k in start:
		if GameState.count(k) == 0:
			GameState.add_item(k, start[k])
	if OS.get_environment("HV_FARM_TEST") != "":
		_test_tour.call_deferred()

# ---------------- plot ----------------
func _build_plot() -> void:
	var world: Node2D = main.world
	var outer := Rect2((PLOT.position - Vector2i.ONE) * T, (PLOT.size + Vector2i(2, 2)) * T).grow(6)
	for c in world.get_children():
		if c == main.player or c.name in main.npcs:
			continue
		if c is Node2D and outer.has_point(c.position):
			c.queue_free()
	# soft dirt border so the plot reads as a garden bed
	var bed := Sprite2D.new()
	var img := Image.create(PLOT.size.x * T, PLOT.size.y * T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.42, 0.62, 0.3, 0.25))
	bed.texture = ImageTexture.create_from_image(img)
	bed.centered = false
	bed.position = PLOT.position * T
	soil_layer.add_child(bed)
	var x0 := PLOT.position.x - 1
	var x1 := PLOT.end.x
	var y0 := PLOT.position.y - 1
	var y1 := PLOT.end.y
	for x in range(x0, x1 + 1):
		for y in [y0, y1]:
			var r: Rect2
			if x == x0:
				r = Rect2(16, 0, 16, 16) if y == y0 else Rect2(16, 32, 16, 16)
			elif x == x1:
				r = Rect2(48, 0, 16, 16) if y == y0 else Rect2(48, 32, 16, 16)
			elif y == y0 and x in GATE:
				continue
			elif y == y0 and x == GATE[0] - 1:
				r = Rect2(48, 48, 16, 16)
			elif y == y0 and x == GATE[-1] + 1:
				r = Rect2(16, 48, 16, 16)
			else:
				r = Rect2(32, 48, 16, 16)
			_fence(world, Vector2i(x, y), r, Vector2(16, 4))
	for y in range(y0 + 1, y1):
		for x in [x0, x1]:
			_fence(world, Vector2i(x, y), Rect2(0, 16, 16, 16), Vector2(4, 16))

func _fence(world: Node2D, tile: Vector2i, region: Rect2, solid: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Art.atlas(FENCES, region)
	s.position = Vector2(tile.x * T + 8, tile.y * T + 12)
	s.offset = Vector2(0, -4)
	world.add_child(s)
	var b := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = solid
	c.shape = rs
	c.position = Vector2(0, -2) if solid.x > solid.y else Vector2(0, -4)
	b.add_child(c)
	s.add_child(b)

func in_plot(tile: Vector2i) -> bool:
	return Rect2i(PLOT).has_point(tile)

func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * T + 8, tile.y * T + 8)

# ---------------- targeting ----------------
func _facing_vec() -> Vector2:
	match str(main.player.facing):
		"up": return Vector2(0, -1)
		"left": return Vector2(-1, 0)
		"right": return Vector2(1, 0)
	return Vector2(0, 1)

func _target_tile() -> Vector2i:
	var p: Vector2 = main.player.position + Vector2(0, -4) + _facing_vec() * 12.0
	return Vector2i(floori(p.x / T), floori(p.y / T))

func _near_tree():
	var best = null
	var bd := 22.0
	var probe: Vector2 = main.player.position + _facing_vec() * 8.0
	for tr in trees:
		var d: float = probe.distance_to(tr.position)
		if d < bd:
			bd = d
			best = tr
	return best

func _seed() -> String:
	if GameState.count(seed_sel) <= 0:
		for s in SEEDS:
			if GameState.count(s) > 0:
				seed_sel = s
	return seed_sel

func _compute_action() -> Dictionary:
	if main.player == null or main.talking != "":
		return {}
	var tr = _near_tree()
	if tr != null:
		if tr.grown:
			return {"do": "shake", "tree": tr, "text": "F: Shake tree"}
		return {"do": "none", "tree": tr, "text": "Tree growing..."}
	var tile := _target_tile()
	if in_plot(tile):
		var st: Dictionary = tiles.get(tile, {})
		if st.is_empty():
			return {"do": "till", "tile": tile, "text": "F: Till soil"}
		var crop = st["crop"]
		if crop == null:
			var s := _seed()
			if GameState.count(s) <= 0:
				return {"do": "none", "tile": tile, "text": "No seeds (ask a villager!)"}
			var other := "   Q: switch" if GameState.count("seed_wheat") > 0 and GameState.count("seed_tomato") > 0 else ""
			return {"do": "plant", "tile": tile, "text": "F: Plant %s (x%d)%s" % [Art.item_name(s), GameState.count(s), other]}
		if crop.ready_to_harvest():
			return {"do": "harvest", "tile": tile, "text": "F: Harvest %s" % crop.kind}
		if not crop.watered:
			return {"do": "water", "tile": tile, "text": "F: Water"}
		return {"do": "none", "tile": tile, "text": "Growing... %d%%" % int(crop.progress() * 100)}
	# outside the plot: plant a sapling on free grass
	if GameState.count("sapling") > 0 and _can_plant_tree(tile):
		return {"do": "tree", "tile": tile, "text": "F: Plant sapling (x%d)" % GameState.count("sapling")}
	return {}

func _can_plant_tree(tile: Vector2i) -> bool:
	var pos := tile_center(tile)
	var outer := Rect2i(PLOT.position - Vector2i(2, 2), PLOT.size + Vector2i(4, 4))
	if outer.has_point(tile):
		return false
	if tile.x < 1 or tile.y < 2 or tile.x >= 59 or tile.y >= 39:
		return false
	for tr in trees:
		if tr.position.distance_to(pos) < 24:
			return false
	if pos.distance_to(main.player.position) < 6:
		return false
	return main._free(pos, 4)

# ---------------- loop ----------------
func _process(_delta: float) -> void:
	cur_action = _compute_action()
	var text: String = cur_action.get("text", "")
	if text != hint_label.text:
		hint_label.text = text
		if text != "" and not hint_panel.visible:
			hint_panel.visible = true
			UiKit.pop_in(hint_panel, 0.85)
		elif text == "":
			hint_panel.visible = false
	cursor.queue_redraw()

func _draw_cursor() -> void:
	if not cur_action.has("tile"):
		return
	var tile: Vector2i = cur_action["tile"]
	var r := Rect2(Vector2(tile * T) + Vector2(1, 1), Vector2(14, 14))
	var a := 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	cursor.draw_rect(r, Color(1, 1, 1, a), false, 1.0)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: Key = e.physical_keycode
	if k == KEY_Q:
		var other := "seed_wheat" if seed_sel == "seed_tomato" else "seed_tomato"
		if GameState.count(other) > 0:
			seed_sel = other
			Sfx.play("select")
		get_viewport().set_input_as_handled()
	elif k == KEY_F or (k == KEY_E and _e_free()):
		if act():
			get_viewport().set_input_as_handled()

func _e_free() -> bool:
	for id in main.npcs:
		if main.player.position.distance_to(main.npcs[id].position) < 36.0:
			return false
	for c in main.world.get_children():
		if c is Area2D and c.get("active") and main.player.position.distance_to(c.position) < 22:
			return false
	return main.talking == "" and cur_action.get("do", "none") != "none"

## Performs the current action. Returns true if something happened.
func act() -> bool:
	cur_action = _compute_action()
	var d: String = cur_action.get("do", "")
	if d == "" or d == "none":
		if cur_action.has("tile") and tiles.has(cur_action["tile"]) and tiles[cur_action["tile"]]["crop"] != null:
			tiles[cur_action["tile"]]["crop"].wiggle()
		return d == "none"
	_player_squash()
	match d:
		"till": _till(cur_action["tile"])
		"plant": _plant(cur_action["tile"])
		"water": _water(cur_action["tile"])
		"harvest": _harvest(cur_action["tile"])
		"tree": _plant_tree(cur_action["tile"])
		"shake": _shake(cur_action["tree"])
	return true

func _till(tile: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = Art.atlas(DIRT, Rect2(16, 0, 16, 16))
	s.position = tile_center(tile)
	soil_layer.add_child(s)
	s.scale = Vector2(1.3, 0.6)
	s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tiles[tile] = {"soil": s, "crop": null}
	_particles(tile_center(tile) + Vector2(0, 4), "dust")
	Sfx.play("pop", 0.15, -4.0)

func _plant(tile: Vector2i) -> void:
	var s := _seed()
	GameState.add_item(s, -1)
	var c := Node2D.new()
	c.set_script(CropScript)
	c.setup(SEEDS[s], stage_time)
	c.position = tile_center(tile)
	main.world.add_child(c)
	tiles[tile]["crop"] = c
	tiles[tile]["soil"].modulate = DRY
	_particles(tile_center(tile), "dust")
	Sfx.play("pickup", 0.1)

func _water(tile: Vector2i) -> void:
	var st: Dictionary = tiles[tile]
	st["crop"].watered = true
	var soil: Sprite2D = st["soil"]
	soil.create_tween().tween_property(soil, "modulate", WET, 0.3)
	_particles(tile_center(tile) - Vector2(0, 6), "water")
	Sfx.play("emote", 0.1)

func _harvest(tile: Vector2i) -> void:
	var st: Dictionary = tiles[tile]
	var crop: Node2D = st["crop"]
	var kind: String = crop.kind
	st["crop"] = null
	st["soil"].modulate = DRY
	var tw := crop.create_tween()
	tw.tween_property(crop, "scale", Vector2(1.4, 0.6), 0.06)
	tw.tween_property(crop, "scale", Vector2(0.6, 1.5), 0.08)
	tw.parallel().tween_property(crop, "position:y", crop.position.y - 10, 0.12)
	tw.tween_property(crop, "modulate:a", 0.0, 0.12)
	tw.tween_callback(crop.queue_free)
	GameState.add_item(kind, 1)
	Fx.burst(main.world, tile_center(tile) - Vector2(0, 6), "pop")
	Fx.burst(main.world, tile_center(tile) - Vector2(0, 6), "sparkle")
	Fx.float_text(main.world, tile_center(tile) - Vector2(0, 4), "+1 %s" % kind)
	Sfx.play("pickup", 0.12)
	_notify(kind)

func _plant_tree(tile: Vector2i) -> void:
	GameState.add_item("sapling", -1)
	var tr := Node2D.new()
	tr.set_script(TreeScript)
	tr.grow_time = tree_time
	tr.position = tile_center(tile) + Vector2(0, 6)
	main.world.add_child(tr)
	trees.append(tr)
	GameState.add_item("plant_tree", 1)
	_particles(tr.position, "dust")
	Fx.float_text(main.world, tr.position - Vector2(0, 8), "Tree planted!", Color("#b8f28b"))
	Sfx.play("quest", 0.05, -6.0)
	_notify("plant_tree")

func _shake(tr) -> void:
	if not tr.shake():
		return
	_particles(tr.position - Vector2(0, 20), "leaves")
	var item := "wood"
	var n := 1
	GameState.add_item(item, n)
	var drop := Sprite2D.new()
	drop.texture = Art.item_icon(item)
	drop.position = tr.position - Vector2(0, 22)
	drop.z_index = 40
	main.world.add_child(drop)
	var land: Vector2 = tr.position + Vector2(randf_range(-10, 10), 6)
	var tw := drop.create_tween()
	tw.tween_property(drop, "position:x", land.x, 0.4)
	tw.parallel().tween_property(drop, "position:y", land.y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(drop, "position", main.player.position - Vector2(0, 10), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(drop.queue_free)
	Fx.float_text(main.world, tr.position - Vector2(0, 26), "+1 %s" % item)
	Sfx.play("pickup", 0.1)
	_notify(item)

func _notify(item: String) -> void:
	for q in GameState.active_quests():
		if q["item"] == item:
			var have := GameState.count(item)
			if have == int(q["count"]) and main.hud and main.hud.has_method("toast"):
				main.hud.toast("Got all %d %s! Go see %s" % [int(q["count"]), Art.item_name(item), Art.NPC_NAMES.get(q["npc"], q["npc"])], Color("#3aa35b"))
			if Hotline.in_call:
				Hotline.inform("Player now has %d/%d %s for the quest '%s'." % [mini(have, int(q["count"])), int(q["count"]), item, q["title"]])
			break

func _player_squash() -> void:
	var spr = main.player.get("sprite")
	if spr == null:
		return
	spr.scale = Vector2(1.15, 0.85)
	spr.create_tween().tween_property(spr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# ---------------- particles ----------------
func _particles(pos: Vector2, kind: String) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.z_index = 45
	match kind:
		"dust":
			p.amount = 14
			p.lifetime = 0.55
			p.direction = Vector2(0, -1)
			p.spread = 80
			p.initial_velocity_min = 15
			p.initial_velocity_max = 35
			p.gravity = Vector2(0, 50)
			p.damping_min = 30
			p.damping_max = 50
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.5
			p.color = Color("#d9b48a")
		"water":
			p.amount = 18
			p.lifetime = 0.6
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(5, 1)
			p.direction = Vector2(0, -1)
			p.spread = 50
			p.initial_velocity_min = 20
			p.initial_velocity_max = 45
			p.gravity = Vector2(0, 220)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.8
			p.color = Color("#7cc8ff")
		"leaves":
			p.amount = 22
			p.lifetime = 1.2
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			p.emission_rect_extents = Vector2(10, 6)
			p.direction = Vector2(0, -1)
			p.spread = 120
			p.initial_velocity_min = 15
			p.initial_velocity_max = 40
			p.gravity = Vector2(0, 45)
			p.angular_velocity_min = -300
			p.angular_velocity_max = 300
			p.scale_amount_min = 1.5
			p.scale_amount_max = 2.5
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			g.colors = PackedColorArray([Color("#7fc35a"), Color("#5aa646"), Color("#a6d86e")])
			p.color_initial_ramp = g
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	main.world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---------------- hint (AC-clean pill) ----------------
func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", UiKit.box(UiKit.CREAM, 22, true, 3, Color("#8fcf6a")))
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.offset_bottom = -28
	hint_panel.visible = false
	holder.add_child(hint_panel)
	hint_label = UiKit.label("", 22)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(hint_label)
	hint_panel.resized.connect(func(): hint_panel.pivot_offset = hint_panel.size * 0.5)

# ---------------- automated check (HV_FARM_TEST=1, use with HV_FARM_FAST=1) ----------------
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/hv_farm_%s.png" % n)
	print("[farm-shot] /tmp/hv_farm_%s.png" % n)

func _face(tile: Vector2i, dir: String) -> void:
	var off := {"up": Vector2(0, 14), "down": Vector2(0, -10), "left": Vector2(14, 4), "right": Vector2(-14, 4)}
	main.player.position = tile_center(tile) + off[dir]
	main.player.facing = dir
	main.player.velocity = Vector2.ZERO

func _test_tour() -> void:
	await get_tree().create_timer(1.0).timeout
	var row := [Vector2i(33, 25), Vector2i(34, 25), Vector2i(35, 25), Vector2i(36, 25)]
	_face(row[0], "up")
	await get_tree().create_timer(0.8).timeout
	await _shot("1_plot")
	for t in row:
		_face(t, "up")
		await get_tree().process_frame
		print("[farm] ", _compute_action().get("text"), " -> ", act())
	await get_tree().create_timer(0.3).timeout
	await _shot("2_tilled")
	for i in row.size():
		_face(row[i], "up")
		await get_tree().process_frame
		if i == 2:
			seed_sel = "seed_wheat"
		print("[farm] ", _compute_action().get("text"), " -> ", act())
		await get_tree().process_frame
		print("[farm] ", _compute_action().get("text"), " -> ", act())
	await get_tree().create_timer(0.15).timeout
	await _shot("3_watered")
	await get_tree().create_timer(stage_time * 1.6).timeout
	await _shot("4_growing")
	await get_tree().create_timer(stage_time * 2.0).timeout
	await _shot("5_ready")
	for t in row:
		_face(t, "up")
		await get_tree().process_frame
		print("[farm] ", _compute_action().get("text"), " -> ", act())
	await get_tree().create_timer(0.2).timeout
	await _shot("6_harvest")
	# tree outside the plot
	var tt := Vector2i(33, 31)
	_face(tt, "down")
	await get_tree().process_frame
	print("[farm] tree: ", _compute_action().get("text"), " -> ", act())
	await get_tree().create_timer(0.6).timeout
	await _shot("7_sapling")
	await get_tree().create_timer(tree_time + 1.0).timeout
	print("[farm] grown: ", _compute_action().get("text"), " -> ", act())
	await get_tree().create_timer(0.15).timeout
	await _shot("8_shake")
	print("[farm] inventory ", GameState.inventory)
	get_tree().quit()
