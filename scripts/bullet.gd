extends Node2D

var game
var velocity := Vector2.ZERO
var damage := 1
var pierce := 0
var radius := 6.0
var color := Color("#ffe07a")
var friendly := true
var life := 3.0
var has_hit: Array = []
var trail: Array = []


func _process(delta: float) -> void:
	if game != null and not game.is_playing():
		queue_redraw()
		return
	if game != null:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
	position += velocity * delta
	trail.append(position)
	if trail.size() > 7:
		trail.pop_front()
	if game != null:
		var a: Rect2 = game.ARENA
		if not a.grow(40.0).has_point(position):
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var col := color
	if friendly:
		if trail.size() >= 2:
			var pts := PackedVector2Array()
			for p in trail:
				pts.append(p - global_position)
			pts.append(Vector2.ZERO)
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.22), radius * 1.9, true)
		draw_circle(Vector2.ZERO, radius * 2.3, Color(col.r, col.g, col.b, 0.13))
		draw_circle(Vector2.ZERO, radius, col)
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 1.0, 1.0, 0.95))
	else:
		if trail.size() >= 2:
			var pts2 := PackedVector2Array()
			for p in trail:
				pts2.append(p - global_position)
			pts2.append(Vector2.ZERO)
			draw_polyline(pts2, Color(col.r, col.g, col.b, 0.18), radius * 1.5, true)
		draw_circle(Vector2.ZERO, radius * 2.0, Color(col.r, col.g, col.b, 0.15))
		draw_circle(Vector2.ZERO, radius + 1.5, Color(0.12, 0.03, 0.03, 0.9))
		draw_circle(Vector2.ZERO, radius, col)
		draw_circle(Vector2(-1.0, -1.0), radius * 0.42, Color(1.0, 0.88, 0.7, 0.95))
