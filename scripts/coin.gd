extends Node2D

var game
var value := 1
var vel := Vector2.ZERO
var t := 0.0
var life := 45.0


func _ready() -> void:
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	if game != null and not game.is_playing():
		queue_redraw()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	if game != null and is_instance_valid(game.player):
		var p = game.player
		var d: float = global_position.distance_to(p.global_position)
		var magnet := float(game.stats.get("magnet", 100.0))
		if d < magnet and d > 1.0:
			var pull: Vector2 = (p.global_position - position) / d
			var force: float = lerpf(300.0, 1500.0, 1.0 - clampf(d / magnet, 0.0, 1.0))
			vel = vel.lerp(pull * force, 1.0 - exp(-9.0 * delta))
		else:
			vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-4.5 * delta))
	else:
		vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-4.5 * delta))

	position += vel * delta
	if game != null:
		var a: Rect2 = game.ARENA
		position.x = clampf(position.x, a.position.x + 12.0, a.end.x - 12.0)
		position.y = clampf(position.y, a.position.y + 12.0, a.end.y - 12.0)
	queue_redraw()


func _draw() -> void:
	var bob := sin(t * 3.4) * 2.0
	draw_set_transform(Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var spin := absf(cos(t * 5.0))
	var sx := maxf(0.22, spin)

	draw_circle(Vector2(0.0, bob), 12.0, Color(1.0, 0.78, 0.25, 0.10))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, 8.5, Color("#b8821a"))
	draw_circle(Vector2.ZERO, 7.0, Color("#f0c04a"))
	draw_circle(Vector2.ZERO, 4.6, Color("#ffe58a"))
	if spin > 0.45:
		draw_circle(Vector2(-2.2, -2.6), 2.0, Color(1.0, 1.0, 0.92, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
