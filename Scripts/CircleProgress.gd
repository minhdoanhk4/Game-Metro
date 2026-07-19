extends Control

var value: float = 0.0 :
	set(v):
		value = v
		queue_redraw()
		if has_node("Label"):
			$Label.text = str(int(value)) + "%"

func _draw():
	var center = size / 2.0
	var radius = min(size.x, size.y) / 2.0 - 10.0
	var start_angle = -PI / 2.0
	var end_angle = start_angle + (value / 100.0) * PI * 2.0

	# Draw background ring (dark grey, half transparent)
	draw_arc(center, radius, 0, PI * 2.0, 64, Color(0.1, 0.1, 0.1, 0.6), 16.0, true)

	# Draw progress ring (bright cyan/blue)
	if value > 0:
		draw_arc(center, radius, start_angle, end_angle, 64, Color(0.0, 0.8, 1.0, 1.0), 16.0, true)
