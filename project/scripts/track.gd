extends Node2D

const TRACK_WIDTH := GameConstants.TRACK_WIDTH
const WALL_THICKNESS := 35.0

@export var track_index: int = 0

# Track layouts — selected by track_index in _ready()
var centerline: Array[Vector2] = []
var checkpoint_indices: Array = []
var boost_positions: Array[Vector2] = []
var missile_positions: Array[Vector2] = []

# Elevation zone config per track: [start, end, color]
var _elevation_zones: Array = []

var _outer_points: PackedVector2Array = PackedVector2Array()
var _inner_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	# Read track selection from main menu (if scene was loaded from menu)
	var menu_script := load("res://scripts/main_menu.gd")
	if menu_script and "selected_track" in menu_script:
		track_index = menu_script.selected_track
	_load_track_layout(track_index)
	if centerline.is_empty():
		push_error("[Track] Centerline empty after loading track %d — falling back to Track 1" % track_index)
		track_index = 0
		_load_track_1()
	if centerline.is_empty():
		push_error("[Track] Track 1 centerline also empty — cannot build track")
		return
	_compute_edges()
	_build_background()
	_build_road_quads()
	_build_center_dashes()
	_build_elevation_zones()
	_build_decorations()
	_build_walls()
	_build_checkpoints()
	_build_items()
	_build_start_line()
	print("[Track] Track %d built — %d centerline points, %d checkpoints" % [track_index, centerline.size(), checkpoint_indices.size()])

func _load_track_layout(idx: int) -> void:
	match idx:
		1:
			_load_track_2()
		2:
			_load_track_3()
		_:
			_load_track_1()

func _load_track_1() -> void:
	# Track 1: Grand Circuit — wide sweeping turns for drift flow
	centerline.assign([
		# Start/finish straight (heading right)
		Vector2(1000, 1000),      # 0 — finish line
		Vector2(1500, 980),       # 1
		Vector2(2000, 960),       # 2
		Vector2(2500, 950),       # 3
		Vector2(3000, 960),       # 4
		Vector2(3500, 1000),      # 5
		# Turn 1 — wide sweeping right (banked hairpin)
		Vector2(3900, 1100),      # 6
		Vector2(4200, 1300),      # 7
		Vector2(4400, 1550),      # 8
		Vector2(4450, 1850),      # 9
		Vector2(4350, 2150),      # 10
		Vector2(4100, 2400),      # 11
		# S-curve section — flowing arcs
		Vector2(3750, 2550),      # 12
		Vector2(3350, 2650),      # 13
		Vector2(2950, 2600),      # 14
		Vector2(2600, 2450),      # 15
		Vector2(2300, 2550),      # 16
		Vector2(2000, 2700),      # 17
		Vector2(1650, 2750),      # 18
		# Turn 2 — wide sweeping left (bottom hairpin)
		Vector2(1300, 2700),      # 19
		Vector2(1000, 2550),      # 20
		Vector2(800, 2300),       # 21
		Vector2(750, 2000),       # 22
		Vector2(800, 1700),       # 23
		# Final corner back to start
		Vector2(900, 1400),       # 24
		Vector2(950, 1200),       # 25
	])
	checkpoint_indices = [9, 15, 22]
	boost_positions.assign([
		Vector2(2500, 950), Vector2(3750, 2550), Vector2(1650, 2750),
	])
	missile_positions.assign([
		Vector2(3500, 1000), Vector2(2300, 2550),
	])
	_elevation_zones = []

func _load_track_2() -> void:
	# Track 2: Figure-8 Drift Arena — multiple hairpins and sweepers
	centerline.assign([
		# Start/Finish straight
		Vector2(800, 600),        # 0 — finish line
		Vector2(1300, 580),       # 1
		Vector2(1900, 560),       # 2
		Vector2(2500, 560),       # 3
		Vector2(3100, 580),       # 4
		Vector2(3700, 650),       # 5
		# Wide right turn into figure-8 crossover
		Vector2(4150, 800),       # 6
		Vector2(4450, 1050),      # 7
		Vector2(4550, 1350),      # 8
		Vector2(4450, 1650),      # 9
		Vector2(4200, 1900),      # 10
		# Figure-8 crossover going down-left
		Vector2(3800, 2050),      # 11
		Vector2(3400, 2150),      # 12
		Vector2(3000, 2300),      # 13
		Vector2(2600, 2450),      # 14
		# Bottom loop — tight hairpin series
		Vector2(2200, 2600),      # 15
		Vector2(1800, 2700),      # 16
		Vector2(1400, 2700),      # 17
		Vector2(1050, 2600),      # 18
		Vector2(800, 2400),       # 19
		Vector2(700, 2150),       # 20
		Vector2(750, 1900),       # 21
		# Sweeper back up
		Vector2(900, 1700),       # 22
		Vector2(1150, 1550),      # 23
		Vector2(1450, 1450),      # 24
		Vector2(1750, 1400),      # 25
		# Figure-8 crossover going up-right
		Vector2(2050, 1350),      # 26
		Vector2(2350, 1250),      # 27
		Vector2(2650, 1100),      # 28
		Vector2(2950, 950),       # 29
		# Upper right loop — tight drift hairpin
		Vector2(3200, 870),       # 30
		Vector2(3450, 830),       # 31
		Vector2(3650, 880),       # 32
		Vector2(3750, 1020),      # 33
		Vector2(3700, 1170),      # 34
		# Hairpin exit
		Vector2(3500, 1270),      # 35
		Vector2(3250, 1320),      # 36
		Vector2(3000, 1280),      # 37
		# Long sweeper back to bottom section
		Vector2(2750, 1180),      # 38
		Vector2(2500, 1070),      # 39
		Vector2(2250, 980),       # 40
		# Return sweep to start
		Vector2(1950, 920),       # 41
		Vector2(1650, 870),       # 42
		Vector2(1350, 830),       # 43
		Vector2(1050, 780),       # 44
		Vector2(920, 700),        # 45
		Vector2(850, 640),        # 46
	])
	checkpoint_indices = [9, 18, 30, 42]
	boost_positions.assign([
		Vector2(2500, 560), Vector2(4450, 1350), Vector2(1400, 2700),
		Vector2(900, 1700), Vector2(3450, 830),
	])
	missile_positions.assign([
		Vector2(3700, 650), Vector2(2600, 2450), Vector2(1750, 1400),
		Vector2(3250, 1320),
	])
	_elevation_zones = [
		[15, 21, Color(0.22, 0.22, 0.26, 1)],  # Bottom loop (lower)
		[30, 35, Color(0.35, 0.35, 0.40, 1)],   # Upper right loop (elevated)
	]

func _load_track_3() -> void:
	# Track 3: Off-Road Circuit — compact technical circuit inspired by Super Off Road (NES)
	# Tight hairpins, switchbacks, and short straights in a dense layout
	centerline.assign([
		# Start/finish straight (heading right)
		Vector2(700, 800),        # 0 — finish line
		Vector2(1000, 790),       # 1
		Vector2(1300, 770),       # 2
		# Hairpin 1 — sharp right turn
		Vector2(1550, 800),       # 3
		Vector2(1750, 900),       # 4
		Vector2(1850, 1100),      # 5
		Vector2(1800, 1300),      # 6
		Vector2(1650, 1450),      # 7
		# Switchback heading left
		Vector2(1400, 1500),      # 8
		Vector2(1100, 1520),      # 9
		Vector2(850, 1480),       # 10
		# Hairpin 2 — sharp left turn going down
		Vector2(700, 1550),       # 11
		Vector2(650, 1750),       # 12
		Vector2(700, 1950),       # 13
		Vector2(850, 2100),       # 14
		# Chicane section — quick left-right-left
		Vector2(1050, 2180),      # 15
		Vector2(1300, 2130),      # 16
		Vector2(1500, 2200),      # 17
		Vector2(1700, 2300),      # 18
		# Hairpin 3 — tight right turn
		Vector2(1900, 2400),      # 19
		Vector2(2050, 2550),      # 20
		Vector2(2100, 2750),      # 21
		Vector2(2000, 2900),      # 22
		Vector2(1800, 2950),      # 23
		# Long return sweep heading left
		Vector2(1550, 2900),      # 24
		Vector2(1300, 2800),      # 25
		Vector2(1050, 2680),      # 26
		Vector2(850, 2550),       # 27
		# Bottom-left corner — wide sweeper
		Vector2(700, 2380),       # 28
		Vector2(620, 2180),       # 29
		Vector2(600, 1980),       # 30
		# Straight climb back north
		Vector2(620, 1750),       # 31
		Vector2(600, 1500),       # 32
		Vector2(580, 1280),       # 33
		# Final corner back to start
		Vector2(590, 1080),       # 34
		Vector2(620, 920),        # 35
	])
	checkpoint_indices = [5, 12, 20, 27, 33]
	boost_positions.assign([
		Vector2(1300, 770), Vector2(1100, 1520),
		Vector2(1500, 2200), Vector2(1050, 2680),
	])
	missile_positions.assign([
		Vector2(1750, 900), Vector2(850, 2100),
		Vector2(1800, 2950),
	])
	_elevation_zones = []

func _compute_edges() -> void:
	var n := centerline.size()
	_outer_points.clear()
	_inner_points.clear()

	for i in n:
		var prev := centerline[(i - 1 + n) % n]
		var curr := centerline[i]
		var next := centerline[(i + 1) % n]

		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		var avg_dir := (dir_in + dir_out).normalized()
		if avg_dir.length() < 0.01:
			avg_dir = dir_out

		var perp := Vector2(-avg_dir.y, avg_dir.x)

		var cos_half := perp.dot(Vector2(-dir_out.y, dir_out.x))
		var miter := 1.0 / maxf(cos_half, 0.5)
		miter = minf(miter, 1.8)

		_outer_points.append(curr + perp * TRACK_WIDTH * 0.5 * miter)
		_inner_points.append(curr - perp * TRACK_WIDTH * 0.5 * miter)

func _build_background() -> void:
	if centerline.is_empty():
		return
	# Compute bounding box from centerline for dynamic background
	var min_p: Vector2 = centerline[0]
	var max_p: Vector2 = centerline[0]
	for p: Vector2 in centerline:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)

	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		min_p - Vector2(800, 800), Vector2(max_p.x + 800, min_p.y - 800),
		max_p + Vector2(800, 800), Vector2(min_p.x - 800, max_p.y + 800)
	])
	bg.color = Color(0.12, 0.2, 0.10, 1)
	bg.z_index = -10
	add_child(bg)

func _build_road_quads() -> void:
	var n := _outer_points.size()
	var curb_offset := 0.07

	for i in n:
		var ni := (i + 1) % n

		# Road quad (asphalt)
		var road_quad := Polygon2D.new()
		road_quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		road_quad.color = Color(0.25, 0.25, 0.30, 1)
		road_quad.z_index = -5
		add_child(road_quad)

		# Outer curb strip
		var o1 := _outer_points[i]
		var o2 := _outer_points[ni]
		var i1 := _inner_points[i]
		var i2 := _inner_points[ni]
		var oc1 := o1.lerp(i1, curb_offset)
		var oc2 := o2.lerp(i2, curb_offset)
		var outer_curb := Polygon2D.new()
		outer_curb.polygon = PackedVector2Array([o1, o2, oc2, oc1])
		outer_curb.color = Color(0.8, 0.15, 0.1, 1) if (i / 2) % 2 == 0 else Color(0.9, 0.9, 0.9, 1)
		outer_curb.z_index = -4
		add_child(outer_curb)

		# Inner curb strip
		var ic1 := i1.lerp(o1, curb_offset)
		var ic2 := i2.lerp(o2, curb_offset)
		var inner_curb := Polygon2D.new()
		inner_curb.polygon = PackedVector2Array([i1, i2, ic2, ic1])
		inner_curb.color = Color(0.8, 0.15, 0.1, 1) if (i / 2) % 2 == 0 else Color(0.9, 0.9, 0.9, 1)
		inner_curb.z_index = -4
		add_child(inner_curb)

func _build_center_dashes() -> void:
	var dash_len := 30.0
	var gap_len := 30.0
	for i in centerline.size():
		var ni := (i + 1) % centerline.size()
		var p1 := centerline[i]
		var p2 := centerline[ni]
		var seg_dir := p2 - p1
		var seg_length := seg_dir.length()
		if seg_length < 1.0:
			continue
		var seg_norm := seg_dir / seg_length
		var dist := 0.0
		while dist < seg_length:
			var start := p1 + seg_norm * dist
			var end_dist := minf(dist + dash_len, seg_length)
			var end := p1 + seg_norm * end_dist
			var dash := Line2D.new()
			dash.points = PackedVector2Array([start, end])
			dash.width = 4.0
			dash.default_color = Color(1, 1, 1, 0.5)
			dash.z_index = -3
			add_child(dash)
			dist += dash_len + gap_len

func _build_elevation_zones() -> void:
	for zone in _elevation_zones:
		_build_elevation_zone(zone[0], zone[1], zone[2])

func _build_elevation_zone(start_idx: int, end_idx: int, color: Color) -> void:
	for i in range(start_idx, end_idx):
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = color
		quad.z_index = -4
		add_child(quad)

func _build_decorations() -> void:
	var n: int = centerline.size()

	# Grass patches outside walls at straight sections
	for i in range(0, n, 8):
		var ni: int = (i + 1) % n
		var p_cur: Vector2 = centerline[i]
		var p_next: Vector2 = centerline[ni]
		var seg_dir: Vector2 = (p_next - p_cur).normalized()
		var perp: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		# Outer side grass patch
		var outer_base: Vector2 = Vector2(_outer_points[i].x, _outer_points[i].y) + perp * (WALL_THICKNESS + 20)
		var grass := Polygon2D.new()
		var size_x: float = randf_range(60, 120)
		var size_y: float = randf_range(40, 80)
		grass.polygon = PackedVector2Array([
			outer_base,
			outer_base + Vector2(size_x, 0),
			outer_base + Vector2(size_x * 0.8, size_y),
			outer_base + Vector2(size_x * 0.2, size_y * 0.9),
		])
		grass.color = Color(0.15, 0.28, 0.12, 0.7)
		grass.z_index = -9
		add_child(grass)

	# Gravel traps at sharp turns (where direction changes significantly)
	for i in range(1, n - 1):
		var p_prev: Vector2 = centerline[i - 1]
		var p_cur: Vector2 = centerline[i]
		var p_next: Vector2 = centerline[(i + 1) % n]
		var prev_dir: Vector2 = (p_cur - p_prev).normalized()
		var next_dir: Vector2 = (p_next - p_cur).normalized()
		var angle_change: float = abs(prev_dir.angle_to(next_dir))
		if angle_change > 0.4:
			var outer_pt: Vector2 = Vector2(_outer_points[i].x, _outer_points[i].y)
			var seg_dir: Vector2 = (p_next - p_cur).normalized()
			var perp: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
			var gravel := Polygon2D.new()
			var gx: float = 80.0
			var gy: float = 60.0
			var base: Vector2 = outer_pt + perp * (WALL_THICKNESS + 10)
			gravel.polygon = PackedVector2Array([
				base, base + Vector2(gx, 0),
				base + Vector2(gx, gy), base + Vector2(0, gy),
			])
			gravel.color = Color(0.45, 0.38, 0.28, 0.5)
			gravel.z_index = -9
			add_child(gravel)

	# Orange cone markers at checkpoints
	for ci_idx in range(checkpoint_indices.size()):
		var ci: int = checkpoint_indices[ci_idx]
		if ci >= n:
			continue
		var pos: Vector2 = centerline[ci]
		var ni: int = (ci + 1) % n
		var p_next: Vector2 = centerline[ni]
		var seg_dir: Vector2 = (p_next - pos).normalized()
		var perp: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
		for side in [-1.0, 1.0]:
			var cone_pos: Vector2 = pos + perp * (TRACK_WIDTH * 0.35) * side
			var cone := Polygon2D.new()
			cone.polygon = PackedVector2Array([
				cone_pos + Vector2(0, -12),
				cone_pos + Vector2(8, 8),
				cone_pos + Vector2(-8, 8),
			])
			cone.color = Color(1.0, 0.5, 0.0, 0.8)
			cone.z_index = -2
			add_child(cone)

	# Grandstand rectangle near start line
	var start_pos: Vector2 = centerline[0]
	var start_dir: Vector2 = (Vector2(centerline[1].x, centerline[1].y) - start_pos).normalized()
	var start_perp: Vector2 = Vector2(-start_dir.y, start_dir.x)
	var grandstand_base := start_pos + start_perp * (TRACK_WIDTH * 0.5 + WALL_THICKNESS + 60)
	var grandstand := Polygon2D.new()
	grandstand.polygon = PackedVector2Array([
		grandstand_base,
		grandstand_base + start_dir * 200,
		grandstand_base + start_dir * 200 + start_perp * 80,
		grandstand_base + start_perp * 80,
	])
	grandstand.color = Color(0.3, 0.3, 0.35, 0.6)
	grandstand.z_index = -9
	add_child(grandstand)

	# Grandstand seats (rows of color)
	for row in 3:
		var row_base := grandstand_base + start_perp * (15 + row * 20)
		var seat_row := Polygon2D.new()
		seat_row.polygon = PackedVector2Array([
			row_base + start_dir * 10,
			row_base + start_dir * 190,
			row_base + start_dir * 190 + start_perp * 12,
			row_base + start_dir * 10 + start_perp * 12,
		])
		var row_colors := [Color(0.8, 0.2, 0.2, 0.5), Color(0.2, 0.2, 0.8, 0.5), Color(0.8, 0.8, 0.2, 0.5)]
		seat_row.color = row_colors[row]
		seat_row.z_index = -9
		add_child(seat_row)

func _build_walls() -> void:
	var n := _outer_points.size()

	# Outer walls
	var outer_body := StaticBody2D.new()
	outer_body.name = "OuterWalls"
	add_child(outer_body)

	for i in n:
		var ni := (i + 1) % n
		var p1 := _outer_points[i]
		var p2 := _outer_points[ni]
		var dir := (p2 - p1).normalized()
		var perp := Vector2(-dir.y, dir.x) * WALL_THICKNESS

		var col := CollisionPolygon2D.new()
		col.polygon = PackedVector2Array([p1, p2, p2 + perp, p1 + perp])
		outer_body.add_child(col)

	# Inner walls
	var inner_body := StaticBody2D.new()
	inner_body.name = "InnerWalls"
	add_child(inner_body)

	for i in n:
		var ni := (i + 1) % n
		var p1 := _inner_points[i]
		var p2 := _inner_points[ni]
		var dir := (p2 - p1).normalized()
		var perp := Vector2(dir.y, -dir.x) * WALL_THICKNESS

		var col := CollisionPolygon2D.new()
		col.polygon = PackedVector2Array([p1, p2, p2 + perp, p1 + perp])
		inner_body.add_child(col)

func _build_checkpoints() -> void:
	var preload_cp := load("res://scripts/checkpoint.gd")

	for idx in range(checkpoint_indices.size()):
		var ci: int = checkpoint_indices[idx]
		if ci >= centerline.size():
			continue
		var pos := centerline[ci]
		var cp := Area2D.new()
		cp.position = pos
		cp.set_script(preload_cp)
		cp.set("checkpoint_index", idx + 1)
		cp.set("is_finish_line", false)

		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(TRACK_WIDTH, 30)
		col.shape = shape
		var next_ci := (ci + 1) % centerline.size()
		var track_dir := (centerline[next_ci] - pos).angle()
		col.rotation = track_dir + PI / 2.0
		cp.add_child(col)
		add_child(cp)

func _build_items() -> void:
	var preload_item := load("res://scripts/item_pickup.gd")
	var preload_missile := load("res://scripts/missile_pickup.gd")

	for pos in boost_positions:
		var item := Area2D.new()
		item.position = pos
		item.set_script(preload_item)
		add_child(item)

	for pos in missile_positions:
		var item := Area2D.new()
		item.position = pos
		item.set_script(preload_missile)
		add_child(item)

func _build_start_line() -> void:
	if centerline.size() < 2:
		return
	var preload_cp := load("res://scripts/checkpoint.gd")

	var pos := centerline[0]
	var finish := Area2D.new()
	finish.position = pos
	finish.set_script(preload_cp)
	finish.set("checkpoint_index", 0)
	finish.set("is_finish_line", true)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TRACK_WIDTH, 30)
	col.shape = shape
	var dir := (centerline[1] - pos).angle()
	col.rotation = dir + PI / 2.0
	finish.add_child(col)
	add_child(finish)

	# Visual start line
	var next_idx := 1
	var track_dir := (centerline[next_idx] - pos).normalized()
	var perp := Vector2(-track_dir.y, track_dir.x)
	var line := Polygon2D.new()
	line.polygon = PackedVector2Array([
		pos + perp * TRACK_WIDTH * 0.5,
		pos - perp * TRACK_WIDTH * 0.5,
		pos - perp * TRACK_WIDTH * 0.5 + track_dir * 12,
		pos + perp * TRACK_WIDTH * 0.5 + track_dir * 12,
	])
	line.color = Color(1, 1, 1, 0.5)
	line.z_index = -2
	add_child(line)

func connect_to_lap_manager(lm: Node, car_node: CharacterBody2D) -> void:
	for child in get_children():
		if child is Area2D:
			if child.get("is_finish_line") != null:
				if child.is_finish_line:
					if child.has_signal("finish_line_crossed"):
						child.finish_line_crossed.connect(func(body):
							if body == car_node:
								lm.cross_finish_line()
						)
				elif child.has_signal("checkpoint_triggered"):
					child.checkpoint_triggered.connect(func(index, body):
						if body == car_node:
							lm.register_checkpoint(index)
					)

func get_bounding_box() -> Rect2:
	if centerline.is_empty():
		return Rect2()
	var min_p: Vector2 = centerline[0]
	var max_p: Vector2 = centerline[0]
	for p: Vector2 in centerline:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)
	return Rect2(min_p, max_p - min_p)
