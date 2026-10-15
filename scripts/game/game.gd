extends Node2D
## Playable prototype of the core loop: one chain rolling along a generated
## track toward a hole, a shooter, triple and word pops, chain reactions and
## scoring. Everything is drawn in code; art comes later.
##
## Controls: drag to aim and release to fire. Tap the shooter (or Space) to
## swap letters. The buttons at the top toggle backward words and relaxed
## mode (keys B and R). N starts the next level or retries; C takes a
## rewarded continue after losing.

const WordList = preload("res://scripts/core/word_list.gd")
const Rules = preload("res://scripts/core/chain_rules.gd")
const ScoreKeeper = preload("res://scripts/core/score_keeper.gd")
const LetterDealer = preload("res://scripts/core/letter_dealer.gd")
const ChainGenerator = preload("res://scripts/core/chain_generator.gd")
const Track = preload("res://scripts/core/track.gd")
const TrackGenerator = preload("res://scripts/core/track_generator.gd")

const VIEW := Vector2(720, 1280)
const D := 48.0  # bubble diameter
const SHOT_SPEED := 2200.0
const INTRO_SPEED_FACTOR := 5.0
const INTRO_FRACTION := 0.3
const CONTINUE_PUSHBACK := 0.35
const POPUP_TIME := 1.4
const ROTATING_SHOOTER_FROM_LEVEL := 4
## Letters ordered by English frequency; a level's alphabet is a prefix.
const FREQUENCY_ORDER := "etaoinsrhldcumfpgwybvkxjqz"

const PLAYING := "playing"
const WON := "won"
const LOST := "lost"

var words := WordList.new()
var score := ScoreKeeper.new()
var dealer: LetterDealer
var track: Track

var level := 1
## Chain letters, tail first (see chain_rules.gd).
var letters: Array = []
## Arc length of the head bubble along the track.
var head_s := 0.0
## Letters still to enter; the last one enters next.
var queue: Array = []
var speed := 40.0
var alphabet := ""
var intro_done := false
var shooter := Vector2.ZERO
var aim := Vector2.UP
var current := ""
var upcoming: Array = []
var shot: Dictionary = {}
var popups: Array = []
var state := PLAYING
var allow_backward := false
var relaxed := false
var aiming := false
var continues_used := 0


func _ready() -> void:
	words.load_files("res://data/words_pop.txt", "res://data/words_seed.txt", "res://data/blocklist.txt")
	Ads.reward_earned.connect(_on_reward)
	start_level(1)


func start_level(n: int) -> void:
	level = n
	var t := clampf((n - 1) / 9.0, 0.0, 1.0)
	var seed_value := n * 7919
	_build_track(n, seed_value)
	alphabet = FREQUENCY_ORDER.substr(0, int(round(lerpf(12, 26, t))))
	var chain_gen := ChainGenerator.new(words, seed_value)
	chain_gen.alphabet = alphabet
	chain_gen.handles_per_block = int(round(lerpf(3, 1, t)))
	queue = chain_gen.generate(int(round(lerpf(50, 120, t))))
	dealer = LetterDealer.new(words, seed_value + 2)
	dealer.help_rate = lerpf(0.8, 0.4, t)
	dealer.pity_limit = int(round(lerpf(2, 4, t)))
	speed = lerpf(40.0, 90.0, t)
	letters = []
	head_s = 0.0
	intro_done = false
	shot = {}
	popups = []
	score.reset_level()
	continues_used = 0
	state = PLAYING
	var preview := queue.slice(maxi(0, queue.size() - 20))
	current = dealer.deal(preview, alphabet)
	upcoming = [dealer.deal(preview, alphabet), dealer.deal(preview, alphabet)]


func _build_track(n: int, seed_value: int) -> void:
	var gen := TrackGenerator.new(seed_value)
	if n >= ROTATING_SHOOTER_FROM_LEVEL:
		var area := Rect2(16, 260, VIEW.x - 32, VIEW.x - 32)
		shooter = area.get_center()
		track = gen.generate(TrackGenerator.SPIRAL, area, shooter, D)
	else:
		shooter = Vector2(VIEW.x / 2.0, VIEW.y - 150.0)
		track = gen.generate(TrackGenerator.SERPENTINE, Rect2(0, 140, VIEW.x, VIEW.y - 430), shooter, D)
	if track == null:
		push_error("No valid track for level %d" % n)


func _process(delta: float) -> void:
	_update_popups(delta)
	if state == PLAYING and track != null:
		_advance_chain(delta)
		_update_shot(delta)
		_check_end()
	queue_redraw()


func _advance_chain(delta: float) -> void:
	if not (relaxed and aiming):
		var factor := 1.0 if intro_done else INTRO_SPEED_FACTOR
		head_s += speed * factor * delta
		if head_s >= track.length * INTRO_FRACTION:
			intro_done = true
	if letters.is_empty() and not queue.is_empty():
		head_s = 0.0
		letters.append(queue.pop_back())
	while not queue.is_empty() and _bubble_s(0) >= D:
		letters.push_front(queue.pop_back())


func _update_shot(delta: float) -> void:
	if shot.is_empty():
		return
	var pos: Vector2 = shot["pos"] + shot["vel"] * delta
	shot["pos"] = pos
	if not Rect2(-Vector2(D, D), VIEW + Vector2(D, D) * 2.0).has_point(pos):
		shot = {}
		score.score_shot([])
		return
	var hit := -1
	var best := D * 0.85
	for i in letters.size():
		var s := _bubble_s(i)
		if s < 0.0:
			continue
		var dist := pos.distance_to(track.position_at(s))
		if dist < best:
			best = dist
			hit = i
	if hit >= 0:
		_land(hit, pos)


## Inserts the shot next to bubble `hit` and resolves pops. Bubbles ahead of
## the landing spot are pushed forward one slot, as in Zuma.
func _land(hit: int, pos: Vector2) -> void:
	var s := _bubble_s(hit)
	var ahead := (pos - track.position_at(s)).dot(track.tangent_at(s)) > 0.0
	var index := hit + 1 if ahead else hit
	letters.insert(index, shot["letter"])
	head_s += D
	shot = {}
	var size := letters.size()
	var events := Rules.resolve(letters, index, index, words, allow_backward)
	score.score_shot(events)
	for k in events.size():
		var event: Dictionary = events[k]
		var removed: Array = event["removed"]
		# If the head end popped, the rest of the chain stays where it was.
		if event["end"] == size - 1:
			head_s -= removed.size() * D
		size -= removed.size()
		popups.append({"text": _describe(event), "pos": pos + Vector2(0, -50 - 44 * k), "t": POPUP_TIME})


func _describe(event: Dictionary) -> String:
	var text: String
	if event["kind"] == Rules.WORD:
		text = String(event["word"]).to_upper()
		if event["backward"]:
			text += " (backward)"
	else:
		text = "Triple"
	var depth: int = event["depth"]
	if depth > 0:
		text += " chain x%d" % (depth + 1)
	return "%s +%d" % [text, event["points"]]


func _check_end() -> void:
	if not letters.is_empty() and head_s >= track.length:
		state = LOST
	elif letters.is_empty() and queue.is_empty() and shot.is_empty():
		state = WON
		Ads.level_completed()


func _bubble_s(i: int) -> float:
	return head_s - (letters.size() - 1 - i) * D


func _update_popups(delta: float) -> void:
	for p in popups:
		p["t"] -= delta
		p["pos"] += Vector2(0, -30) * delta
	popups = popups.filter(func(p): return p["t"] > 0.0)


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for b in _buttons():
				if b["rect"].has_point(mouse):
					_press(b["action"])
					return
			if state != PLAYING:
				return
			if mouse.distance_to(shooter) < D:
				_swap()
				return
			aiming = true
			_aim_at(mouse)
		elif aiming:
			aiming = false
			_aim_at(mouse)
			_fire()
	elif event is InputEventMouseMotion and aiming:
		_aim_at(mouse)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_swap()
			KEY_B:
				_press("backward")
			KEY_R:
				_press("relaxed")
			KEY_C:
				_press("continue")
			KEY_N:
				_press("next" if state == WON else "retry")


func _press(action: String) -> void:
	match action:
		"backward":
			allow_backward = not allow_backward
		"relaxed":
			relaxed = not relaxed
		"next":
			start_level(level + 1)
		"retry":
			start_level(level)
		"continue":
			if state == LOST and Ads.policy.can_offer_continue(continues_used, false):
				Ads.show_rewarded("continue")


func _on_reward(kind: String) -> void:
	if kind == "continue" and state == LOST:
		continues_used += 1
		head_s -= track.length * CONTINUE_PUSHBACK
		state = PLAYING


func _aim_at(target: Vector2) -> void:
	var dir := target - shooter
	if dir.length() > 1.0:
		aim = dir.normalized()


func _fire() -> void:
	if not shot.is_empty() or state != PLAYING:
		return
	shot = {"pos": shooter, "vel": aim * SHOT_SPEED, "letter": current}
	current = upcoming.pop_front()
	upcoming.append(dealer.deal(letters, alphabet))


func _swap() -> void:
	var next: String = upcoming[0]
	upcoming[0] = current
	current = next


func _buttons() -> Array:
	var out: Array = [
		{"rect": Rect2(16, 72, 260, 48), "label": "Backward: %s" % ("on" if allow_backward else "off"), "action": "backward"},
		{"rect": Rect2(292, 72, 230, 48), "label": "Relaxed: %s" % ("on" if relaxed else "off"), "action": "relaxed"},
	]
	var center := VIEW / 2.0
	if state == WON:
		out.append({"rect": Rect2(center.x - 130, center.y + 40, 260, 64), "label": "Next level", "action": "next"})
	elif state == LOST:
		out.append({"rect": Rect2(center.x - 130, center.y + 40, 260, 64), "label": "Retry", "action": "retry"})
		if Ads.policy.can_offer_continue(continues_used, false):
			out.append({"rect": Rect2(center.x - 130, center.y + 120, 260, 64), "label": "Continue (ad)", "action": "continue"})
	return out


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#1d2433"))
	if track != null:
		draw_polyline(track.points, Color("#2c3650"), D * 1.15, true)
		draw_circle(track.points[track.points.size() - 1], D * 0.8, Color("#0b0e14"))
		for i in letters.size():
			var s := _bubble_s(i)
			if s >= 0.0:
				_draw_bubble(track.position_at(s), letters[i], D * 0.5)
	if state == PLAYING:
		draw_dashed_line(shooter, shooter + aim * 240.0, Color(1, 1, 1, 0.35), 3.0, 12.0)
	draw_circle(shooter, D * 0.8, Color("#3d4a6b"))
	_draw_bubble(shooter, current, D * 0.5)
	# Upcoming letters sit just below the shooter, inside the gap a spiral's
	# hole always leaves around it.
	for k in upcoming.size():
		_draw_bubble(shooter + Vector2(D * (0.55 * (2 * k - 1)), D * 1.2), upcoming[k], D * 0.32)
	if not shot.is_empty():
		_draw_bubble(shot["pos"], shot["letter"], D * 0.5)
	var hud := "Level %d    Score %d" % [level, score.total]
	if score.combo > 1:
		hud += "    Combo %d" % score.combo
	draw_string(font, Vector2(16, 48), hud, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	for p in popups:
		var alpha := clampf(p["t"] / POPUP_TIME, 0.0, 1.0)
		draw_string(font, p["pos"] - Vector2(200, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color(1, 0.9, 0.4, alpha))
	if state != PLAYING:
		var message := "Level clear!" if state == WON else "The chain reached the hole"
		draw_string(font, Vector2(0, VIEW.y / 2.0 - 10), message, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, 40, Color.WHITE)
	for b in _buttons():
		var rect: Rect2 = b["rect"]
		draw_rect(rect, Color("#33415e"))
		draw_string(font, rect.position + Vector2(0, rect.size.y * 0.66), b["label"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 26, Color.WHITE)


func _draw_bubble(pos: Vector2, letter: String, radius: float) -> void:
	draw_circle(pos, radius, _letter_color(letter))
	draw_string(ThemeDB.fallback_font, pos + Vector2(-radius, radius * 0.42), letter.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, int(radius * 1.15), Color("#1a1a1a"))


func _letter_color(letter: String) -> Color:
	if letter.is_empty():
		return Color.WHITE
	var index := letter.unicode_at(0) - 97
	return Color.from_hsv(float((index * 7) % 26) / 26.0, 0.38, 1.0)
