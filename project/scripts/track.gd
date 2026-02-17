extends Node2D

const TRACK_WIDTH := 220.0
const WALL_THICKNESS := 20.0
const JUMP_WALL_LAYER := 2

# Complex winding track centerline
var centerline: Array[Vector2] = [
	# Start/Finish straight (going right)
	Vector2(800, 600),
	Vector2(1200, 580),
	Vector2(1800, 560),
	Vector2(2400, 560),
	Vector2(2900, 580),
	# Turn 1 - sweeping right
	Vector2(3200, 650),
	Vector2(3450, 800),
	Vector2(3550, 1050),
	Vector2(3550, 1300),
	# Down the right side
	Vector2(3500, 1550),
	Vector2(3380, 1750),
	# Turn 2 - left toward chicane
	Vector2(3150, 1900),
	Vector2(2900, 1980),
	# Chicane section
	Vector2(2650, 1920),
	Vector2(2450, 1830),
	Vector2(2250, 1920),
	Vector2(2050, 1830),
	Vector2(1850, 1920),
	# Southwest run
	Vector2(1550, 2050),
	Vector2(1250, 2200),
	# Hairpin
	Vector2(950, 2380),
	Vector2(700, 2450),
	Vector2(500, 2350),
	Vector2(420, 2150),
	# Left side going north
	Vector2(400, 1850),
	Vector2(400, 1550),
	Vector2(430, 1250),
	# S-curve
	Vector2(550, 1050),
	Vector2(430, 850),
	Vector2(500, 680),
	# Final approach back to start
	Vector2(620, 600),
]

# Checkpoint positions (indices into centerline)
var checkpoint_indices := [8, 16, 24]  # Turn 1, chicane, hairpin exit

# Item pickup positions (world coords)
var item_positions: Array[Vector2] = [
	Vector2(1800, 560),    # Top straight
	Vector2(3500, 1300),   # Right side
	Vector2(2250, 1920),   # Chicane middle
	Vector2(420, 1550),    # Left side
	Vector2(500, 850),     # S-curve
]

# Jump shortcut: wall indices to put on layer 2 (inner wall segments)
# These are indices into the wall segment arrays
var jump_shortcut_inner := [13, 14, 15]  # Chicane inner wall gap
var jump_shortcut_outer := []

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

		# Average direction at this point
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		var avg_dir := (dir_in + dir_out).normalized()
		if avg_dir.length() < 0.01:
			avg_dir = dir_out

		# Perpendicular (left = outer for clockwise track, right = inner)
		var perp := Vector2(-avg_dir.y, avg_dir.x)

		# Miter correction to prevent pinching at sharp angles
		var cos_half := perp.dot(Vector2(-dir_out.y, dir_out.x))
		var miter := 1.0 / maxf(cos_half, 0.3)
		miter = minf(miter, 2.5)

		_outer_points.append(curr + perp * TRACK_WIDTH * 0.5 * miter)
		_inner_points.append(curr - perp * TRACK_WIDTH * 0.5 * miter)

func _build_background() -> void:
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(-300, -200), Vector2(4200, -200),
		Vector2(4200, 3000), Vector2(-300, 3000)
	])
	bg.color = Color(0.12, 0.2, 0.10, 1)
	bg.z_index = -10
	add_child(bg)

func _build_road_surface() -> void:
	# Road = polygon from outer + reversed inner
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

	# Racing line (center stripe, subtle)
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for p in centerline:
		pts.append(p)
	pts.append(centerline[0])
	line.points = pts
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.08)
	line.z_index = -4
	add_child(line)

func _build_elevation_zones() -> void:
	# Visual elevation: darker road in "low" sections, lighter in "high"
	# S-curve area = elevated (lighter)
	var elevated_indices := range(26, 30)  # S-curve points
	for i in elevated_indices:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.35, 0.35, 0.40, 1)  # lighter = elevated
		quad.z_index = -4
		add_child(quad)

	# Hairpin area = lower (darker)
	var low_indices := range(19, 24)
	for i in low_indices:
		if i >= _outer_points.size() - 1:
			continue
		var ni: int = (i + 1) % _outer_points.size()
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			_outer_points[i], _outer_points[ni],
			_inner_points[ni], _inner_points[i]
		])
		quad.color = Color(0.22, 0.22, 0.26, 1)  # darker = lower
		quad.z_index = -4
		add_child(quad)

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
		var perp := Vector2(dir.y, -dir.x) * WALL_THICKNESS  # inward

		var col := CollisionPolygon2D.new()
		col.polygon = PackedVector2Array([p1, p2, p2 + perp, p1 + perp])

		# Jump shortcut walls go on a separate layer
		if i in jump_shortcut_inner:
			var jump_body := StaticBody2D.new()
			jump_body.collision_layer = 1 << (JUMP_WALL_LAYER - 1)
			jump_body.add_child(col)
			add_child(jump_body)
			# Visual indicator for jump section
			var ramp_vis := Polygon2D.new()
			ramp_vis.polygon = PackedVector2Array([
				_inner_points[i], _inner_points[ni],
				centerline[(i + 1) % centerline.size()], centerline[i]
			])
			ramp_vis.color = Color(0.5, 0.3, 0.1, 0.4)  # brown ramp look
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
		shape.size = Vector2(TRACK_WIDTH, 20)
		col.shape = shape
		# Rotate collision to be perpendicular to track direction
		var next_ci := (ci + 1) % centerline.size()
		var track_dir := (centerline[next_ci] - pos).angle()
		col.rotation = track_dir + PI / 2.0
		cp.add_child(col)
		add_child(cp)

func _build_items() -> void:
	var preload_item := load("res://scripts/item_pickup.gd")

	for pos in item_positions:
		var item := Area2D.new()
		item.position = pos
		item.set_script(preload_item)
		add_child(item)

func _build_jump_ramps() -> void:
	# Visual arrows on jump sections
	for i in jump_shortcut_inner:
		if i >= centerline.size():
			continue
		var pos := centerline[i]
		var arrow := Label.new()
		arrow.text = "JUMP"
		arrow.position = pos + Vector2(-20, -30)
		arrow.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 0.6))
		arrow.add_theme_font_size_override("font_size", 14)
		arrow.z_index = 5
		add_child(arrow)

func _build_start_line() -> void:
	var preload_cp := load("res://scripts/checkpoint.gd")

	# Start/finish between points 0 and 1
	var pos := centerline[0]
	var finish := Area2D.new()
	finish.position = pos
	finish.set_script(preload_cp)
	finish.set("checkpoint_index", 0)
	finish.set("is_finish_line", true)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TRACK_WIDTH, 20)
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
		pos - perp * TRACK_WIDTH * 0.5 + track_dir * 8,
		pos + perp * TRACK_WIDTH * 0.5 + track_dir * 8,
	])
	line.color = Color(1, 1, 1, 0.5)
	line.z_index = -2
	add_child(line)

func connect_to_lap_manager(lap_manager: Node) -> void:
	for child in get_children():
		if child is Area2D:
			if child.get("is_finish_line") != null:
				if child.is_finish_line:
					if child.has_signal("finish_line_crossed"):
						child.finish_line_crossed.connect(lap_manager.cross_finish_line)
				elif child.has_signal("checkpoint_triggered"):
					child.checkpoint_triggered.connect(lap_manager.register_checkpoint)
