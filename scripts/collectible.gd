extends Area2D

signal picked(item: String, pos: Vector2)

const RESPAWN := 20.0
var item := "egg"
var sprite: Sprite2D
var shadow: Sprite2D
var active := true
var twinkle: CPUParticles2D
static var _sh: Texture2D

static func _shadow_tex() -> Texture2D:
	if _sh == null:
		var img := Image.create(12, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 12:
				var d := Vector2((x - 5.5) / 6.0, (y - 1.5) / 2.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d < 1.0 else 0.0))
		_sh = ImageTexture.create_from_image(img)
	return _sh
var _t := 0.0

func _ready() -> void:
	_t = randf() * TAU
	var sh := CircleShape2D.new()
	sh.radius = 7.0
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	shadow = Sprite2D.new()
	shadow.texture = _shadow_tex()
	shadow.modulate = Color(0.2, 0.3, 0.1, 0.35)
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = Art.item_world(item)
	sprite.self_modulate = Art.item_world_modulate(item)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	twinkle = CPUParticles2D.new()
	twinkle.amount = 2
	twinkle.lifetime = 1.4
	twinkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	twinkle.emission_rect_extents = Vector2(6, 5)
	twinkle.position = Vector2(0, -9)
	twinkle.gravity = Vector2(0, -6)
	twinkle.initial_velocity_min = 0
	twinkle.initial_velocity_max = 2
	twinkle.color = Color("#fffbd0")
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.5, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	twinkle.color_ramp = g
	add_child(twinkle)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	if active:
		sprite.position.y = roundf(sin(_t * 3.0) * 1.5 - 0.5)
		var shine := 0.25 * pow(maxf(0.0, sin(_t * 1.3)), 8.0)
		sprite.modulate = Color(1 + shine, 1 + shine, 1 + shine)

func _on_body(b: Node) -> void:
	if b.name == "Player":
		pickup()

func pickup() -> void:
	if not active:
		return
	active = false
	set_deferred("monitoring", false)
	twinkle.emitting = false
	shadow.visible = false
	picked.emit(item, global_position)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.08)
	t.tween_property(sprite, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(RESPAWN).timeout
	active = true
	monitoring = true
	twinkle.emitting = true
	shadow.visible = true
	sprite.scale = Vector2.ZERO
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
