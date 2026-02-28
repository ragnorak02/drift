class_name GhostData
extends RefCounted

## Binary ghost replay serialization.
## Format: "GHOS" (4B) + version (4B) + track_index (4B) + total_time (4B)
##         + best_lap (4B) + frame_count (4B) = 24B header
## Per frame: pos.x (4B) + pos.y (4B) + rotation (4B) + drift_tier (1B) + is_boosting (1B) = 14B

const GHOST_DIR := "user://ghosts/"
const MAGIC := "GHOS"
const VERSION := 1

static func _ghost_path(track_index: int) -> String:
	return GHOST_DIR + "track_%d_best.ghost" % track_index

static func has_ghost(track_index: int) -> bool:
	return FileAccess.file_exists(_ghost_path(track_index))

static func get_ghost_time(track_index: int) -> float:
	var path := _ghost_path(track_index)
	if not FileAccess.file_exists(path):
		return INF
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return INF
	# Read header: magic(4) + version(4) + track_index(4) + total_time(4)
	var magic := f.get_buffer(4).get_string_from_ascii()
	if magic != MAGIC:
		return INF
	f.get_32()  # version
	f.get_32()  # track_index
	var total_time := f.get_float()
	return total_time

static func save_ghost(track_index: int, total_time: float, best_lap: float, frames: Array) -> bool:
	# Only overwrite if new time is better
	var existing_time := get_ghost_time(track_index)
	if total_time >= existing_time:
		print("[Ghost] Not saved — existing ghost (%.2fs) is faster than new (%.2fs)" % [existing_time, total_time])
		return false

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(GHOST_DIR)

	var path := _ghost_path(track_index)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[Ghost] Failed to open %s for writing" % path)
		return false

	# Write header
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_32(VERSION)
	f.store_32(track_index)
	f.store_float(total_time)
	f.store_float(best_lap)
	f.store_32(frames.size())

	# Write frames
	for frame: Dictionary in frames:
		f.store_float(frame.position.x)
		f.store_float(frame.position.y)
		f.store_float(frame.rotation)
		f.store_8(clampi(frame.drift_tier, 0, 255))
		f.store_8(1 if frame.is_boosting else 0)

	print("[Ghost] Saved ghost for track %d — %.2fs, %d frames" % [track_index, total_time, frames.size()])
	return true

static func load_ghost(track_index: int) -> Dictionary:
	var path := _ghost_path(track_index)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}

	# Read header
	var magic := f.get_buffer(4).get_string_from_ascii()
	if magic != MAGIC:
		push_warning("[Ghost] Invalid ghost file magic: %s" % magic)
		return {}
	var version := f.get_32()
	if version != VERSION:
		push_warning("[Ghost] Unsupported ghost version: %d" % version)
		return {}
	var file_track := f.get_32()
	var total_time := f.get_float()
	var best_lap := f.get_float()
	var frame_count := f.get_32()

	# Read frames
	var frames: Array[Dictionary] = []
	frames.resize(frame_count)
	for i: int in frame_count:
		var px := f.get_float()
		var py := f.get_float()
		var rot := f.get_float()
		var dt := f.get_8()
		var ib := f.get_8()
		frames[i] = {
			"position": Vector2(px, py),
			"rotation": rot,
			"drift_tier": dt,
			"is_boosting": ib == 1,
		}

	print("[Ghost] Loaded ghost for track %d — %.2fs, %d frames" % [file_track, total_time, frame_count])
	return {
		"track_index": file_track,
		"total_time": total_time,
		"best_lap": best_lap,
		"frame_count": frame_count,
		"frames": frames,
	}
