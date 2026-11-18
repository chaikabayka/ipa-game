extends Node2D

const BulletScript := preload("res://scripts/bullet.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const CoinScript := preload("res://scripts/coin.gd")
const PlayerScript := preload("res://scripts/player.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

enum State { TITLE, PLAYING, SHOP, DEAD }

const VIEW := Vector2(1280.0, 720.0)
const ARENA := Rect2(26.0, 102.0, 1228.0, 592.0)

const UPGRADES := [
	{"id": "damage", "short": "Ядра", "name": "Тяжёлые ядра", "desc": "+1 урон за выстрел", "base": 12, "step": 9, "max": 12},
	{"id": "rate", "short": "Темп", "name": "Скорострельность", "desc": "+13% к темпу стрельбы", "base": 14, "step": 10, "max": 10},
	{"id": "multishot", "short": "Залп", "name": "Мультивыстрел", "desc": "+1 ядро в залпе", "base": 34, "step": 28, "max": 4},
	{"id": "pierce", "short": "Пробитие", "name": "Пробитие", "desc": "Ядра пробивают +1 врага", "base": 26, "step": 22, "max": 3},
	{"id": "speed", "short": "Ветер", "name": "Попутный ветер", "desc": "+10% к скорости хода", "base": 12, "step": 10, "max": 8},
	{"id": "hp", "short": "Корпус", "name": "Крепкий корпус", "desc": "+2 к макс. HP и лечение", "base": 16, "step": 13, "max": 8},
	{"id": "magnet", "short": "Магнит", "name": "Магнит", "desc": "+85 к радиусу сбора монет", "base": 10, "step": 8, "max": 6},
	{"id": "dash", "short": "Рывок", "name": "Рывок", "desc": "-14% перезарядка рывка", "base": 14, "step": 12, "max": 6},
]

var state := State.TITLE
var time := 0.0
var shake := 0.0
var input_lock := 0.0

var player
var camera: Camera2D
var fx
var hud
var touch

var enemies: Array = []
var bullets: Array = []
var ebullets: Array = []
var coin_nodes: Array = []
var stars: Array = []

var wave := 0
var score := 0
var coins := 0
var kills := 0

var spawn_queue: Array = []
var spawn_timer := 0.0
var wave_clear_timer := -1.0
var wave_active := false
var dead_timer := 0.0

var levels := {}
var stats := {}


func _ready() -> void:
	randomize()
	_make_stars()

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)

	touch = TouchScript.new()
	touch.game = self
	layer.add_child(touch)

	fx = FxScript.new()
	fx.game = self
	fx.z_index = 60
	add_child(fx)

	camera = Camera2D.new()
	camera.position = VIEW * 0.5
	camera.enabled = true
	add_child(camera)
	camera.make_current()

	reset_levels()
	recalc()
	hud.show_title()


func is_playing() -> bool:
	return state == State.PLAYING


func is_title() -> bool:
	return state == State.TITLE


func _process(delta: float) -> void:
	time += delta
	shake = maxf(0.0, shake - delta * 30.0)
	if camera != null:
		var amp := shake
		camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	if input_lock > 0.0:
		input_lock = maxf(0.0, input_lock - delta)

	if state == State.PLAYING:
		_update_spawning(delta)
		_collide()
		_cleanup()
		_check_wave_clear(delta)
	elif state == State.DEAD:
		if dead_timer > 0.0:
			dead_timer -= delta
			if dead_timer <= 0.0:
				hud.show_gameover()

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and state == State.DEAD:
			start_game()
		elif event.keycode == KEY_ESCAPE and state == State.SHOP:
			close_shop()


# ---------------------------------------------------------------- flow

func start_game() -> void:
	_clear_world()
	reset_levels()
	recalc()

	player = PlayerScript.new()
	player.game = self
	player.position = ARENA.get_center() + Vector2(0.0, 130.0)
	player.z_index = 10
	add_child(player)

	wave = 0
	score = 0
	coins = 0
	kills = 0
	spawn_queue.clear()
	wave_clear_timer = -1.0
	wave_active = false
	dead_timer = 0.0
	input_lock = 0.2
	state = State.PLAYING
	hud.hide_panels()
	fx.burst(player.position, Color("#8fd7ff"), 20, 260.0, 0.6)
	fx.ring(player.position, Color("#8fd7ff"), 10.0, 90.0, 0.5)
	start_wave(1)


func _clear_world() -> void:
	for n in enemies:
		if is_instance_valid(n):
			n.queue_free()
	for n in bullets:
		if is_instance_valid(n):
			n.queue_free()
	for n in ebullets:
		if is_instance_valid(n):
			n.queue_free()
	for n in coin_nodes:
		if is_instance_valid(n):
			n.queue_free()
	enemies.clear()
	bullets.clear()
	ebullets.clear()
	coin_nodes.clear()
	if is_instance_valid(player):
		player.queue_free()
	player = null


func start_wave(n: int) -> void:
	wave = n
	spawn_queue.clear()
	wave_clear_timer = -1.0
	wave_active = true
	spawn_timer = 0.4

	var count := mini(4 + n * 2, 30)
	if n % 5 == 0:
		spawn_queue.append("boss")
		count = maxi(4, count - 4)
	for i in count:
		spawn_queue.append(_pick_kind(n))

	if n % 5 == 0:
		hud.banner("КАПИТАН НА БОРТУ", "береги корпус", 2.2)
	else:
		hud.banner("ВОЛНА %d" % n, "врагов: %d" % spawn_queue.size(), 1.8)


func _pick_kind(n: int) -> String:
	var pool: Array = ["crab", "crab"]
	if n >= 2:
		pool.append_array(["wisp", "wisp"])
	if n >= 3:
		pool.append("gunner")
	if n >= 4:
		pool.append("brute")
	if n >= 7:
		pool.append_array(["wisp", "gunner"])
	return String(pool.pick_random())


func _update_spawning(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = maxf(0.22, 0.44 - float(wave) * 0.012)
		var kind: String = spawn_queue.pop_front()
		_spawn_enemy(kind)


func _spawn_enemy(kind: String) -> void:
	var e = EnemyScript.new()
	e.game = self
	e.setup(kind, wave)
	e.position = _spawn_point(kind)
	e.z_index = 6
	add_child(e)
	enemies.append(e)
	fx.ring(e.position, Color(0.6, 0.9, 1.0, 0.9), 6.0, e.radius * 2.6, 0.5)


func _spawn_point(kind: String) -> Vector2:
	var margin := 110.0
	if kind == "boss":
		margin = 190.0
	var p := Vector2.ZERO
	for i in 14:
		p = Vector2(
			randf_range(ARENA.position.x + margin, ARENA.end.x - margin),
			randf_range(ARENA.position.y + margin, ARENA.end.y - margin)
		)
		if not is_instance_valid(player):
			break
		if p.distance_to(player.position) > 300.0:
			break
	return p


func _check_wave_clear(delta: float) -> void:
	if wave_active and spawn_queue.is_empty() and enemies.is_empty():
		wave_active = false
		wave_clear_timer = 1.1
		var bonus := 3 + wave
		add_coins(bonus)
		hud.banner("ПАЛУБА ЧИСТА", "+%d монет" % bonus, 1.8)
		fx.ring(ARENA.get_center(), Color("#ffd75e"), 40.0, 420.0, 0.8)
	if wave_clear_timer > 0.0:
		wave_clear_timer -= delta
		if wave_clear_timer <= 0.0:
			wave_clear_timer = -1.0
			open_shop()


func open_shop() -> void:
	state = State.SHOP
	hud.show_shop()


func close_shop() -> void:
	hud.hide_shop()
	input_lock = 0.3
	start_wave(wave + 1)


func on_player_dead() -> void:
	state = State.DEAD
	dead_timer = 0.9
	fx.burst(player.position, Color("#ff6a4a"), 40, 380.0, 0.9)
	fx.ring(player.position, Color("#ff6a4a"), 20.0, 260.0, 0.7)
	shake = 18.0


# ---------------------------------------------------------------- economy

func add_coins(n: int) -> void:
	coins += n


func upgrade_cost(def: Dictionary, lvl: int) -> int:
	return int(def["base"]) + int(def["step"]) * lvl


func buy(id: String) -> void:
	var def := _upgrade_def(id)
	if def.is_empty():
		return
	var lvl: int = int(levels.get(id, 0))
	if lvl >= int(def["max"]):
		return
	var cost := upgrade_cost(def, lvl)
	if coins < cost:
		hud.coin_warn = 0.7
		return
	coins -= cost
	levels[id] = lvl + 1
	recalc()
	hud.coin_warn = 0.0


func _upgrade_def(id: String) -> Dictionary:
	for d in UPGRADES:
		if String(d["id"]) == id:
			return d
	return {}


func reset_levels() -> void:
	levels = {
		"damage": 0, "rate": 0, "multishot": 0, "pierce": 0,
		"speed": 0, "hp": 0, "magnet": 0, "dash": 0,
	}


func recalc() -> void:
	var old_max := int(stats.get("max_hp", 6))
	stats = {
		"max_hp": 6 + 2 * int(levels["hp"]),
		"damage": 2 + int(levels["damage"]),
		"fire_interval": 0.32 / (1.0 + 0.13 * float(levels["rate"])),
		"shots": 1 + int(levels["multishot"]),
		"pierce": int(levels["pierce"]),
		"speed": 300.0 * (1.0 + 0.10 * float(levels["speed"])),
		"magnet": 100.0 + 85.0 * float(levels["magnet"]),
		"dash_cd": 1.7 * pow(0.86, float(levels["dash"])),
	}
	if is_instance_valid(player):
		var new_max := int(stats["max_hp"])
		player.max_hp = new_max
		player.hp = mini(player.max_hp, player.hp + maxi(0, new_max - old_max))


# ---------------------------------------------------------------- combat

func player_shoot(pos: Vector2, dir: Vector2, dmg: int, pierce: int) -> void:
	var b = BulletScript.new()
	b.game = self
	b.position = pos
	b.velocity = dir * 980.0
	b.damage = dmg
	b.pierce = pierce
	b.radius = 6.0
	b.color = Color("#ffe07a")
	b.friendly = true
	b.z_index = 20
	add_child(b)
	bullets.append(b)


func enemy_shoot(pos: Vector2, dir: Vector2, speed := 300.0) -> void:
	var b = BulletScript.new()
	b.game = self
	b.position = pos
	b.velocity = dir.normalized() * speed
	b.damage = 1
	b.radius = 7.0
	b.color = Color("#ff5a3c")
	b.friendly = false
	b.life = 5.0
	b.z_index = 20
	add_child(b)
	ebullets.append(b)


func kill_enemy(e) -> void:
	e.alive = false
	score += e.score
	kills += 1
	shake = maxf(shake, 6.0)
	fx.burst(e.position, e.color, 18, 240.0, 0.55)
	fx.ring(e.position, e.color, e.radius * 0.5, e.radius * 2.6, 0.35)
	var drops := 1
	if e.kind == "brute":
		drops = 3
	elif e.kind == "boss":
		drops = 10
		shake = 22.0
		fx.ring(e.position, Color("#ffd75e"), 20.0, 500.0, 0.9)
	for i in drops:
		_drop_coin(e.position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0)))


func _drop_coin(pos: Vector2) -> void:
	var c = CoinScript.new()
	c.game = self
	c.position = pos
	c.z_index = 4
	c.vel = Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
	add_child(c)
	coin_nodes.append(c)


func _collide() -> void:
	# ядра игрока -> враги
	var i := bullets.size() - 1
	while i >= 0:
		var b = bullets[i]
		if not is_instance_valid(b):
			bullets.remove_at(i)
			i -= 1
			continue
		var gone := false
		for e in enemies:
			if not is_instance_valid(e) or not e.alive or e.spawning:
				continue
			var eid: int = e.get_instance_id()
			if b.has_hit.has(eid):
				continue
			if b.position.distance_to(e.position) < b.radius + e.radius:
				b.has_hit.append(eid)
				e.hit(b.damage, b.velocity.normalized())
				fx.burst(b.position, b.color, 5, 130.0, 0.22)
				if b.pierce <= 0:
					gone = true
					break
				b.pierce -= 1
		if gone:
			b.queue_free()
			bullets.remove_at(i)
		i -= 1

	# враги -> игрок (контакт)
	if is_instance_valid(player) and player.alive:
		for e in enemies:
			if not is_instance_valid(e) or not e.alive or e.spawning:
				continue
			if player.position.distance_to(e.position) < player.radius + e.radius * 0.85:
				player.take_damage(e.contact_damage, e.position)
				var push: Vector2 = (player.position - e.position).normalized()
				player.position += push * 6.0

	# ядра врагов -> игрок
	var j := ebullets.size() - 1
	while j >= 0:
		var b = ebullets[j]
		if not is_instance_valid(b):
			ebullets.remove_at(j)
			j -= 1
			continue
		if is_instance_valid(player) and player.alive and b.position.distance_to(player.position) < b.radius + player.radius * 0.8:
			player.take_damage(b.damage, b.position)
			b.queue_free()
			ebullets.remove_at(j)
		j -= 1

	# монеты
	if is_instance_valid(player) and player.alive:
		for c in coin_nodes:
			if not is_instance_valid(c):
				continue
			if player.position.distance_to(c.position) < 28.0:
				coins += c.value
				fx.burst(c.position, Color("#ffd75e"), 8, 150.0, 0.32)
				fx.text(c.position, "+%d" % c.value, Color("#ffd75e"))
				c.queue_free()


func _cleanup() -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
		elif not e.alive:
			e.queue_free()
			enemies.remove_at(i)
		i -= 1
	_prune(bullets)
	_prune(ebullets)
	_prune(coin_nodes)


func _prune(arr: Array) -> void:
	var i := arr.size() - 1
	while i >= 0:
		if not is_instance_valid(arr[i]):
			arr.remove_at(i)
		i -= 1


# ---------------------------------------------------------------- visuals

func _make_stars() -> void:
	stars.clear()
	for i in 110:
		stars.append({
			"p": Vector2(randf() * VIEW.x, randf() * VIEW.y),
			"a": randf_range(0.12, 0.55),
			"s": randf_range(0.7, 2.0),
			"f": randf_range(0.4, 2.0),
		})


func _draw() -> void:
	# ночное море
	var top := Color("#050b13")
	var bot := Color("#0a2331")
	var bands := 26
	for i in bands:
		var k := float(i) / float(bands)
		draw_rect(Rect2(0.0, VIEW.y * k, VIEW.x, VIEW.y / float(bands) + 1.0), top.lerp(bot, k))

	# луна — только мягкое свечение за верхней панелью
	var moon := Vector2(1112.0, 58.0)
	for i in 14:
		var k := float(i) / 14.0
		draw_circle(moon, 18.0 + k * 110.0, Color(0.62, 0.8, 0.9, 0.028 * (1.0 - k)))

	# звёзды
	for s in stars:
		var p: Vector2 = s["p"]
		var a: float = float(s["a"]) * (0.55 + 0.45 * sin(time * float(s["f"]) + p.x * 0.05))
		draw_circle(p, float(s["s"]), Color(0.78, 0.9, 1.0, a))

	# волны
	for row in 15:
		var base_y := 36.0 + float(row) * 48.0
		var pts := PackedVector2Array()
		for c in 40:
			var x := float(c) * 34.0
			var y := base_y + sin(x * 0.006 + time * (0.45 + float(row) * 0.02) + float(row)) * (5.0 + float(row) * 0.3)
			pts.append(Vector2(x, y))
		draw_polyline(pts, Color(0.32, 0.63, 0.71, 0.05), 1.5, true)

	_draw_deck()


func _draw_deck() -> void:
	# рама
	draw_rect(ARENA.grow(12.0), Color("#070d11"))
	draw_rect(ARENA.grow(8.0), Color("#18262c"))

	# доски палубы
	var planks := 16
	var pw := ARENA.size.x / float(planks)
	for i in planks:
		var x := ARENA.position.x + float(i) * pw
		var seedv := sin(float(i) * 12.9898) * 43758.5453
		var g: float = 0.050 * (seedv - floorf(seedv))
		var c := Color(0.165 + g, 0.113 + g * 0.78, 0.079 + g * 0.5)
		draw_rect(Rect2(x, ARENA.position.y, pw - 1.5, ARENA.size.y), c)
		draw_line(Vector2(x + 0.5, ARENA.position.y), Vector2(x + 0.5, ARENA.end.y), Color(0.045, 0.030, 0.022, 0.9), 1.5)
		for j in 3:
			var gy := ARENA.position.y + 70.0 + float(j) * 175.0 + sin(float(i) * 2.0 + float(j)) * 26.0
			draw_line(Vector2(x + 9.0, gy), Vector2(x + pw - 12.0, gy + 3.0), Color(0.09, 0.06, 0.04, 0.35), 1.0)
		draw_circle(Vector2(x + pw * 0.5, ARENA.position.y + 15.0), 2.2, Color("#3a3a44"))
		draw_circle(Vector2(x + pw * 0.5, ARENA.end.y - 15.0), 2.2, Color("#3a3a44"))

	# поперечные балки
	for b in [0.335, 0.665]:
		var by := ARENA.position.y + ARENA.size.y * float(b)
		draw_rect(Rect2(ARENA.position.x, by - 11.0, ARENA.size.x, 22.0), Color(0.105, 0.073, 0.049))
		draw_line(Vector2(ARENA.position.x, by - 11.0), Vector2(ARENA.end.x, by - 11.0), Color(0.22, 0.16, 0.11), 1.5)
		draw_line(Vector2(ARENA.position.x, by + 11.0), Vector2(ARENA.end.x, by + 11.0), Color(0.04, 0.028, 0.02), 2.0)
		for n in 13:
			var bx := ARENA.position.x + 46.0 + float(n) * (ARENA.size.x - 92.0) / 12.0
			draw_circle(Vector2(bx, by), 2.4, Color(0.30, 0.30, 0.34))
			draw_circle(Vector2(bx, by - 0.6), 1.2, Color(0.55, 0.56, 0.60))

	# роза ветров
	var ctr := ARENA.get_center()
	draw_circle(ctr, 156.0, Color(0.85, 0.70, 0.42, 0.028))
	draw_arc(ctr, 156.0, 0.0, TAU, 54, Color(0.85, 0.70, 0.42, 0.10), 2.0, true)
	draw_arc(ctr, 104.0, 0.0, TAU, 46, Color(0.85, 0.70, 0.42, 0.075), 1.5, true)
	draw_arc(ctr, 30.0, 0.0, TAU, 24, Color(0.85, 0.70, 0.42, 0.09), 1.5, true)
	for i in 8:
		var ang := TAU * float(i) / 8.0 - PI * 0.5
		var ln := 156.0 if i % 2 == 0 else 96.0
		draw_line(ctr, ctr + Vector2.from_angle(ang) * ln, Color(0.88, 0.73, 0.45, 0.085), 2.0)
		if i % 2 == 0:
			var tip := ctr + Vector2.from_angle(ang) * ln
			var side := Vector2.from_angle(ang + PI * 0.5) * 7.0
			draw_colored_polygon(PackedVector2Array([tip, ctr + Vector2.from_angle(ang) * (ln - 26.0) + side, ctr + Vector2.from_angle(ang) * (ln - 26.0) - side]), Color(0.88, 0.73, 0.45, 0.10))

	# мягкое затемнение по краям палубы
	for i in 9:
		var a := 0.055 * (1.0 - float(i) / 9.0)
		draw_rect(ARENA.grow(-float(i) * 7.0), Color(0.0, 0.0, 0.0, a), false, 14.0)

	# факельный свет по углам
	var corners := [
		ARENA.position + Vector2(46.0, 46.0),
		Vector2(ARENA.end.x - 46.0, ARENA.position.y + 46.0),
		ARENA.end - Vector2(46.0, 46.0),
		Vector2(ARENA.position.x + 46.0, ARENA.end.y - 46.0),
	]
	for c in corners:
		for i in 7:
			draw_circle(c, 22.0 + float(i) * 16.0, Color(1.0, 0.66, 0.28, 0.014))
		draw_circle(c, 4.0, Color(1.0, 0.78, 0.4, 0.5 + 0.2 * sin(time * 7.0 + c.x)))

	# золотой рант
	draw_rect(ARENA, Color("#c9a253"), false, 2.5)
	draw_rect(ARENA.grow(-4.0), Color(0.79, 0.64, 0.33, 0.3), false, 1.0)
	for c in [ARENA.position, Vector2(ARENA.end.x, ARENA.position.y), ARENA.end, Vector2(ARENA.position.x, ARENA.end.y)]:
		draw_circle(c, 8.0, Color("#0d1519"))
		draw_circle(c, 7.0, Color("#c9a253"), false, 2.0)
		draw_circle(c, 3.0, Color("#6b5220"))

	# виньетка
	for i in 22:
		var a := 0.042 * (1.0 - float(i) / 22.0)
		var inset := float(i) * 4.0
		draw_rect(Rect2(inset, inset, VIEW.x - inset * 2.0, VIEW.y - inset * 2.0), Color(0.0, 0.0, 0.0, a), false, 9.0)
