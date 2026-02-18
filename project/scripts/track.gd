extends Node2D

const TRACK_WIDTH := 500.0
const WALL_THICKNESS := 35.0
const JUMP_WALL_LAYER := 2

# ~70-point centerline spanning ~7200x4800 area
var centerline: Array[Vector2] = [
	# Start/Finish straight (going right)
	Vector2(1000, 800),       # 0 — finish line
	Vector2(1500, 780),       # 1
	Vector2(2100, 760),       # 2
	Vector2(2800, 750),       # 3
	Vector2(3500, 750),       # 4
	Vector2(4200, 770),       # 5
	# Turn 1 - wide sweeping right
	Vector2(4800, 850),       # 6
	Vector2(5300, 1050),      # 7
	Vector2(5600, 1350),      # 8
	Vector2(5700, 1700),      # 9
	Vector2(5650, 2050),      # 10
	# Downhill section (darker elevation zone)
	Vector2(5500, 2400),      # 11
	Vector2(5250, 2700),      # 12
	Vector2(4900, 2950),      # 13
	Vector2(4500, 3100),      # 14
	# Tight hairpin right
	Vector2(4100, 3200),      # 15
	Vector2(3750, 3250),      # 16
	Vector2(3450, 3200),      # 17
	Vector2(3250, 3050),      # 18
	# S-curve complex
	Vector2(3100, 2850),      # 19
	Vector2(3050, 2600),      # 20
	Vector2(3150, 2400),      # 21
	Vector2(3350, 2250),      # 22
	Vector2(3400, 2050),      # 23
	Vector2(3300, 1850),      # 24
	Vector2(3100, 1700),      # 25
	# Jump ramp 1 (over ravine)
	Vector2(2850, 1600),      # 26
	Vector2(2550, 1550),      # 27
	Vector2(2250, 1550),      # 28  — jump ramp start
	Vector2(1950, 1600),      # 29  — jump ramp end
	# Chicane (tight left-right-left)
	Vector2(1700, 1700),      # 30
	Vector2(1500, 1850),      # 31
	Vector2(1300, 1750),      # 32
	Vector2(1150, 1900),      # 33
	Vector2(1000, 1800),      # 34
	# Long downhill to bottom
	Vector2(850, 2000),       # 35
	Vector2(750, 2300),       # 36
	Vector2(700, 2650),       # 37
	Vector2(700, 3000),       # 38
	Vector2(750, 3350),       # 39
	# Wide bottom hairpin
	Vector2(900, 3650),       # 40
	Vector2(1150, 3850),      # 41
	Vector2(1450, 3950),      # 42
	Vector2(1800, 3950),      # 43
	Vector2(2100, 3850),      # 44
	Vector2(2350, 3650),      # 45
	# Uphill tunnel section (lighter elevation zone)
	Vector2(2500, 3400),      # 46
	Vector2(2550, 3100),      # 47
	Vector2(2500, 2800),      # 48
	Vector2(2350, 2550),      # 49
	# Jump ramp 2 (over pit)
	Vector2(2100, 2350),      # 50
	Vector2(1850, 2200),      # 51
	Vector2(1600, 2100),      # 52  — jump ramp 2 start
	Vector2(1350, 2050),      # 53  — jump ramp 2 end
	# Elevated return section
	Vector2(1100, 1650),      # 54
	Vector2(900, 1400),       # 55
	Vector2(750, 1150),       # 56
	Vector2(650, 900),        # 57
	# Fast sweeping final turn
	Vector2(600, 700),        # 58
	Vector2(650, 550),        # 59
	Vector2(750, 450),        # 60
	Vector2(900, 400),        # 61
	# Final approach back to start
	Vector2(1100, 500),       # 62
	Vector2(1200, 650),       # 63
	Vector2(1150, 750),       # 64
]

# 4 checkpoints at strategic points
var checkpoint_indices := [9, 18, 40, 54]

# Boost item positions
var boost_positions: Array[Vector2] = [
	Vector2(2800, 750),     # Top straight
	Vector2(5650, 2050),    # Right side downhill
	Vector2(3150, 2400),    # S-curve
	Vector2(750, 2650),     # Left side
	Vector2(1800, 3950),    # Bottom hairpin
	Vector2(650, 900),      # Final turn
]

# Missile item positions
var missile_positions: Array[Vector2] = [
	Vector2(4200, 770),     # After start straight
	Vector2(4500, 3100),    # Before hairpin
	Vector2(2550, 1550),    # Before jump ramp 1
	Vector2(2500, 3100),    # Tunnel section
	Vector2(900, 1400),     # Return section
]

# Jump shortcut: wall indices for jump ramp sections (inner wall segments on layer 2)
var jump_ramp_1_indices := [28, 29]  # Ravine jump
var jump_ramp_2_indices := [52, 53]  # Pit jump

var _outer_points: PackedVector2Array = PackedVector2Array()
var _inner_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	_compute_edges()
	_build_background()
	_build_road_surface()
	_build_elevation_zones()
	_build_walls()
	_build_checkpoints()
	_build_items()
	_build_jump_ramps()
	_build_start_line()

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
		var miter := 1.0 / maxf(cos_half, 0.3)
		miter = minf(miter, 2.5)

		_outer_points.append(curr + perp * TRACK_WIDTH * 0.5 * miter)
		_inner_points.append(curr - perp * TRACK_WIDTH * 0.5 * miter)

func _build_background() -> void:
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(-500, -500), Vector2(7500, -500),
		Vector2(7500, 5000), Vector2(-500, 5000)
	])
	bg.color = Color(0.12, 0.2, 0.10, 1)
	bg.z_index = -10
	add_child(bg)

func _build_road_surface() -> void:
	var road_poly := PackedVector2Array()
	for p in _outer_points:
		road_poly.append(p)
	for i in range(_inner_points.size() - 1, -1, -1):
		road_poly.append(_inner_points[i])

	var road := Polygon2D.new()
	road.polygon = road_poly
	road.color = Color(0.28, 0.28, 0.32, 1)
	road.z_index = -5
	add_child(road)

	# Racing line (center stripe)
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for p in centerline:
		pts.append(p)
	pts.append(centerline[0])
	line.points = pts
	line.width = 3.0
	line.default_color = Color(1, 1, 1, 0.08)
	line.z_index = -4
	add_child(line)

func _build_elevation_zones() -> void:
	# Downhill section = lower (darker) — indices 11-14
	var low_indices_1 := range(11, 15)
	for i in low_indices_1:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.22, 0.22, 0.26, 1)
		quad.z_index = -4
		add_child(quad)

	# Bottom hairpin = lower (darker) — indices 39-45
	var low_indices_2 := range(39, 46)
	for i in low_indices_2:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.22, 0.22, 0.26, 1)
		quad.z_index = -4
		add_child(quad)

	# Tunnel/uphill section = elevated (lighter) — indices 46-53
	var elevated_indices_1 := range(46, 54)
	for i in elevated_indices_1:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.35, 0.35, 0.40, 1)
		quad.z_index = -4
		add_child(quad)

	# Elevated return section — indices 54-58
	var elevated_indices_2 := range(54, 59)
	for i in elevated_indices_2:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.35, 0.35, 0.40, 1)
		quad.z_index = -4
		add_child(quad)

func _build_walls() -> void:
	var n := _outer_points.size()
	var all_jump_indices := jump_ramp_1_indices + jump_ramp_2_indices

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

		if i in all_jump_indices:
			var jump_body := StaticBody2D.new()
			jump_body.collision_layer = 1 << (JUMP_WALL_LAYER - 1)
			jump_body.add_child(col)
			add_child(jump_body)
			# Visual ramp indicator
			var ramp_vis := Polygon2D.new()
			ramp_vis.polygon = PackedVector2Array([
				_inner_points[i], _inner_points[ni],
				centerline[(i + 1) % centerline.size()], centerline[i]
			])
			ramp_vis.color = Color(0.5, 0.3, 0.1, 0.4)
			ramp_vis.z_index = -3
			add_child(ramp_vis)
		else:
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

func _build_jump_ramps() -> void:
	var all_ramp_indices := jump_ramp_1_indices + jump_ramp_2_indices
	for i in all_ramp_indices:
		if i >= centerline.size():
			continue
		var pos := centerline[i]
		var arrow := Label.new()
		arrow.text = "JUMP"
		arrow.position = pos + Vector2(-30, -40)
		arrow.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 0.6))
		arrow.add_theme_font_size_override("font_size", 20)
		arrow.z_index = 5
		add_child(arrow)

func _build_start_line() -> void:
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

func connect_to_lap_manager(lap_manager: Node, car: CharacterBody2D) -> void:
	for child in get_children():
		if child is Area2D:
			if child.get("is_finish_line") != null:
				if child.is_finish_line:
					if child.has_signal("finish_line_crossed"):
						child.finish_line_crossed.connect(func(body):
							if body == car:
								lap_manager.cross_finish_line()
						)
				elif child.has_signal("checkpoint_triggered"):
					child.checkpoint_triggered.connect(func(index, body):
						if body == car:
							lap_manager.register_checkpoint(index)
					)
