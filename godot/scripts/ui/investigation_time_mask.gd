extends Control
## Four detents on each paper tape. Release freezes it; drag back to cover.
const Art = preload("res://scripts/ui/art_theme.gd")
const Seal = preload("res://assets/art/content-r14/paper-seal.webp")
var panel: CanvasLayer
var held := -1
var hold_clock := 0.0
var moved := false
var start := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_cover_input)

func _process(delta: float) -> void:
	if held < 0 or moved: return
	hold_clock += delta
	if hold_clock >= .55:
		hold_clock = 0
		set_step(held,int(panel.manager.entry().reveal_steps[held])+1)

func set_step(index: int, step: int) -> void:
	panel.manager.reveal_time(index,clampi(step,0,3))
	panel.reveal_count = panel.manager.entry().reveal_steps.count(3)
	var diagram: Control = panel.surface.find_child("RevealedDocumentLinks",true,false)
	if diagram:
		diagram.revealed = panel.reveal_count-1
		diagram.reveal_steps = panel.manager.entry().reveal_steps.duplicate()
		diagram.time_confirmed = panel.reveal_count == 3
		diagram.queue_redraw()
	var status: Label = panel.surface.find_child("IllustrationState",true,false)
	if status: status.text = panel.illustration_caption()
	queue_redraw()
	if panel.reveal_count == 3: panel.show_page.call_deferred()

func _cover_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var down := false
	var up := false
	var motion := false
	if event is InputEventScreenTouch:
		point = event.position; down = event.pressed; up = not down
	elif event is InputEventScreenDrag:
		point = event.position; motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position; down = event.pressed; up = not down
	elif event is InputEventMouseMotion:
		point = event.position; motion = true
	else: return
	if down:
		held = clampi(int(point.x/(size.x/3.0)),0,2)
		start = point; moved = false; hold_clock = 0
	if held < 0: return
	if motion and (moved or point.distance_to(start) > 6):
		moved = true
		var width := size.x/3.0
		set_step(held,roundi(clampf((point.x-width*held-10)/(width-20),0,1)*3))
	if up: held = -1
	accept_event()

func areas() -> Array:
	return panel.manager.entry().reveal_steps.map(func(step: Variant) -> float: return float(step)/3.0)

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
		draw_rect(time_box.grow(-1),Art.RED,false,2)
		draw_string(font,Vector2(time_box.position.x,time_box.position.y+time_box.size.y*.65),["17：42","17：55","18：00"][i],HORIZONTAL_ALIGNMENT_CENTER,time_box.size.x,20 if size.x>330 else 16,Art.CHARCOAL)
		var cover := Rect2(time_box.position+Vector2(time_box.size.x*progress[i],0),Vector2(time_box.size.x*(1-progress[i]),time_box.size.y))
		if cover.size.x > 0:
			draw_rect(Rect2(cover.position+Vector2(2,4),cover.size),Color(0,0,0,.24))
			draw_texture_rect_region(Seal,cover,Rect2(Vector2(Seal.get_width()*progress[i],0),Vector2(Seal.get_width()*(1-progress[i]),Seal.get_height())))
			for tear: int in range(0,int(cover.size.y),8):
				draw_line(cover.position+Vector2(0,tear),cover.position+Vector2(4,tear+4),Art.PAPER,3,true)
			for tape: int in range(int(progress[i]*6)):
				draw_rect(Rect2(time_box.position+Vector2(tape*6,-4),Vector2(5,9)),Color("c8b084"))
			# Lifted paper edge, distinct from the unrevealed time beneath it.
			var fold := minf(12,cover.size.x*.35)
			draw_colored_polygon(PackedVector2Array([cover.position,cover.position+Vector2(fold,-5),cover.position+Vector2(fold,cover.size.y)]),Color("dec593"))
			draw_line(cover.position+Vector2(fold,-5),cover.position+Vector2(fold,cover.size.y),Art.KRAFT,1,true)
		draw_string(font,Vector2(paper.position.x,paper.end.y-9),"已揭" if progress[i]>=1 else "%d／3 拖揭" % int(progress[i]*3),HORIZONTAL_ALIGNMENT_CENTER,paper.size.x,13,Art.CHARCOAL)
