extends RefCounted
## A track as a polyline, addressed by arc length from its start.

var points := PackedVector2Array()
var length := 0.0

var _cumulative := PackedFloat32Array()


func _init(track_points: PackedVector2Array = PackedVector2Array()) -> void:
	points = track_points
	_cumulative.resize(points.size())
	var total := 0.0
	for i in points.size():
		if i > 0:
			total += points[i].distance_to(points[i - 1])
		_cumulative[i] = total
	length = total


func position_at(s: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if s <= 0.0:
		return points[0]
	if s >= length:
		return points[points.size() - 1]
	var i := clampi(_cumulative.bsearch(s), 1, points.size() - 1)
	var segment := _cumulative[i] - _cumulative[i - 1]
	var t := 0.0 if segment <= 0.0 else (s - _cumulative[i - 1]) / segment
	return points[i - 1].lerp(points[i], t)


## Unit direction of travel at arc length s.
func tangent_at(s: float) -> Vector2:
	return (position_at(s + 2.0) - position_at(s - 2.0)).normalized()
