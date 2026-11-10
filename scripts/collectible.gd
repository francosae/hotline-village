extends Area2D

signal picked(item: String, pos: Vector2)

const RESPAWN := 20.0
var item := "egg"
var sprite: Sprite2D
var shadow: Sprite2D
var active := true
var _t := 0.0

func _ready() -> void:
	_t = randf() * TAU
	var sh := CircleShape2D.new()
	sh.radius = 7.0
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	sprite = Sprite2D.new()
	sprite.texture = Art.item_icon(item)
	sprite.self_modulate = Art.item_modulate(item)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	_t += delta
	if active:
		sprite.position.y = sin(_t * 3.0) * 1.5
		var shine := 0.15 + 0.15 * maxf(0.0, sin(_t * 2.0))
		sprite.modulate = Color(1 + shine, 1 + shine, 1 + shine)

func _on_body(b: Node) -> void:
	if b.name == "Player":
		pickup()

func pickup() -> void:
	if not active:
		return
	active = false
	set_deferred("monitoring", false)
	picked.emit(item, global_position)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.08)
	t.tween_property(sprite, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(RESPAWN).timeout
	active = true
	monitoring = true
	sprite.scale = Vector2.ZERO
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
