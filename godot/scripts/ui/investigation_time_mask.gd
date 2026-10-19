extends Control
## Existing paper texture, real typeset times and a moving opaque paper cover.
const Art = preload("res://scripts/ui/art_theme.gd")
var panel: CanvasLayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func areas() -> Array:
	var result: Array = []
	for i: int in 3:
		result.append(clampf(float(panel.reveal_count-i)+panel.reveal_clock/.8,0,1))
	return result

func _draw() -> void:
	var width := size.x/3.0
	var font := get_theme_default_font()
	var progress := areas()
	for i: int in 3:
		var paper := Rect2(width*i+3,3,width-6,size.y-6)
		draw_style_box(Art.paper(),paper)
		draw_rect(paper,Art.KRAFT,false,1)
		draw_string(font,Vector2(paper.position.x,26),["甲 車店收據","乙 交接摘要","丙 輪值資料"][i],HORIZONTAL_ALIGNMENT_CENTER,paper.size.x,13,Art.CHARCOAL)
		var time_box := Rect2(paper.position+Vector2(6,36),Vector2(paper.size.x-12,size.y-70))
		draw_string(font,Vector2(time_box.position.x,time_box.position.y+time_box.size.y*.65),["17：42","17：55","18：00"][i],HORIZONTAL_ALIGNMENT_CENTER,time_box.size.x,20 if size.x>330 else 16,Art.CHARCOAL)
		var cover := Rect2(time_box.position+Vector2(time_box.size.x*progress[i],0),Vector2(time_box.size.x*(1-progress[i]),time_box.size.y))
		if cover.size.x > 0:
			draw_rect(cover,Art.CHARCOAL)
			draw_line(cover.position,cover.position+Vector2(0,cover.size.y),Art.AMBER,3,true)
			for y: int in range(int(cover.position.y+4),int(cover.end.y),8):
				draw_line(Vector2(cover.position.x+2,y),Vector2(cover.end.x,y),Color("65502c"),1)
		draw_string(font,Vector2(paper.position.x,paper.end.y-9),"已揭" if progress[i]>=1 else "揭開中" if progress[i]>0 else "待揭",HORIZONTAL_ALIGNMENT_CENTER,paper.size.x,13,Art.CHARCOAL)
