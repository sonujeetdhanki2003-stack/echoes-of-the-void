class_name ConduitBoard
extends RefCounted
## Conduit rotation logic: a W x H grid of pipe tiles. Each tile has connections (bitmask N=1 E=2 S=4 W=8)
## and a rotation 0..3. Power enters at SOURCE (left edge of row source_row) and must reach the UPLINK
## (right edge of row uplink_row) without powering the SPIRE FEED outlet (right edge of row feed_row).

const N := 1
const E := 2
const S := 4
const W := 8

var w := 5
var h := 4
var source_row := 1
var uplink_row := 2
var feed_row := 0
var feed2_row := 3
var base: Array = []     # connection mask at rotation 0
var rot: Array = []      # current rotation per tile
var solution: Array = [] # a known-good rotation per tile

static func rotate_mask(m: int, r: int) -> int:
	var out := m
	for i in r:
		out = ((out << 1) | (out >> 3)) & 15
	return out

func mask(x: int, y: int) -> int:
	return rotate_mask(base[y * w + x], rot[y * w + x])

## The designed layout: a carved route from SOURCE to UPLINK plus decoy tiles, scrambled.
func setup_default() -> void:
	base.clear()
	rot.clear()
	solution.clear()
	for k in w * h:
		base.append(E | W)
		solution.append(0)
		rot.append(0)
	_make_solvable()
	scramble(7)

## Build a guaranteed route: carve a path from source to uplink and set tile shapes along it.
func _make_solvable() -> void:
	var path := [Vector2i(0, source_row), Vector2i(1, source_row), Vector2i(2, source_row), Vector2i(2, source_row + 1), Vector2i(3, source_row + 1), Vector2i(4, source_row + 1)]
	var shapes := {}
	for i in path.size():
		var c: Vector2i = path[i]
		var m := 0
		var prev: Vector2i = path[i - 1] if i > 0 else Vector2i(-1, source_row)
		var nxt: Vector2i = path[i + 1] if i < path.size() - 1 else Vector2i(w, uplink_row)
		for o in [prev, nxt]:
			var d: Vector2i = o - c
			if d == Vector2i(0, -1): m |= N
			elif d == Vector2i(1, 0): m |= E
			elif d == Vector2i(0, 1): m |= S
			elif d == Vector2i(-1, 0): m |= W
		shapes[c] = m
	for c in shapes.keys():
		var cc: Vector2i = c
		var want: int = shapes[cc]
		# store as a canonical base shape with the rotation that produces `want`
		var canon := _canon(want)
		base[cc.y * w + cc.x] = canon
		for r in 4:
			if rotate_mask(canon, r) == want:
				solution[cc.y * w + cc.x] = r
				break
	# decoys: give every other tile a random shape; solution rotation = any (irrelevant) except that no decoy
	# may connect the route to the feed outlets in the solved state — checked by solved_state_ok().
	var rng := RandomNumberGenerator.new()
	rng.seed = 4171
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if shapes.has(c):
				continue
			var opts := [E | W, N | E, N | E | S, E | W, N | E]
			base[y * w + x] = opts[rng.randi() % opts.size()]
			solution[y * w + x] = rng.randi() % 4
	# make sure decoys don't leak power into the feeds in the solved state; rotate offenders until clean
	for attempt in 64:
		rot = solution.duplicate()
		var pw := powered()
		if not pw["feed"]:
			break
		for y in h:
			for x in w:
				if pw["cells"].has(Vector2i(x, y)) and not shapes.has(Vector2i(x, y)):
					solution[y * w + x] = (solution[y * w + x] + 1) % 4

func _canon(m: int) -> int:
	var best := m
	for r in 4:
		var v := rotate_mask(m, r)
		if v < best:
			best = v
	return best

func scramble(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	rot = solution.duplicate()
	for i in rot.size():
		rot[i] = (rot[i] + 1 + rng.randi() % 3) % 4
	if is_solved():
		rot[0] = (rot[0] + 1) % 4

func load_solved() -> void:
	rot = solution.duplicate()

func rotate_tile(x: int, y: int) -> void:
	rot[y * w + x] = (rot[y * w + x] + 1) % 4

## Flood power from the source. Returns {cells: {Vector2i: true}, uplink: bool, feed: bool}.
func powered() -> Dictionary:
	var cells := {}
	var uplink := false
	var feed := false
	var start := Vector2i(0, source_row)
	if not (mask(0, source_row) & W):
		return {"cells": cells, "uplink": false, "feed": false}
	var q: Array = [start]
	cells[start] = true
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		var m := mask(c.x, c.y)
		for d in [[N, Vector2i(0, -1), S], [E, Vector2i(1, 0), W], [S, Vector2i(0, 1), N], [W, Vector2i(-1, 0), E]]:
			if not (m & int(d[0])):
				continue
			var nb: Vector2i = c + d[1]
			if nb.x >= w:
				if c.y == uplink_row:
					uplink = true
				elif c.y == feed_row or c.y == feed2_row:
					feed = true
				continue
			if nb.x < 0 or nb.y < 0 or nb.y >= h:
				continue
			if cells.has(nb):
				continue
			if mask(nb.x, nb.y) & int(d[2]):
				cells[nb] = true
				q.append(nb)
	return {"cells": cells, "uplink": uplink, "feed": feed}

func is_solved() -> bool:
	var p := powered()
	return p["uplink"] and not p["feed"]
