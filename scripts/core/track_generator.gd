extends RefCounted
## Procedural tracks from shape families, with random parameters. A candidate
## is rejected and regenerated if parallel stretches are too close, it passes
## too near the shooter, or it leaves the play area.

const Track = preload("res://scripts/core/track.gd")

const SPIRAL := "spiral"
const SERPENTINE := "serpentine"
const MAX_ATTEMPTS := 40
const MIN_GAP := 1.3          # parallel stretches, in bubble diameters
const MIN_SHOOTER_GAP := 2.5  # track to shooter, in bubble diameters
const MIN_LENGTH := 20.0      # in bubble diameters

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value


## Returns a Track, or null if no valid track was found.
func generate(family: String, area: Rect2, shooter: Vector2, diameter: float) -> Track:
	for attempt in MAX_ATTEMPTS:
		var pts: PackedVector2Array
		if family == SPIRAL:
			pts = _spiral(area, diameter)
		else:
			pts = _serpentine(area, diameter)
		if is_valid(pts, area, shooter, diameter):
			return Track.new(pts)
	return null


func is_valid(pts: PackedVector2Array, area: Rect2, shooter: Vector2, diameter: float) -> bool:
	var track := Track.new(pts)
	if track.length < diameter * MIN_LENGTH:
		return false
	var samples := PackedVector2Array()
	var arcs := PackedFloat32Array()
	var s := 0.0
	while s <= track.length:
		samples.append(track.position_at(s))
		arcs.append(s)
		s += diameter * 0.5
	var bounds := area.grow(diameter)
	for i in samples.size():
		var p := samples[i]
		if p.distance_to(shooter) < diameter * MIN_SHOOTER_GAP:
			return false
		if not bounds.has_point(p):
			return false
		for j in range(i + 1, samples.size()):
			if arcs[j] - arcs[i] > diameter * 3.0 and p.distance_to(samples[j]) < diameter * MIN_GAP:
				return false
	return true


## Back-and-forth rows from the top of the area downward, entering from the
## left edge. The hole is at the end of the lowest row, nearest the shooter.
func _serpentine(area: Rect2, diameter: float) -> PackedVector2Array:
	var rows := rng.randi_range(3, 5)
	var gap := diameter * rng.randf_range(1.5, 1.9)
	var radius := gap / 2.0
	var left := area.position.x + radius + diameter * rng.randf_range(0.6, 1.4)
	var right := area.end.x - radius - diameter * rng.randf_range(0.6, 1.4)
	var y := area.position.y + diameter
	var pts := PackedVector2Array([Vector2(area.position.x - diameter * 0.5, y)])
	var going_right := true
	for row in rows:
		var x_end := right if going_right else left
		if row == rows - 1:
			# Stop the last row short so the hole sits inside the screen.
			x_end = lerpf(left, right, 0.7) if going_right else lerpf(left, right, 0.3)
		pts.append(Vector2(x_end, y))
		if row == rows - 1:
			break
		var side := 1.0 if going_right else -1.0
		for k in range(1, 17):
			var a := -PI / 2.0 + PI * k / 16.0
			pts.append(Vector2(x_end + side * radius * cos(a), y + radius + radius * sin(a)))
		y += gap
		going_right = not going_right
	return pts


## An inward spiral around the area's centre, where a rotating shooter sits.
func _spiral(area: Rect2, diameter: float) -> PackedVector2Array:
	var center := area.get_center()
	var outer := minf(area.size.x, area.size.y) / 2.0 - diameter * 0.6
	var inner := diameter * rng.randf_range(2.8, 3.4)
	var ring_gap := diameter * rng.randf_range(1.5, 1.8)
	var turns := (outer - inner) / ring_gap
	var max_angle := turns * TAU
	var phase := rng.randf() * TAU
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var pts := PackedVector2Array()
	var angle := 0.0
	while angle <= max_angle:
		var r := outer - ring_gap * angle / TAU
		var a := phase + direction * angle
		pts.append(center + Vector2(cos(a), sin(a)) * r)
		angle += 0.04
	return pts
