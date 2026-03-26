class_name ColorChannels
extends RefCounted

enum Channel {
	WHITE,
	RED,
	BLUE,
	GREEN,
	YELLOW,
	PURPLE,
	ORANGE
}

static func to_color(channel: int) -> Color:
	match channel:
		Channel.RED:
			return Color("e5484d")
		Channel.BLUE:
			return Color("4c8dff")
		Channel.GREEN:
			return Color("46c36f")
		Channel.YELLOW:
			return Color("f2c94c")
		Channel.PURPLE:
			return Color("9b5de5")
		Channel.ORANGE:
			return Color("f2994a")
		_:
			return Color.WHITE

static func apply_to_color_fill(root: Node, channel: int, alpha: float = 1.0) -> void:
	var poly := root.find_child("ColorFill", true, false) as Polygon2D
	if poly == null:
		return

	var c := to_color(channel)
	c.a = alpha
	poly.color = c
