extends Control

var value: float = 0.0
var max_value: float = 100.0
var train_color: Color = Color.WHITE

func _process(_delta):
	queue_redraw()

func _draw():
	var w = size.x
	var h = size.y
	
	# 1. Nền viền (theo màu tàu)
	var outline_poly = PackedVector2Array([
		Vector2(-2, -2),
		Vector2(w + 2, -2),
		Vector2(w - 18, h + 2),
		Vector2(18, h + 2)
	])
	draw_colored_polygon(outline_poly, train_color)

	# 2. Nền thanh tốc độ (tối màu)
	var bg_poly = PackedVector2Array([
		Vector2(0, 0),
		Vector2(w, 0),
		Vector2(w - 20, h),
		Vector2(20, h)
	])
	draw_colored_polygon(bg_poly, Color(0.05, 0.05, 0.08, 1.0))
	
	# 3. Chia vạch hiển thị tốc độ
	var num_ticks = 10
	for i in range(num_ticks + 1):
		var t = float(i) / num_ticks
		var tx_top = lerp(0.0, w, t)
		var tx_bot = lerp(20.0, w - 20.0, t)
		draw_line(Vector2(tx_top, 0), Vector2(tx_bot, h), Color(1, 1, 1, 0.15), 2.0)
	
	# 4. Vẽ dải tốc độ (Progress)
	var ratio = clamp(value / max_value, 0.0, 1.0)
	if ratio > 0.001:
		var segments = 40
		var max_i = int(ceil(ratio * segments))
		for i in range(max_i):
			var t1 = float(i) / segments
			var t2 = float(i + 1) / segments
			if t2 > ratio:
				t2 = ratio
				
			var top1 = lerp(0.0, w, t1)
			var top2 = lerp(0.0, w, t2)
			var bot1 = lerp(20.0, w - 20.0, t1)
			var bot2 = lerp(20.0, w - 20.0, t2)
			
			var poly = PackedVector2Array([
				Vector2(top1, 0),
				Vector2(top2, 0),
				Vector2(bot2, h),
				Vector2(bot1, h)
			])
			var c1 = _get_speed_color(t1)
			var c2 = _get_speed_color(t2)
			draw_polygon(poly, PackedColorArray([c1, c2, c2, c1]))

func _get_speed_color(t: float) -> Color:
	if t < 0.3:
		return Color(1.0, 0.2, 0.2).lerp(Color(1.0, 0.8, 0.0), t / 0.3) # Đỏ -> Vàng
	elif t < 0.6:
		return Color(1.0, 0.8, 0.0).lerp(Color(0.2, 1.0, 0.2), (t - 0.3) / 0.3) # Vàng -> Xanh lá
	elif t < 0.8:
		return Color(0.2, 1.0, 0.2) # Xanh lá (tối ưu)
	else:
		return Color(0.2, 1.0, 0.2).lerp(Color(1.0, 0.0, 0.0), (t - 0.8) / 0.2) # Xanh lá -> Đỏ (vượt tốc)
