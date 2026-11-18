extends Node2D

var game
var kind := "crab"
var hp := 3
var max_hp := 3
var speed := 90.0
var radius := 16.0
var contact_damage := 1
var score := 10
var color := Color("#e2603c")
var alive := true
var spawning := false
var spawn_t := 0.0
var t := 0.0
var vel := Vector2.ZERO
var flash := 0.0
var shoot_t := 1.0
var strafe := 1.0
var phase := 0.0


func setup(k: String, wave: int) -> void:
	kind = k
	var mult := 1.0 + 0.10 * float(wave - 1)
	match kind:
		"crab":
			hp = 3
			speed = 95.0 + float(wave) * 3.0
			radius = 16.0
			contact_damage = 1
			score = 10
			color = Color("#e2603c")
		"wisp":
			hp = 2
			speed = 150.0 + float(wave) * 5.0
			radius = 13.0
			contact_damage = 1
			score = 12
			color = Color("#8d6bff")
		"gunner":
			hp = 5
			speed = 74.0
			radius = 17.0
			contact_damage = 1
			score = 18
			color = Color("#d9c14a")
		"brute":
			hp = 14
			speed = 58.0
			radius = 27.0
			contact_damage = 2
			score = 32
			color = Color("#5fae72")
		"boss":
			hp = 70 + wave * 12
			speed = 50.0
			radius = 46.0
			contact_damage = 2
			score = 150
			color = Color("#c93a52")
	hp = int(round(float(hp) * mult))
	max_hp = hp
	spawning = true
	spawn_t = 0.55
	shoot_t = 1.0 + randf() * 0.8
	strafe = 1.0 if randf() < 0.5 else -1.0
	t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 6.0)

	if not alive:
		queue_redraw()
		return
	if not game.is_playing():
		queue_redraw()
		return

	if spawning:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawning = false
			game.fx.burst(position, color.lightened(0.35), 10, 200.0, 0.4)
		queue_redraw()
		return

	if not is_instance_valid(game.player):
		queue_redraw()
		return

	var to_player: Vector2 = game.player.position - position
	var dist := maxf(1.0, to_player.length())
	var dir := to_player / dist
	var desired := Vector2.ZERO

	match kind:
		"crab":
			desired = dir
		"wisp":
			desired = dir.rotated(sin(t * 4.2) * 0.95)
		"brute":
			desired = dir
		"gunner":
			if dist > 330.0:
				desired = dir
			elif dist < 230.0:
				desired = -dir
			else:
				desired = dir.rotated(PI * 0.5) * strafe * 0.8
		"boss":
			if dist > 300.0:
				desired = dir
			elif dist < 220.0:
				desired = -dir
			else:
				desired = dir.rotated(PI * 0.5) * strafe * 0.5

	# расталкивание
	for other in game.enemies:
		if other == self or not is_instance_valid(other) or not other.alive or other.spawning:
			continue
		var d: Vector2 = position - other.position
		var dl := d.length()
		if dl > 0.01 and dl < radius + other.radius:
			desired += (d / dl) * 1.4

	if desired.length() > 1.0:
		desired = desired.normalized()

	var target_vel := desired * speed
	vel = vel.lerp(target_vel, 1.0 - exp(-6.0 * delta))
	position += vel * delta

	position.x = clampf(position.x, game.ARENA.position.x + radius, game.ARENA.end.x - radius)
	position.y = clampf(position.y, game.ARENA.position.y + radius, game.ARENA.end.y - radius)

	# стрельба
	if kind == "gunner" or kind == "boss":
		shoot_t -= delta
		if shoot_t <= 0.0 and dist < 780.0:
			if kind == "gunner":
				shoot_t = 1.9
				game.enemy_shoot(position + dir * (radius + 14.0), dir, 315.0)
				game.fx.burst(position + dir * (radius + 14.0), Color("#ffb066"), 6, 140.0, 0.2)
			else:
				shoot_t = 2.0
				phase += 1.0
				var shots := 12
				for i in shots:
					var ang := TAU * float(i) / float(shots) + phase * 0.35
					game.enemy_shoot(position, Vector2.from_angle(ang), 240.0)
				game.shake = maxf(game.shake, 5.0)

	queue_redraw()


func hit(dmg: int, dir: Vector2) -> void:
	if not alive or spawning:
		return
	hp -= dmg
	flash = 1.0
	vel += dir * 80.0
	game.fx.text(position + Vector2(randf_range(-6.0, 6.0), -radius - 6.0), str(dmg), Color("#ffe28a"))
	if hp <= 0:
		hp = 0
		alive = false
		game.kill_enemy(self)


func _eyes(center: Vector2, spread: float) -> void:
	var look := Vector2.RIGHT
	if is_instance_valid(game.player):
		look = (game.player.global_position - global_position).normalized()
	var ey := center + Vector2(0.0, -spread * 0.4)
	for side in [-1.0, 1.0]:
		var ep := ey + Vector2(spread * 0.45 * side, 0.0)
		draw_circle(ep, spread * 0.34, Color("#f7f4ee"))
		draw_circle(ep + look * spread * 0.13, spread * 0.17, Color("#171a20"))


func _draw() -> void:
	if spawning:
		var k := 1.0 - clampf(spawn_t / 0.55, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (0.3 + k * 0.9), Color(0.55, 0.85, 1.0, 0.10 + 0.10 * k))
		draw_arc(Vector2.ZERO, radius * (2.1 - k * 1.2), 0.0, TAU, 28, Color(0.6, 0.9, 1.0, 0.55), 2.0, true)
		draw_arc(Vector2.ZERO, radius * (0.6 + k), t * 3.0, t * 3.0 + 2.4, 14, Color(1.0, 1.0, 1.0, 0.6), 2.5, true)
		return

	var col := color.lerp(Color(1.0, 1.0, 1.0), minf(1.0, flash))

	draw_set_transform(Vector2(0.0, radius * 0.58), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	match kind:
		"crab":
			var bob := sin(t * 7.0) * 1.5
			for i in 3:
				var side := -1.0 if i % 2 == 0 else 1.0
				var yy := (float(i) - 1.0) * 7.0
				draw_line(
					Vector2(side * radius * 0.55, yy),
					Vector2(side * (radius + 8.0), yy + sin(t * 9.0 + float(i)) * 3.0),
					col.darkened(0.45), 2.5
				)
			draw_circle(Vector2(0.0, bob), radius + 2.5, col.darkened(0.5))
			draw_circle(Vector2(0.0, bob), radius, col)
			draw_circle(Vector2(-radius * 0.95, bob - radius * 0.55), radius * 0.42, col.darkened(0.12))
			draw_circle(Vector2(-radius * 0.95, bob + radius * 0.55), radius * 0.42, col.darkened(0.12))
			_eyes(Vector2(0.0, bob), radius * 0.68)

		"wisp":
			var bob := sin(t * 5.0) * 4.0
			for i in 3:
				draw_circle(
					Vector2(0.0, bob + radius * 0.55 + float(i) * radius * 0.5),
					radius * (0.7 - float(i) * 0.18),
					Color(col.r, col.g, col.b, 0.18 - float(i) * 0.05)
				)
			draw_colored_polygon(PackedVector2Array([
				Vector2(radius * 0.9, bob),
				Vector2(0.0, bob + radius * 1.4),
				Vector2(-radius * 0.9, bob),
				Vector2(0.0, bob - radius * 0.95),
			]), col)
			draw_circle(Vector2(0.0, bob), radius * 0.72, col.lightened(0.08))
			_eyes(Vector2(0.0, bob), radius * 0.62)

		"gunner":
			var to_p := Vector2.RIGHT
			if is_instance_valid(game.player):
				to_p = (game.player.global_position - global_position).normalized()
			var ang := to_p.angle()
			draw_line(Vector2.ZERO, to_p * (radius + 17.0), Color("#2c3138"), 8.0)
			draw_line(Vector2.ZERO, to_p * (radius + 17.0), Color("#5d6672"), 4.0)
			draw_circle(Vector2.ZERO, radius + 1.5, col.darkened(0.55))
			draw_circle(Vector2.ZERO, radius, col)
			draw_arc(Vector2.ZERO, radius * 0.66, ang - 0.95, ang + 0.95, 16, col.darkened(0.32), 3.0, true)
			_eyes(Vector2.ZERO, radius * 0.6)

		"brute":
			var bob := sin(t * 4.0) * 1.2
			draw_circle(Vector2(0.0, bob), radius + 3.0, col.darkened(0.55))
			draw_circle(Vector2(0.0, bob), radius, col)
			for i in 4:
				var ang2 := TAU * float(i) / 4.0 + 0.4
				draw_arc(Vector2(0.0, bob), radius * 0.86, ang2, ang2 + 1.0, 12, col.darkened(0.32), 3.0, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(radius * 0.34, bob + radius * 0.34),
				Vector2(radius * 0.62, bob + radius * 0.98),
				Vector2(radius * 0.08, bob + radius * 0.56),
			]), Color("#e8e2d0"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-radius * 0.34, bob + radius * 0.34),
				Vector2(-radius * 0.62, bob + radius * 0.98),
				Vector2(-radius * 0.08, bob + radius * 0.56),
			]), Color("#e8e2d0"))
			_eyes(Vector2(0.0, bob), radius * 0.54)

		"boss":
			var bob := sin(t * 2.5) * 2.0
			var spikes := PackedVector2Array()
			var n := 14
			for i in n:
				var ang3 := TAU * float(i) / float(n)
				var rr := radius + (11.0 if i % 2 == 0 else 0.0)
				spikes.append(Vector2(cos(ang3), sin(ang3)) * rr + Vector2(0.0, bob))
			draw_colored_polygon(spikes, col.darkened(0.6))
			draw_circle(Vector2(0.0, bob), radius, col)
			draw_circle(Vector2(0.0, bob), radius * 0.74, col.darkened(0.22))
			_eyes(Vector2(0.0, bob), radius * 0.52)
			draw_arc(Vector2(0.0, bob), radius + 16.0, t * 1.4, t * 1.4 + 2.1, 26, Color(1.0, 0.75, 0.3, 0.5), 3.0, true)

	if hp < max_hp or kind == "boss":
		var w := radius * 2.2
		var y := -radius - 20.0
		draw_rect(Rect2(-w * 0.5, y, w, 5.0), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(-w * 0.5, y, w * clampf(float(hp) / float(max_hp), 0.0, 1.0), 5.0), Color("#7fe08a"))
