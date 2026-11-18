extends Control

var game
var font: Font = ThemeDB.fallback_font

const GOLD := Color("#e8be5a")
const INK := Color("#dff0f4")
const DIM := Color("#8fb0ba")

var banner_title := ""
var banner_sub := ""
var banner_t := 0.0
var banner_dur := 1.0
var banner_color := Color("#ffe6a3")

var shop: Control
var shop_coins: Label
var shop_rows := {}
var title_box: Control
var over_box: Control
var over_stats: Label
var coin_warn := 0.0

var bar_back: StyleBoxFlat
var bar_fill: StyleBoxFlat
var chip_style: StyleBoxFlat


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_styles()
	_build_title()
	_build_shop()
	_build_over()


func _make_styles() -> void:
	bar_back = StyleBoxFlat.new()
	bar_back.bg_color = Color(0.035, 0.07, 0.09, 0.88)
	bar_back.set_corner_radius_all(8)
	bar_back.border_color = Color(0.38, 0.58, 0.63, 0.55)
	bar_back.set_border_width_all(2)

	bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color("#e05a3c")
	bar_fill.set_corner_radius_all(6)

	chip_style = StyleBoxFlat.new()
	chip_style.bg_color = Color(0.05, 0.11, 0.14, 0.82)
	chip_style.set_corner_radius_all(7)
	chip_style.border_color = Color(0.45, 0.72, 0.78, 0.35)
	chip_style.set_border_width_all(1)


# ---------------------------------------------------------------- HUD draw

func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
		position = Vector2.ZERO
	if banner_t > 0.0:
		banner_t = maxf(0.0, banner_t - delta)
	if coin_warn > 0.0:
		coin_warn = maxf(0.0, coin_warn - delta)
	if shop_coins != null:
		if coin_warn > 0.0:
			shop_coins.add_theme_color_override("font_color", Color("#ff6f5c"))
		else:
			shop_coins.add_theme_color_override("font_color", Color("#ffe9a8"))
	if game != null and not game.is_title():
		queue_redraw()


func _draw() -> void:
	if game == null or game.is_title():
		return

	var w: float = size.x
	var h: float = size.y
	var p = game.player

	# красная виньетка при низком HP
	if is_instance_valid(p) and p.max_hp > 0:
		var ratio: float = float(p.hp) / float(p.max_hp)
		if ratio < 0.42:
			var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
			var a: float = (0.42 - ratio) * 0.55 * pulse
			for i in 11:
				var ins := float(i) * 13.0
				draw_rect(Rect2(ins, ins, w - ins * 2.0, h - ins * 2.0), Color(0.85, 0.06, 0.06, a * 0.09), false, 15.0)

	# полоса здоровья
	var bar := Rect2(34.0, 30.0, 300.0, 26.0)
	bar_back.draw(get_canvas_item(), bar)
	var filled := 0.0
	var hp_now := 0
	var hp_max := 1
	if is_instance_valid(p):
		hp_now = int(p.hp)
		hp_max = maxi(1, int(p.max_hp))
		filled = clampf(float(hp_now) / float(hp_max), 0.0, 1.0)
	if filled > 0.0:
		var fw: float = maxf(16.0, bar.size.x * filled - 3.0)
		bar_fill.draw(get_canvas_item(), Rect2(bar.position + Vector2(1.5, 1.5), Vector2(fw, bar.size.y - 3.0)))
	draw_string(font, Vector2(bar.position.x, bar.position.y + 18.0),
		"%d / %d" % [hp_now, hp_max], HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 15, Color("#ffe9d2"))

	# монеты
	var pill := Rect2(w - 258.0, 30.0, 224.0, 26.0)
	chip_style.draw(get_canvas_item(), pill)
	var cx := pill.position.x + 20.0
	var cy := pill.position.y + 13.0
	draw_circle(Vector2(cx, cy), 9.5, Color("#b8821a"))
	draw_circle(Vector2(cx, cy), 7.8, Color("#f0c04a"))
	draw_circle(Vector2(cx - 2.4, cy - 2.6), 2.2, Color(1.0, 1.0, 1.0, 0.85))
	draw_string(font, Vector2(cx + 17.0, cy + 6.0), str(game.coins), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffe9a8"))
	draw_string(font, Vector2(cx + 90.0, cy + 5.5), "очки %d" % game.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.8, 0.85, 0.9))

	# волна
	var remain: int = game.enemies.size() + game.spawn_queue.size()
	draw_string(font, Vector2(w * 0.5 - 200.0, 42.0), "ВОЛНА %d" % game.wave,
		HORIZONTAL_ALIGNMENT_CENTER, 400.0, 22, GOLD)
	draw_string(font, Vector2(w * 0.5 - 200.0, 62.0), "врагов: %d" % remain,
		HORIZONTAL_ALIGNMENT_CENTER, 400.0, 13, DIM)

	# купленные способности
	var x := 30.0
	var y := h - 46.0
	for def in game.UPGRADES:
		var id := String(def["id"])
		var lvl: int = int(game.levels.get(id, 0))
		if lvl <= 0:
			continue
		var label := "%s %d" % [String(def["short"]), lvl]
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var rect := Rect2(x, y, tw + 20.0, 24.0)
		chip_style.draw(get_canvas_item(), rect)
		draw_string(font, Vector2(x + 10.0, y + 16.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#cfe8ee"))
		x += rect.size.x + 8.0

	# рывок
	var dash_ready := true
	if is_instance_valid(p):
		dash_ready = p.dash_cd <= 0.0
	draw_string(font, Vector2(w - 330.0, h - 42.0),
		"ПРОБЕЛ · рывок" if dash_ready else "рывок перезаряжается",
		HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 12,
		Color(0.55, 0.82, 0.92, 0.85) if dash_ready else Color(0.5, 0.58, 0.62, 0.7))

	# баннер волны
	if banner_t > 0.0:
		var k: float = 1.0 - banner_t / banner_dur
		var a: float = clampf(minf(k * 6.0, (1.0 - k) * 5.0), 0.0, 1.0)
		var by: float = h * 0.34
		draw_string_outline(font, Vector2(w * 0.5 - 420.0, by), banner_title,
			HORIZONTAL_ALIGNMENT_CENTER, 840.0, 52, 9, Color(0.0, 0.0, 0.0, a * 0.85))
		draw_string(font, Vector2(w * 0.5 - 420.0, by), banner_title,
			HORIZONTAL_ALIGNMENT_CENTER, 840.0, 52, Color(banner_color.r, banner_color.g, banner_color.b, a))
		if banner_sub != "":
			draw_string_outline(font, Vector2(w * 0.5 - 420.0, by + 38.0), banner_sub,
				HORIZONTAL_ALIGNMENT_CENTER, 840.0, 19, 6, Color(0.0, 0.0, 0.0, a * 0.7))
			draw_string(font, Vector2(w * 0.5 - 420.0, by + 38.0), banner_sub,
				HORIZONTAL_ALIGNMENT_CENTER, 840.0, 19, Color(0.9, 0.97, 1.0, a * 0.9))


# ---------------------------------------------------------------- helpers

func banner(title: String, sub := "", dur := 1.8) -> void:
	banner_title = title
	banner_sub = sub
	banner_dur = maxf(0.4, dur)
	banner_t = banner_dur


func _panel_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.043, 0.086, 0.113, 0.97)
	sb.border_color = Color(0.55, 0.46, 0.26, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	return sb


func _btn_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(9)
	return sb


func _style_btn(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _btn_sb(Color(0.10, 0.22, 0.27, 1.0), Color(0.28, 0.55, 0.62, 0.8)))
	b.add_theme_stylebox_override("hover", _btn_sb(Color(0.15, 0.33, 0.39, 1.0), Color(0.45, 0.82, 0.9, 1.0)))
	b.add_theme_stylebox_override("pressed", _btn_sb(Color(0.08, 0.17, 0.21, 1.0), Color(0.35, 0.7, 0.78, 0.9)))
	b.add_theme_stylebox_override("disabled", _btn_sb(Color(0.06, 0.11, 0.14, 1.0), Color(0.16, 0.24, 0.28, 0.8)))
	b.add_theme_color_override("font_color", Color("#dff2f6"))
	b.add_theme_color_override("font_hover_color", Color("#ffffff"))
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.52, 0.56))
	b.add_theme_font_size_override("font_size", 16)


func _label(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _dim_panel(parent: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.024, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	return cc


# ---------------------------------------------------------------- title

func _build_title() -> void:
	title_box = Control.new()
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.mouse_filter = Control.MOUSE_FILTER_STOP
	title_box.visible = false
	add_child(title_box)

	var cc := _dim_panel(title_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	panel.add_theme_stylebox_override("panel", _panel_sb())
	cc.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t := _label("ПИРАТСКАЯ АРЕНА", 54, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var sub := _label("стреляй по абордажникам. уворачивайся от ядер. собирай монеты.", 17, Color("#bfd9df"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(HSeparator.new())

	var is_touch := DisplayServer.is_touchscreen_available()
	var ctl_text := "WASD — ходить\nМЫШЬ — целиться     ЛКМ — стрелять\nПРОБЕЛ — рывок (он спасает жизнь)"
	if is_touch:
		ctl_text = "ЛЕВЫЙ ПАЛЕЦ (низ) — джойстик хода\nПРАВЫЙ ПАЛЕЦ — целиться и стрелять\nКРУГ С МОЛНИЕЙ — рывок (он спасает жизнь)"
	var ctl := _label(ctl_text, 16, Color("#9dc0c9"))
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ctl)

	var tip := _label("Между волнами открывается мастерская — там тратятся монеты.", 14, Color("#7d9aa4"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)

	var go := Button.new()
	go.text = "ОТДАТЬ ШВАРТОВЫ"
	go.custom_minimum_size = Vector2(0, 54)
	_style_btn(go)
	go.add_theme_font_size_override("font_size", 20)
	go.pressed.connect(_on_start)
	v.add_child(go)


func _on_start() -> void:
	if game != null:
		game.start_game()


func show_title() -> void:
	title_box.visible = true


func hide_panels() -> void:
	title_box.visible = false
	shop.visible = false
	over_box.visible = false


# ---------------------------------------------------------------- shop

func _build_shop() -> void:
	shop = Control.new()
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop.mouse_filter = Control.MOUSE_FILTER_STOP
	shop.visible = false
	add_child(shop)

	var cc := _dim_panel(shop)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940, 0)
	panel.add_theme_stylebox_override("panel", _panel_sb())
	cc.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(_label("МАСТЕРСКАЯ", 28, GOLD))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	shop_coins = _label("Монеты: 0", 20, Color("#ffe9a8"))
	head.add_child(shop_coins)

	var hint := _label("Каждый уровень стоит дороже. Выбирай, чем воевать дальше.", 14, DIM)
	v.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	for def in game.UPGRADES:
		grid.add_child(_make_row(def))

	v.add_child(HSeparator.new())

	var go := Button.new()
	go.text = "В БОЙ"
	go.custom_minimum_size = Vector2(0, 50)
	_style_btn(go)
	go.add_theme_font_size_override("font_size", 19)
	go.pressed.connect(_on_continue)
	v.add_child(go)


func _make_row(def: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.10, 0.13, 0.95)
	sb.border_color = Color(0.25, 0.44, 0.50, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(9)
	item.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	item.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(_label(String(def["name"]), 18, Color("#eaf6f8")))

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	var lvl := _label("ур. 0", 14, DIM)
	top.add_child(lvl)

	var ds := _label(String(def["desc"]), 13, Color("#9db9c2"))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(360, 0)
	v.add_child(ds)

	var b := Button.new()
	b.text = "Купить"
	b.custom_minimum_size = Vector2(0, 30)
	_style_btn(b)
	b.pressed.connect(_on_buy.bind(String(def["id"])))
	v.add_child(b)

	shop_rows[String(def["id"])] = {"lvl": lvl, "btn": b}
	return item


func _on_buy(id: String) -> void:
	if game != null:
		game.buy(id)
	refresh_shop()


func _on_continue() -> void:
	if game != null:
		game.close_shop()


func refresh_shop() -> void:
	if game == null:
		return
	shop_coins.text = "Монеты: %d" % game.coins
	for def in game.UPGRADES:
		var id := String(def["id"])
		var ref = shop_rows.get(id, null)
		if ref == null:
			continue
		var lvl: int = int(game.levels.get(id, 0))
		var lmax := int(def["max"])
		ref["lvl"].text = "ур. %d / %d" % [lvl, lmax]
		if lvl >= lmax:
			ref["btn"].text = "МАКСИМУМ"
			ref["btn"].disabled = true
		else:
			var cost: int = game.upgrade_cost(def, lvl)
			ref["btn"].text = "Купить · %d" % cost
			ref["btn"].disabled = game.coins < cost


func show_shop() -> void:
	refresh_shop()
	shop.visible = true
	shop.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(shop, "modulate:a", 1.0, 0.18)


func hide_shop() -> void:
	shop.visible = false


# ---------------------------------------------------------------- game over

func _build_over() -> void:
	over_box = Control.new()
	over_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_box.mouse_filter = Control.MOUSE_FILTER_STOP
	over_box.visible = false
	add_child(over_box)

	var cc := _dim_panel(over_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", _panel_sb())
	cc.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t := _label("ТЫ УШЁЛ НА ДНО", 42, Color("#ff8a72"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	over_stats = _label("", 18, Color("#c6dbe1"))
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_stats)

	var go := Button.new()
	go.text = "ЕЩЁ РАЗ"
	go.custom_minimum_size = Vector2(0, 52)
	_style_btn(go)
	go.add_theme_font_size_override("font_size", 19)
	go.pressed.connect(_on_start)
	v.add_child(go)

	var hint := _label("или нажми R", 13, DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func show_gameover() -> void:
	if game == null:
		return
	over_stats.text = "волна %d      очки %d      убито %d" % [game.wave, game.score, game.kills]
	over_box.visible = true
	over_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(over_box, "modulate:a", 1.0, 0.25)
