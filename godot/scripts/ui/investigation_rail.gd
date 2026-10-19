extends Control
## Continuous record ribbon and insertion marker, drawn around actual hit targets.
const Art = preload("res://scripts/ui/art_theme.gd")
var origin_mode := false
var origin_caption := ""
var preview := -1
var record_mode := false
var highlights: Array = []
var pinned: Array = []
var sealed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if origin_mode:
		for x: int in range(0,int(size.x),10):
			draw_line(Vector2(x,1),Vector2(mini(x+5,int(size.x)),1),Art.KRAFT,2)
			draw_line(Vector2(x,size.y-1),Vector2(mini(x+5,int(size.x)),size.y-1),Art.KRAFT,2)
		for y: int in range(0,int(size.y),10):
			draw_line(Vector2(1,y),Vector2(1,mini(y+5,int(size.y))),Art.KRAFT,2)
			draw_line(Vector2(size.x-1,y),Vector2(size.x-1,mini(y+5,int(size.y))),Art.KRAFT,2)
		draw_string(get_theme_default_font(),Vector2(5,size.y*.6),origin_caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(Art.CHARCOAL,.45))
		return
	var width := size.x/3.0
	if record_mode:
		draw_line(Vector2(width*.5,42),Vector2(size.x-width*.5,42),Art.KRAFT,3,true)
		for i: int in 3:
			var x := width*(i+.5)
			var active: bool = i in highlights or i in pinned or sealed
			draw_line(Vector2(x,13),Vector2(x,42),Art.CHARCOAL if active else Art.KRAFT,2,true)
			if i == 1:
				draw_colored_polygon(PackedVector2Array([Vector2(x,29),Vector2(x+12,42),Vector2(x,55),Vector2(x-12,42)]),Art.CHARCOAL)
				draw_line(Vector2(x-4,42),Vector2(x+4,42),Art.PAPER,2,true)
			else:
				draw_circle(Vector2(x,42),6,Art.PAPER)
				draw_arc(Vector2(x,42),6,0,TAU,32,Art.CHARCOAL,2 if active else 1,true)
			if i in pinned or sealed:
				draw_circle(Vector2(x,7),4,Art.CHARCOAL)
				draw_line(Vector2(x,9),Vector2(x,15),Art.CHARCOAL,2,true)
	else:
		for i: int in 3:
			var r := Rect2(i*width+2,2,width-4,size.y-4)
			draw_style_box(Art.paper(),r)
			if i == preview: draw_rect(r,Art.AMBER,true)
			draw_rect(r,Art.CHARCOAL if i == preview else Art.KRAFT,false,3 if i == preview else 1)
		if preview >= 0:
			var x := preview*width+2
			draw_line(Vector2(x,0),Vector2(x,size.y),Art.CHARCOAL,4,true)
			draw_colored_polygon(PackedVector2Array([Vector2(x-5,0),Vector2(x+5,0),Vector2(x,7)]),Art.CHARCOAL)
