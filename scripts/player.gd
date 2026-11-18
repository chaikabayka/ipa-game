extends Node2D

var game
var radius := 18.0
var hp := 6
var max_hp := 6
var aim := Vector2.RIGHT
var vel := Vector2.ZERO
var shoot_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.RIGHT
var dash_ghost := 0.0
var invuln := 0.0
var muzzle := 0.0
var walk_t := 0.0
var hit_flash := 0.0
var alive := true
var space_prev := false


func _ready() -> void:
	max_hp = int(game.stats["max_hp"])
	hp = max_hp


func move_input() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if game.touch != null and game.touch.visible:
		d += game.touch.dir
	return d


func _process(delta: float) -> void:
	if not game.is_playing():
		walk_t += delta * 0.5
		_update_render(delta)
		return

	var dir := move_input()
	if dir.length() > 0.01:
		dir = dir.normalized()
		walk_t += delta * 7.0
	else:
		walk_t += delta * 1.2

	if game.touch != null and game.touch.visible:
		if game.touch.firing:
			var xform: Transform2D = game.get_viewport().get_canvas_transform()
			var to_finger: Vector2 = xform.affine_inverse() * game.touch.aim_screen - global_position
			if to_finger.length() > 4.0:
				aim = to_finger.normalized()
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			aim = to_mouse.normalized()

	# рывок
	var space_now := Input.is_key_pressed(KEY_SPACE)
	if space_now and not space_prev:
		try_dash()
	space_prev = space_now

	var speed := float(game.stats["speed"])
	if dash_time > 0.0:
		dash_time -= delta
		position += dash_dir * 1020.0 * delta
		dash_ghost -= delta
		if dash_ghost <= 0.0:
			dash_ghost = 0.028
			game.fx.ghost(global_position, aim.angle())
		vel = dash_dir * speed
	else:
		vel = vel.lerp(dir * speed, 1.0 - exp(-11.0 * delta))
		position += vel * delta

	position.x = clampf(position.x, game.ARENA.position.x + radius, game.ARENA.end.x - radius)
	position.y = clampf(position.y, game.ARENA.position.y + radius, game.ARENA.end.y - radius)

	# стрельба
	shoot_cd = maxf(0.0, shoot_cd - delta)
	var trigger := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if game.touch != null and game.touch.visible:
		# на сенсорном экране эмулированную ЛКМ игнорируем — стреляет правый палец
		trigger = game.touch.firing
	if trigger and shoot_cd <= 0.0 and game.input_lock <= 0.0:
		_shoot()

	_update_render(delta)


func _update_render(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	muzzle = maxf(0.0, muzzle - delta * 7.5)
	hit_flash = maxf(0.0, hit_flash - delta * 3.0)
	if invuln > 0.0 and dash_time <= 0.0:
		modulate.a = 0.5 if fmod(invuln * 16.0, 2.0) < 1.0 else 0.95
	else:
		modulate.a = 1.0
	queue_redraw()


func try_dash() -> void:
	if not game.is_playing() or dash_cd > 0.0 or dash_time > 0.0:
		return
	var move_dir := move_input()
	dash_dir = move_dir if move_dir != Vector2.ZERO else aim
	dash_time = 0.16
	dash_cd = float(game.stats["dash_cd"])
	invuln = maxf(invuln, 0.24)
	game.fx.ring(global_position, Color(0.55, 0.9, 1.0), 12.0, 54.0, 0.32)
	game.shake = maxf(game.shake, 4.0)


func _shoot() -> void:
	shoot_cd = float(game.stats["fire_interval"])
	muzzle = 1.0
	var n := int(game.stats["shots"])
	var arc := 0.15 * float(n - 1)
	var base := aim.angle()
	for i in range(n):
		var t := 0.0 if n <= 1 else float(i) / float(n - 1)
		var a := base - arc * 0.5 + arc * t
		var d := Vector2.from_angle(a)
		game.player_shoot(global_position + d * (radius + 15.0), d, int(game.stats["damage"]), int(game.stats["pierce"]))
	vel -= aim * 22.0
	game.shake = maxf(game.shake, 2.4)


func take_damage(amount: int, from: Vector2) -> void:
	if invuln > 0.0 or dash_time > 0.0 or not alive:
		return
	hp -= amount
	invuln = 0.95
	hit_flash = 1.0
	game.shake = maxf(game.shake, 13.0)
	var push := (global_position - from)
	if push.length() < 1.0:
		push = Vector2.RIGHT
	vel += push.normalized() * 300.0
	game.fx.burst(global_position, Color("#ff6a4a"), 15, 240.0, 0.45)
	if hp <= 0:
		hp = 0
		alive = false
		visible = false
		game.on_player_dead()


func _draw() -> void:
	# тень
	draw_set_transform(Vector2(0.0, 13.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 22.0, Color(0.0, 0.0, 0.0, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# индикатор рывка
	var cd_max := float(game.stats.get("dash_cd", 1.7))
	if dash_cd > 0.0 and cd_max > 0.0:
		var f := 1.0 - dash_cd / cd_max
		draw_arc(Vector2.ZERO, 31.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color(0.5, 0.85, 1.0, 0.5), 2.5, true)
	elif dash_cd <= 0.0:
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 32, Color(0.5, 0.85, 1.0, 0.12), 2.0, true)

	var bob := sin(walk_t) * 1.4
	var a := aim.angle()
	var hurt := hit_flash * 0.75
	var skin := Color("#e3b07a").lerp(Color("#ff8a7a"), hurt)
	var shirt := Color("#f4ecdb").lerp(Color("#ff8a7a"), hurt)
	var vest := Color("#4a3222").lerp(Color("#ff8a7a"), hurt * 0.6)
	var hat_c := Color("#1e1e27").lerp(Color("#ff8a7a"), hurt * 0.5)
	var gold := Color("#c9a253")

	draw_set_transform(Vector2(0.0, bob), a, Vector2(1.15, 1.15))

	# ноги
	draw_line(Vector2(-9.0, 5.0), Vector2(-21.0, 9.0), Color("#2b303b"), 7.0)
	draw_line(Vector2(-9.0, -5.0), Vector2(-21.0, -9.0), Color("#2b303b"), 7.0)

	# торс
	var torso := PackedVector2Array([
		Vector2(7.0, 0.0), Vector2(4.0, 14.0), Vector2(-8.0, 14.0),
		Vector2(-17.0, 8.0), Vector2(-17.0, -8.0), Vector2(-8.0, -14.0),
		Vector2(4.0, -14.0),
	])
	draw_colored_polygon(torso, shirt)
	var outline := torso.duplicate()
	outline.append(torso[0])
	draw_polyline(outline, Color(0.07, 0.05, 0.04, 0.65), 2.2, true)

	# плечи
	draw_circle(Vector2(1.0, -11.5), 4.6, shirt)
	draw_circle(Vector2(1.0, 11.5), 4.6, shirt)

	# жилет — только спинка, грудь остаётся светлой
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, 0.0), Vector2(-8.0, -12.5), Vector2(-16.0, -6.5),
		Vector2(-16.0, 6.5), Vector2(-8.0, 12.5),
	]), vest)
	draw_line(Vector2(-3.0, 0.0), Vector2(-8.0, -12.5), Color(0.32, 0.22, 0.14), 1.4)
	draw_line(Vector2(-3.0, 0.0), Vector2(-8.0, 12.5), Color(0.32, 0.22, 0.14), 1.4)

	# блик на рубахе
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.0, -3.0), Vector2(2.0, -9.5), Vector2(-4.0, -8.0), Vector2(-3.0, -2.0),
	]), Color(1.0, 1.0, 1.0, 0.4))

	# пояс
	draw_line(Vector2(-8.0, -12.0), Vector2(-8.0, 12.0), Color("#7a5a24"), 4.5)
	draw_circle(Vector2(-8.0, 0.0), 2.6, gold)

	# голова
	draw_circle(Vector2(9.5, 0.0), 7.4, skin)
	draw_circle(Vector2(12.2, 2.0), 3.2, Color(0.62, 0.36, 0.2, 0.28))
	# глаза
	draw_circle(Vector2(13.4, -2.9), 1.5, Color("#20161a"))
	draw_circle(Vector2(13.4, 2.9), 1.5, Color("#20161a"))
	draw_circle(Vector2(14.0, -3.3), 0.6, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2(14.0, 2.5), 0.6, Color(1.0, 1.0, 1.0, 0.9))

	# треуголка (сдвинута назад, лицо открыто)
	var hat := PackedVector2Array([
		Vector2(10.0, -8.5), Vector2(2.0, -9.5), Vector2(-7.0, -6.5),
		Vector2(-9.5, 0.0), Vector2(-7.0, 6.5), Vector2(2.0, 9.5), Vector2(10.0, 8.5),
	])
	draw_colored_polygon(hat, hat_c)
	var hat_line := hat.duplicate()
	hat_line.append(hat[0])
	draw_polyline(hat_line, gold, 1.8, true)
	draw_line(Vector2(9.0, -8.0), Vector2(9.0, 8.0), Color(0.95, 0.85, 0.55, 0.6), 1.4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6.0, -5.5), Vector2(0.0, -6.8), Vector2(-5.0, -3.2), Vector2(1.0, -1.2),
	]), Color(0.62, 0.68, 0.82, 0.16))

	# перо
	draw_line(Vector2(2.0, -9.0), Vector2(-10.0, -18.0), Color("#a8321f"), 4.0)
	draw_line(Vector2(2.0, -9.0), Vector2(-9.0, -17.0), Color("#e06a4a"), 1.6)

	# рукава и руки поверх шляпы, чтобы силуэт читался
	draw_circle(Vector2(1.0, -13.0), 5.0, shirt)
	draw_circle(Vector2(1.0, 13.0), 5.0, shirt)
	draw_circle(Vector2(7.5, -13.5), 3.4, skin)
	draw_circle(Vector2(7.5, 13.5), 3.4, skin)

	# сабля
	var hand := Vector2(7.5, 13.5)
	var tip := Vector2(34.0, 19.0)
	draw_line(hand, tip, Color("#b9c4d2"), 4.0)
	draw_line(hand + Vector2(1.0, 0.6), tip, Color(1.0, 1.0, 1.0, 0.95), 1.4)
	draw_circle(hand, 3.6, gold)
	draw_line(hand + Vector2(-3.0, 0.0), hand + Vector2(3.0, 0.0), gold, 2.2)

	# вспышка выстрела
	if muzzle > 0.0:
		var m := muzzle
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(22.0 * m, 0.0),
			tip + Vector2(3.0, 8.0 * m),
			tip + Vector2(-6.0, 0.0),
			tip + Vector2(3.0, -8.0 * m),
		]), Color(1.0, 0.86, 0.45, m))
		draw_circle(tip, 7.5 * m, Color(1.0, 0.95, 0.7, m * 0.8))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
