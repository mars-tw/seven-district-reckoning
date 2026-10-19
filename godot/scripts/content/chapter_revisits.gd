extends Node
## Short field assignments. Only world proximity advances them; menus never teleport.
## The notebook is a separate collection, with no campaign currency to duplicate.
signal updated
signal notice(text: String)
signal completed(id: String)

const PATH := "user://seven-district-revisits-v1.cfg"
const ROUTES := [
	{"id":"messages", "title":"第一封沒寄出的訊息", "brief":"美晴想知道，失聯的人最後留下了什麼。先回車店，再核對訊息。", "unlock":0,
	 "stops":[Vector3(-56,.1,43),Vector3(-54,.1,59),Vector3(-46,.1,42)],
	 "places":["車店集合點","失聯訊息台","撤離安全點"],
	 "clue":"美晴：訊息寫的是『領回本金前，還要再付一筆保證金』。先把原文留下。",
	 "question":"訊息裡哪一段最需要留下來核對？", "choices":["要求再付保證金的原文","群組頭像的顏色"], "answer":0,
	 "note":"美晴把訊息印在零件單背面。阿遠才發現，自己一直不敢按下的不是送出，而是求助。"},
	{"id":"door", "title":"側門留下的輪班表", "brief":"予安記得側門有人換班。走到側門，核對便條，再回車店交代。", "unlock":1,
	 "stops":[Vector3(-21,.1,-14),Vector3(-40,.15,-26),Vector3(-56,.1,43)],
	 "places":["假客服側門","留言摘要台","車店集合點"],
	 "clue":"予安：側門的人說『晚班接早班』。摘要卻只有白班名字；先查時間，別急著認人。",
	 "question":"兩份說法對不上，下一步先核對什麼？", "choices":["直接把白班名字貼出去","輪班時間與摘要原件"], "answer":1,
	 "note":"予安把白班名字摺進紙裡。『先別讓下一個人被誤認。』阿遠收起扳手，這次先拿筆。"},
	{"id":"handoff", "title":"玻璃後面的回程", "brief":"周成希望有人記下撤離的方法。到前站核對紀錄，最後親自走回安全點。", "unlock":2,
	 "stops":[Vector3(32,.1,25),Vector3(28,.15,19),Vector3(-46,.1,42)],
	 "places":["前站行動台","紀錄 A 原址","撤離安全點"],
	 "clue":"周成：出去後到車店旁的安全點集合。先說清楚集合處，再談設備怎麼處理。",
	 "question":"給還在裡面的人留一句話，哪句能幫他離開？", "choices":["到車店旁的安全點集合","等設備全砸完再找路"], "answer":0,
	 "note":"安全點沒有大門，只有一張長椅。周成先坐下，替下一個走出來的人留了半個位子。"}
]

var persist := true
var records_path := PATH
var records: Dictionary = {}
var active := -1
var step := 0
var elapsed := 0.0
var awaiting_answer := false

func _ready() -> void:
	if persist: load_records()

func unlocked(index: int) -> bool:
	return index >= 0 and index < ROUTES.size() and (index == 0 or records.has(ROUTES[index-1]["id"]))

func start(index: int) -> bool:
	if not unlocked(index) or active >= 0: return false
	active = index
	step = 0
	elapsed = 0.0
	awaiting_answer = false
	updated.emit()
	return true

func cancel() -> void:
	active = -1
	step = 0
	elapsed = 0.0
	awaiting_answer = false
	updated.emit()

func advance(delta: float) -> void:
	if active >= 0 and is_finite(delta) and delta > 0: elapsed = minf(86400.0,elapsed+delta)

func target_position() -> Vector3:
	return ROUTES[active]["stops"][step] if active >= 0 else Vector3.ZERO

func is_near(position_value: Vector3, on_foot: bool = true) -> bool:
	return active >= 0 and on_foot and position_value.is_finite() and position_value.distance_to(target_position()) <= 3.0

func interact_at(position_value: Vector3, on_foot: bool = true) -> String:
	if not is_near(position_value,on_foot): return ""
	if step == 1:
		awaiting_answer = true
		return "question"
	if step == 0:
		notice.emit(ROUTES[active]["clue"])
		step = 1
		updated.emit()
		return "clue"
	var id: String = ROUTES[active]["id"]
	var old: Dictionary = records.get(id,{})
	records[id] = {"runs":mini(9999,int(old.get("runs",0))+1),"best_seconds":minf(float(old.get("best_seconds",86400)),maxf(.1,elapsed))}
	var page: String = ROUTES[active]["note"]
	cancel()
	if persist: save_records()
	notice.emit("後記已收錄｜"+page)
	completed.emit(id)
	return "complete"

func answer(choice: int) -> bool:
	if active < 0 or step != 1 or not awaiting_answer: return false
	if choice != int(ROUTES[active]["answer"]):
		notice.emit("再看看現場線索。答錯不扣分，可以重選。")
		return false
	awaiting_answer = false
	step = 2
	updated.emit()
	return true

func active_text() -> String:
	if active < 0: return ""
	return "回訪 %d／3｜%s" % [step+1,ROUTES[active]["places"][step]]

func recommended(day: int = -1) -> int:
	if day < 0: day = int(Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system())/86400.0)
	var count := 0
	for index: int in ROUTES.size():
		if unlocked(index): count += 1
	return posmod(day,maxi(1,count))

func save_records() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("notebook","records",records)
	return cfg.save(records_path)

func load_records() -> void:
	records.clear()
	var cfg := ConfigFile.new()
	if cfg.load(records_path) != OK: return
	var loaded: Variant = cfg.get_value("notebook","records",{})
	if not loaded is Dictionary: return
	# Validate each entry and require the unlock chain; a malformed page is ignored.
	for route: Dictionary in ROUTES:
		var entry: Variant = loaded.get(route["id"],{})
		if not entry is Dictionary: break
		var runs: Variant = entry.get("runs",0)
		var seconds: Variant = entry.get("best_seconds",0)
		if not (runs is int) or runs < 1 or runs > 9999: break
		if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or seconds <= 0 or seconds > 86400: break
		records[route["id"]] = {"runs":runs,"best_seconds":float(seconds)}
