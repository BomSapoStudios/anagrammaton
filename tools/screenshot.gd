extends SceneTree
## Plays the main scene for a few seconds, firing at the chain, and saves a
## screenshot. Needs a display (use xvfb-run on Linux):
##   godot --path . -s tools/screenshot.gd -- <level> <out.png>

var _game: Node
var _frames := 0
var _out := "user://screenshot.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var level := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(_game)
	_game.ready.connect(_game.start_level.bind(level))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 40 == 0:
		_shoot_at_pair()
	if _frames == 360:
		var image := root.get_texture().get_image()
		image.save_png(_out)
		print("saved ", _out, " score=", _game.score.total, " state=", _game.state, " chain=", _game.letters.size())
		return true
	return false


## Loads the letter that completes a visible pair and fires at it, to show
## pops working.
func _shoot_at_pair() -> void:
	var letters: Array = _game.letters
	for i in range(letters.size() - 2, -1, -1):
		if letters[i] == letters[i + 1] and _game._bubble_s(i) > 0.0:
			_game.current = letters[i]
			_game._aim_at(_game.track.position_at(_game._bubble_s(i)))
			_game._fire()
			return
