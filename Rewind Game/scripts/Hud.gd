extends CanvasLayer

@onready var rewind_bar: ProgressBar = $UI/RewindBar
@onready var rewind_manager: Node = get_node("/root/RewindManager")

# Tweak these colors however you want
const COLOR_FULL := Color(0.2, 0.9, 0.2, 1.0)       # green
const COLOR_REWINDING := Color(1.0, 0.8, 0.2, 1.0)  # yellow/orange
const COLOR_RECHARGING := Color(0.3, 0.6, 1.0, 1.0) # blue

var _fill_style: StyleBoxFlat
var _last_state: String = ""

func _ready() -> void:
	# Grab the current fill stylebox (or make one if it doesn't exist)
	_fill_style = rewind_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if _fill_style == null:
		_fill_style = StyleBoxFlat.new()
		rewind_bar.add_theme_stylebox_override("fill", _fill_style)

	# Set an initial color
	_apply_state_color(rewind_manager.get_rewind_state())

func _process(_delta: float) -> void:
	rewind_bar.value = rewind_manager.get_rewind_percent()

	var state: String = rewind_manager.get_rewind_state()
	if state != _last_state:
		_apply_state_color(state)

func _apply_state_color(state: String) -> void:
	_last_state = state

	match state:
		"full":
			_fill_style.bg_color = COLOR_FULL
		"rewinding":
			_fill_style.bg_color = COLOR_REWINDING
		"recharging":
			_fill_style.bg_color = COLOR_RECHARGING
		_:
			_fill_style.bg_color = COLOR_FULL

	# Re-apply to force refresh
	rewind_bar.add_theme_stylebox_override("fill", _fill_style)
