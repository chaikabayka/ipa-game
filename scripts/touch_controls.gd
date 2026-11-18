extends Control

# Виртуальное управление для сенсорных экранов.
# Левая нижняя зона — плавающий джойстик движения.
# Правая зона — прицел и стрельба (удержание).
# Круг в правом нижнем углу — рывок.

var game

var dir := Vector2.ZERO            # направление движения от джойстика
var firing := false                # правый палец держит стрельбу
var aim_screen := Vector2.ZERO     # палец прицела в координатах вьюпорта

var joy_id := -1
var joy_base := Vector2.ZERO
var joy_stick := Vector2.ZERO

var fire_id := -1

const JOY_R := 110.0
const JOY_DEAD := 10.0
const DASH_R := 62.0

var font: Font = ThemeDB.fallback_font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available()
	set_process_input(visible)


func _process(_delta: float) -> void:
	if visible and game != null and game.is_playing():
		queue_redraw()


func release_all() -> void:
	joy_id = -1
	fire_id = -1
	dir = Vector2.ZERO
	joy_stick = Vector2.ZERO
	firing = false


func dash_center() -> Vector2:
	return Vector2(size.x - DASH_R - 46.0, size.y - DASH_R - 46.0)


func _input(event: InputEvent) -> void:
	if game == null or not visible:
		return
	if not game.is_playing():
		if joy_id != -1 or fire_id != -1:
			release_all()
		return

	var press := event as InputEventScreenTouch
	if press != null:
		var pos: Vector2 = press.position
		if press.pressed:
			if pos.distance_to(dash_center()) <= DASH_R + 14.0:
				game.player.try_dash()
			elif pos.x < size.x * 0.42 and pos.y > size.y * 0.30:
				joy_id = press.index
				joy_base = pos
				joy_stick = Vector2.ZERO
				dir = Vector2.ZERO
			else:
				fire_id = press.index
				firing = true
				aim_screen = pos
		else:
			if press.index == joy_id:
				joy_id = -1
				joy_stick = Vector2.ZERO
				dir = Vector2.ZERO
			elif press.index == fire_id:
				fire_id = -1
				firing = false
		return

	var drag := event as InputEventScreenDrag
	if drag != null:
		if drag.index == joy_id:
			var off := drag.position - joy_base
			var dist := off.length()
			if dist <= JOY_DEAD:
				joy_stick = Vector2.ZERO
				dir = Vector2.ZERO
			else:
				var clamped := minf(dist, JOY_R)
				joy_stick = off.normalized() * clamped
				dir = joy_stick / JOY_R
		elif drag.index == fire_id:
			aim_screen = drag.position


func _draw() -> void:
	if not game.is_playing():
		return
	var ghost := Color(0.55, 0.85, 0.95, 0.14)
	var line := Color(0.6, 0.88, 1.0, 0.42)

	# джойстик
	if joy_id != -1:
		draw_circle(joy_base, JOY_R, ghost)
		draw_arc(joy_base, JOY_R, 0.0, TAU, 40, line, 2.0, true)
		if joy_stick.length() > 1.0:
			draw_circle(joy_base + joy_stick, 34.0, Color(0.65, 0.9, 1.0, 0.45))
			draw_arc(joy_base + joy_stick, 34.0, 0.0, TAU, 32, line, 2.0, true)
	else:
		# подсказка, где лежит джойстик
		var c := Vector2(140.0, size.y - 130.0)
		draw_circle(c, JOY_R * 0.7, Color(0.55, 0.85, 0.95, 0.06))
		draw_arc(c, JOY_R * 0.7, 0.0, TAU, 40, Color(0.6, 0.88, 1.0, 0.16), 1.5, true)

	# кнопка рывка
	var dc := dash_center()
	var ready_now: bool = game.player != null and game.player.dash_cd <= 0.0
	var dash_fill := Color(0.55, 0.9, 1.0, 0.22 if ready_now else 0.08)
	draw_circle(dc, DASH_R, dash_fill)
	draw_arc(dc, DASH_R, 0.0, TAU, 40, Color(0.6, 0.88, 1.0, 0.45 if ready_now else 0.18), 2.0, true)
	# молния внутри
	var s := 20.0
	var bolt := PackedVector2Array([
		Vector2(-s * 0.25, -s), Vector2(s * 0.35, -s), Vector2(0.0, -s * 0.2),
		Vector2(s * 0.45, -s * 0.2), Vector2(-s * 0.35, s),
		Vector2(-s * 0.1, s * 0.15), Vector2(-s * 0.55, s * 0.15),
	])
	var bolt_col := Color(0.85, 0.95, 1.0, 0.8 if ready_now else 0.3)
	draw_colored_polygon(bolt, bolt_col)
