extends Node2D

var game
var parts: Array = []
var rings: Array = []
var texts: Array = []
var ghosts: Array = []
var font: Font = ThemeDB.fallback_font


func burst(pos: Vector2, color: Color, count := 10, speed := 200.0, life := 0.5) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(speed * 0.25, speed)
		parts.append({
			"p": pos,
			"v": Vector2(cos(ang), sin(ang)) * spd,
			"life": life * randf_range(0.55, 1.25),
			"max": life,
			"c": color,
			"r": randf_range(1.8, 4.4),
		})


func ring(pos: Vector2, color: Color, from_r := 8.0, to_r := 70.0, life := 0.4) -> void:
	rings.append({"p": pos, "c": color, "a": from_r, "b": to_r, "t": 0.0, "life": life})


func text(pos: Vector2, txt: String, color: Color) -> void:
	texts.append({"p": pos, "s": txt, "c": color, "t": 0.0, "life": 0.7})


func ghost(pos: Vector2, ang: float) -> void:
	ghosts.append({"p": pos, "a": ang, "t": 0.0, "life": 0.28})


func _process(delta: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			parts.remove_at(i)
		else:
			p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
			p["v"] = Vector2(p["v"]) * (1.0 - 2.6 * delta)
		i -= 1

	var j := rings.size() - 1
	while j >= 0:
		var r: Dictionary = rings[j]
		r["t"] = float(r["t"]) + delta
		if float(r["t"]) >= float(r["life"]):
			rings.remove_at(j)
		j -= 1

	var k := texts.size() - 1
	while k >= 0:
		var tx: Dictionary = texts[k]
		tx["t"] = float(tx["t"]) + delta
		tx["p"] = Vector2(tx["p"]) + Vector2(0.0, -34.0) * delta
		if float(tx["t"]) >= float(tx["life"]):
			texts.remove_at(k)
		k -= 1

	var g := ghosts.size() - 1
	while g >= 0:
		var gh: Dictionary = ghosts[g]
		gh["t"] = float(gh["t"]) + delta
		if float(gh["t"]) >= float(gh["life"]):
			ghosts.remove_at(g)
		g -= 1

	queue_redraw()


func _draw() -> void:
	for gh in ghosts:
		var f: float = 1.0 - float(gh["t"]) / float(gh["life"])
		var pos: Vector2 = gh["p"]
		var ang: float = gh["a"]
		draw_set_transform(pos, ang, Vector2.ONE)
		draw_circle(Vector2.ZERO, 16.0, Color(0.55, 0.85, 1.0, 0.16 * f))
		draw_circle(Vector2(2.0, 0.0), 9.0, Color(0.75, 0.93, 1.0, 0.22 * f))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for r in rings:
		var t: float = float(r["t"]) / float(r["life"])
		var rad: float = lerpf(float(r["a"]), float(r["b"]), t)
		var c: Color = r["c"]
		var rp: Vector2 = r["p"]
		draw_arc(rp, rad, 0.0, TAU, 40, Color(c.r, c.g, c.b, (1.0 - t) * 0.75), 3.0 * (1.0 - t) + 0.6, true)

	for p in parts:
		var f2: float = clampf(float(p["life"]) / maxf(0.001, float(p["max"])), 0.0, 1.0)
		var c2: Color = p["c"]
		var pp: Vector2 = p["p"]
		draw_circle(pp, float(p["r"]) * (0.4 + f2 * 0.8), Color(c2.r, c2.g, c2.b, f2))

	for tx in texts:
		var f3: float = 1.0 - float(tx["t"]) / float(tx["life"])
		var c3: Color = tx["c"]
		var sz := 15
		var tp: Vector2 = tx["p"]
		draw_string(font, tp + Vector2(-20.0, 0.0), String(tx["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, sz, Color(0.0, 0.0, 0.0, f3 * 0.5))
		draw_string(font, tp + Vector2(-20.0, -1.0), String(tx["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, sz, Color(c3.r, c3.g, c3.b, f3))
