extends CharacterBody2D

const SPEED := 70.0
const ACCEL := 600.0
const FRICTION := 700.0

var facing := "down"
var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.player_frames()
	sprite.offset = Vector2(0, -14)
	add_child(sprite)
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 4.0
	col.shape = sh
	col.position = Vector2(0, -3)
	add_child(col)
	sprite.play("idle_down")

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir.normalized() * SPEED, ACCEL * delta)
		if absf(dir.x) > absf(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	var anim := ("walk_" if velocity.length() > 8.0 else "idle_") + facing
	if sprite.animation != anim:
		sprite.play(anim)
