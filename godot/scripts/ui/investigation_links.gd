extends Control
## Information drawing on the existing paper, not a replacement art asset.
const Art = preload("res://scripts/ui/art_theme.gd")
var choices: Dictionary = {}
var revealed := -1
var time_confirmed := false
var reveal_steps: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var column := size.x/3.0
	var font := get_theme_default_font()
	for i: int in 3:
		var card := Rect2(column*i+3,2,column-6,42)
		draw_style_box(Art.paper(),card)
		draw_rect(card,Art.CHARCOAL,false,1)
		draw_string(font,Vector2(card.position.x,18),["甲｜車店收據","乙｜交接摘要","丙｜輪值資料"][i],HORIZONTAL_ALIGNMENT_CENTER,card.size.x,12,Art.CHARCOAL)
		var visible_time: bool = reveal_steps[i] == 3 if reveal_steps.size() == 3 else revealed >= i
		draw_string(font,Vector2(card.position.x,36),["17：42","17：55","18：00"][i] if visible_time else "時間待揭",HORIZONTAL_ALIGNMENT_CENTER,card.size.x,13,Art.CHARCOAL)
	for i: int in 2:
		var chosen: int = choices.get(str(i),-1)
		var wrong: bool = chosen >= 0 and chosen != [0,1][i]
		var start := Vector2(column*(i+.5),45)
		var finish := Vector2(column*(i+1.5),45)
		if wrong:
			var swap := start; start = finish; finish = swap
		var ink: Color = Art.RED if wrong else Art.CHARCOAL if chosen >= 0 else Art.KRAFT
		var points := [start,Vector2(start.x,57),Vector2(finish.x,57),finish]
		for j: int in 3:
			if wrong: draw_dashed_line(points[j],points[j+1],ink,2,4,true)
			else: draw_line(points[j],points[j+1],ink,2,true)
		draw_colored_polygon(PackedVector2Array([finish,finish+Vector2(-4,7),finish+Vector2(4,7)]),ink)
		var title: String = ["附件","沿用"][i]+("・待選" if chosen < 0 else "・讀反" if wrong else "・相符" if time_confirmed else "・待核對")
		draw_string(font,Vector2(column*(i+.5),74),title,HORIZONTAL_ALIGNMENT_CENTER,column,12,ink)
