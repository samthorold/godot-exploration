class_name WorldGen
extends RefCounted

const CHUNK_SIZE := 30   # Tiles per chunk (each axis)
const TILE_SIZE  := 8    # Pixels per tile

const FLOOR  := 0
const MOSS   := 1
const BLIGHT := 2

static func generate_chunk(chunk_x: int, chunk_y: int, seed: int, moss_probability: float) -> Array:
	var grid := []
	var ox := chunk_x * CHUNK_SIZE
	var oy := chunk_y * CHUNK_SIZE
	for ly in CHUNK_SIZE:
		var row := []
		for lx in CHUNK_SIZE:
			if _hash_check(ox + lx, oy + ly, seed, moss_probability):
				row.append(MOSS)
			else:
				row.append(FLOOR)
		grid.append(row)
	return grid

static func _hash_check(wx: int, wy: int, seed: int, probability: float) -> bool:
	var h: int = seed ^ (wx * 0x9e3779b9) ^ (wy * 0x85ebca6b)
	h ^= h >> 16
	h *= 0x45d9f3b7
	h ^= h >> 16
	return (h & 0x7FFFFFFF) < int(probability * float(0x7FFFFFFF))
