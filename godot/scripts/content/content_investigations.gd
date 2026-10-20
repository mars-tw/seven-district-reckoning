extends RefCounted
## Fictional offline packets. Progress requires on-foot proximity, never a menu grant.
signal changed
const DATA := "res://data/fraud_cases.json"
var definitions: Array = []
var records: Dictionary = {}
var active := ""
var feedback := ""
var street_choice := -1 # Read-only archived action replay; never changes the save.
var street_at_source := false
var game_serial := 0

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	definitions = data["cases"]
	reset()

func reset() -> void:
	game_serial += 1
	active = ""
	street_choice = -1
	street_at_source = false
	feedback = ""
	records.clear()
	for c: Dictionary in definitions:
		records[c.id] = {"collected": [], "order": [], "pairs": {}, "compared": false, "complete": false, "time_revealed": false, "time_checked": false, "reveal_steps": [0,0,0], "citations": {}, "viewed_fields": {}, "pins": [], "pin_choices": {}, "judging": false, "relations": {}, "support_refs": [], "history": []}

func remember(kind: String, index: int, choice: int, message: String = "") -> void:
	if not message.is_empty():
		var prior: Array = entry().history.filter(func(e: Dictionary) -> bool: return e.kind == kind and not e.feedback.is_empty())
		if prior.is_empty(): message = {"action":"甲乙收費條件仍有衝突，回看黃標及備註。","relation":"引用方向讀反，回看『附件：』與『接班依據：』。","pin":"時間與『全部』的說法對不上，回看分界兩側。"}.get(kind,message)
	if choice < 0: return
	entry().history.append({"kind":kind,"index":index,"choice":choice,"feedback":message})
	if entry().history.size() > 128: entry().history.pop_front()

func pin_error(index: int) -> String:
	if not index in entry().pins or entry().pin_choices.get(str(index),-1) == [1,2,0][index]: return ""
	var attempts: int = entry().history.filter(func(e: Dictionary) -> bool: return e.kind == "pin" and e.index == index and not e.feedback.is_empty()).size()
	if attempts <= 1: return "先看這筆在 18：00 哪一側，再核對『全部』。"
	return ["再看陳奕廷的原話：他說的『全部』能容納這筆嗎？","再看吳安琪的原話：單側資料足夠嗎？","再看林秀蘭的原話：她說的『全部』能容納這筆嗎？"][index]

func support_missing() -> String:
	if entry().support_refs == [0]: return "已引用 17：50，只有分界前；還缺末筆 18：10。"
	if entry().support_refs == [2]: return "已引用 18：10，只有分界後；還缺首筆 17：50。"
	return "尚未引用原件。請分別引用首筆、末筆。"

func feedback_is_error() -> bool:
	if feedback.is_empty(): return false
	if feedback.contains("還缺") or feedback.begins_with("尚未"): return false
	return not (feedback.begins_with("已") or feedback.begins_with("矛盾已") or feedback.begins_with("時間與") or feedback.begins_with("此句已") or feedback.begins_with("17：50 是") or feedback.begins_with("18：10 是") or feedback.begins_with("首、末"))

func street_result() -> Dictionary:
	if active.is_empty(): return {}
	if active == "second_help":
		var action := -1
		for event: Dictionary in entry().history:
			if event.kind == "action": action = int(event.choice)
		if entry().complete and street_choice >= 0: action = street_choice
		if action < 0: return {}
		return {"place":"美晴車店","heading":"封存後行動回放" if entry().complete and street_choice > 0 else "美晴的處置｜已封存" if entry().complete else "美晴的處置｜尚待修正", "payment":"已照乙付款（待撤回）" if action == 1 else "已暫停付款", "count":1 if action == 2 else 2,"papers":["乙"] if action == 2 else ["甲","乙"],"line":["美晴：兩份都留著，先不付。","美晴：付了，兩句卻仍對不上。","美晴：只剩乙件，甲的承諾無從比對。 "][action],"replay":entry().complete and street_choice > 0,"choice":action}
	if not entry().complete: return {}
	if active == "before_night": return {"place":"美晴車店","heading":"收據已貼回｜已封存","payment":"晚班猜測已撤回","count":3,"papers":["甲","乙","丙"],"line":"美晴：17：42 已開立，不能再說一定是晚班。","replay":false}
	return {"place":"橘盒取件站","heading":"街坊已核對｜已封存","payment":"前後紀錄都已保留","count":2,"papers":["首筆","末筆"],"line":"吳安琪：六點前後都有，先照紀錄更正說法。","replay":false}

func result_position() -> Vector3:
	if active.is_empty(): return Vector3.ZERO
	var index := 2 if active == "three_voices" else 0
	var pos: Array = definition().documents[index].position
	return Vector3(float(pos[0]),.2,float(pos[1]))

func choose_relation(pair_index: int, choice: int) -> bool:
	if not ready_to_solve() or definition().mode != "timeline" or entry().complete or pair_index < 0 or pair_index > 1 or choice < 0 or choice > 1: return false
	entry().relations[str(pair_index)] = choice
	entry().time_checked = false
	feedback = relation_error(pair_index) if choice != [0,1][pair_index] else "已記下關係選擇。"
	remember("relation",pair_index,choice,feedback if choice != [0,1][pair_index] else "")
	changed.emit()
	return true

func relation_error(index: int) -> String:
	var directions: Array = [["車店收據 → 交接摘要","交接摘要 → 車店收據"],["輪值資料 → 交接摘要","交接摘要 → 輪值資料"]][index]
	var choice: int = entry().relations.get(str(index),-1)
	if choice < 0: return "待補：尚未選擇這段方向。"
	return "錯因：你選的："+directions[choice]+"；原文『"+["附件：車店收據","接班依據：已簽收的交接摘要"][index]+"』表示"+["摘要引用收據","輪值沿用摘要"][index]+"，應為："+directions[[0,1][index]]+"。"

func relations_correct(value: Dictionary) -> bool:
	return value.size() == 2 and value.get("0",-1) == 0 and value.get("1",-1) == 1

func reference_support(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "testimony" or entry().complete or not index in [0,2]: return false
	if not index in entry().support_refs: entry().support_refs.append(index)
	changed.emit()
	return true

func uncite_support(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "testimony" or entry().complete or not index in entry().support_refs: return false
	entry().support_refs.erase(index)
	entry().pins.erase(1)
	entry().pin_choices.erase("1")
	changed.emit()
	return true

func cite(document: int, field: int) -> bool:
	if not ready_to_solve() or definition().mode != "contradiction" or entry().complete: return false
	if document < 0 or document >= definition().documents.size() or field < 0 or field >= definition().documents[document].fields.size(): return false
	var key := str(document)
	if not entry().viewed_fields.has(key): entry().viewed_fields[key] = []
	if not field in entry().viewed_fields[key]: entry().viewed_fields[key].append(field)
	if field == 2: entry().citations[key] = field
	feedback = "已標出收費條件。" if field == 2 else "這是期限說明，不是本案收費條件。" if definition().documents[document].fields[field].begins_with("期限：") else "這是收件說明，不是本案收費條件。" if definition().documents[document].fields[field].begins_with("收件：") else "這是案號，不是收費條件。" if field == 1 else "這是版次備註，不是收費條件。" if field == 3 else "這是機構資料，不是收費條件。"
	changed.emit()
	return true

func pin_record(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "testimony" or entry().complete or index < 0 or index > 2: return false
	if entry().judging and not entry().pin_choices.has(str(index)): return false
	if not index in entry().pins: entry().pins.append(index)
	feedback = pin_error(index)
	remember("pin",index,int(entry().pin_choices.get(str(index),-1)),feedback)
	if not feedback.is_empty() and entry().pin_choices.has(str(index)):
		feedback = pin_error(index)
		entry().history[-1].feedback = feedback
	changed.emit()
	return true

func begin_pin_review() -> void:
	if not ready_to_solve() or definition().mode != "testimony" or entry().complete: return
	entry().judging = true
	changed.emit()

func choose_pin(index: int, choice: int) -> bool:
	if not entry().get("judging",false) or entry().complete or index < 0 or index > 2 or choice < 0 or choice > 2 or index in entry().pins: return false
	if index == 1 and choice == 2 and entry().support_refs.size() != 2:
		feedback = support_missing()
		return false
	entry().pin_choices[str(index)] = choice
	feedback = "已選原話，釘入後核對；仍可拔釘修正。"
	changed.emit()
	return true

func unpin_record(index: int) -> bool:
	if entry().complete or not index in entry().pins: return false
	entry().pins.erase(index)
	entry().pin_choices.erase(str(index))
	feedback = "已拔釘，重新選擇這筆能支持或推翻的說法。"
	changed.emit()
	return true

func pins_correct() -> bool:
	if entry().pins.size() != 3 or entry().support_refs.size() != 2: return false
	for i: int in 3:
		if entry().pin_choices.get(str(i),-1) != [1,2,0][i]: return false
	return true

func seal_records() -> bool:
	if not entry().get("judging",false) or entry().complete or not pins_correct(): return false
	entry().pairs = {"0":[1,1],"1":[0,1],"2":[2,0]}
	return _finish()

func definition(id: String = "") -> Dictionary:
	if id.is_empty(): id = active
	for c: Dictionary in definitions:
		if c.id == id: return c
	return {}

func entry() -> Dictionary:
	return records.get(active,{})

func start(id: String) -> bool:
	if not records.has(id): return false
	active = id
	street_choice = -1
	feedback = ""
	changed.emit()
	return true

func suspend() -> void:
	active = ""
	changed.emit()

func pending() -> int:
	if active.is_empty() or entry().complete: return -1
	for i: int in definition().documents.size():
		if not i in entry().collected: return i
	return -1

func target_position() -> Vector3:
	var i := pending()
	if i < 0: return Vector3.ZERO
	var p: Array = definition().documents[i].position
	return Vector3(p[0],.2,p[1])

func nearby(point: Vector3, on_foot: bool = true) -> bool:
	return pending() >= 0 and on_foot and point.is_finite() and point.distance_to(target_position()) <= 3.0

func collect(point: Vector3, on_foot: bool = true) -> int:
	if not nearby(point,on_foot): return -1
	var i := pending()
	entry().collected.append(i)
	feedback = "已留存原文。讀完後可收起案卷，跟著導引找下一份。"
	changed.emit()
	return i

func ready_to_solve() -> bool:
	return not active.is_empty() and entry().collected.size() == definition().documents.size()

func add_time(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "timeline" or entry().complete or index < 0 or index >= 3 or index in entry().order: return false
	entry().order.append(index)
	entry().time_checked = false
	feedback = ""
	changed.emit()
	return true

func undo_time() -> void:
	if not active.is_empty() and not entry().complete and not entry().order.is_empty():
		entry().order.pop_back()
		entry().time_checked = false
		feedback = "已撤回最後一張，可以重新排序。"
		changed.emit()

func place_time(index: int, slot: int) -> bool:
	# A drag moves an existing card or inserts an unplaced card at the drop slot.
	if not ready_to_solve() or definition().mode != "timeline" or entry().complete or index < 0 or index > 2 or slot < 0 or slot > 2: return false
	entry().order.erase(index)
	entry().order.insert(mini(slot,entry().order.size()),index)
	entry().time_checked = false
	feedback = ""
	changed.emit()
	return true

func document_text(index: int) -> String:
	var text: String = definition().documents[index].text
	if definition().mode == "timeline" and not entry().time_revealed:
		for value: String in ["17：42","17：55","18：00"]:
			text = text.replace(value,"〔確認後揭時〕")
	return text

func verify_time() -> bool:
	if not ready_to_solve() or definition().mode != "timeline" or entry().complete: return false
	if entry().order.size() != 3:
		feedback = "先依事件關係放入三張，再揭時核對。"
		return false
	entry().time_checked = false
	if not relations_correct(entry().relations):
		feedback = relation_error(0 if entry().relations.get("0",-1) != 0 else 1)
		changed.emit()
		return false
	entry().time_revealed = true
	entry().time_checked = _correct_order(entry().order)
	if not _correct_order(entry().order):
		feedback = "乙附甲收據，丙沿用乙摘要；引用件須在前。可局部拖回。"
		changed.emit()
		return false
	if not entry().time_checked:
		feedback = "讀反『附件：車店收據』：收據 → 摘要。" if entry().relations.get("0",-1) != 0 else "讀反『接班依據：已簽收的交接摘要』：摘要 → 輪值。"
		for pair_index: int in 2:
			if entry().relations.has(str(pair_index)) and entry().relations[str(pair_index)] != [0,1][pair_index]:
				remember("relation",pair_index,int(entry().relations[str(pair_index)]),feedback)
		changed.emit()
		return false
	entry().reveal_steps = [0,0,0]
	feedback = "引用方向已選，時間待核對。親手揭開三張原件。"
	changed.emit()
	return true

func reveal_time(index: int, step: int) -> bool:
	if active != "before_night" or entry().complete or not entry().time_checked or index < 0 or index > 2 or step < 0 or step > 3: return false
	entry().reveal_steps[index] = step
	changed.emit()
	return true

func seal_time(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "timeline" or entry().complete or not entry().time_checked: return false
	if index != 0:
		feedback = "甲沒有經手人姓名。時間只能推翻『一定是晚班開的』。"
		return false
	return _finish()

func compare_choice(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "contradiction" or entry().complete: return false
	if index < 0 or index >= definition().choices.size(): return false
	if index != int(definition().answer):
		feedback = definition().retry
		return false
	entry().compared = true
	feedback = "矛盾已確認。這還不能確認身分；接著選擇現在的行動。"
	changed.emit()
	return true

func choose_action(index: int) -> bool:
	if not ready_to_solve() or definition().mode != "contradiction" or entry().complete or not entry().compared: return false
	if index < 0 or index >= definition().action_choices.size(): return false
	if index != int(definition().action_answer):
		feedback = definition().get("action_retries",{}).get(str(index),definition().action_retry)
		remember("action",0,index,feedback)
		changed.emit()
		return false
	if entry().citations.get("0",-1) != 2 or entry().citations.get("1",-1) != 2:
		feedback = "先同時標出甲的承諾、乙的要求，才能以兩份原文支持這個行動。"
		return false
	remember("action",0,index)
	return _finish()

func time_cards() -> Array:
	# Deliberately non-chronological, stable across resume and redraw.
	return [2,0,1]

func pair(statement: int, document: int, verdict: int) -> bool:
	if not ready_to_solve() or definition().mode != "testimony" or entry().complete or statement < 0 or statement >= 3 or document < 0 or document >= 3 or verdict < 0 or verdict > 1: return false
	if not _correct_pair(definition(),statement,document,verdict):
		feedback = "這份文件還不能支持這個判斷。核對時間與『全部』兩字，可直接重配，不扣分。"
		return false
	entry().pairs[str(statement)] = [document,verdict]
	feedback = "此句已核對。繼續交叉比對另外兩句。"
	if entry().pairs.size() == 3 and not entry().judging: return _finish()
	changed.emit()
	return true

func _finish() -> bool:
	entry().complete = true
	feedback = "已封存｜"+definition().conclusion
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"schema":1,"active":active,"records":records.duplicate(true)}

func _correct_order(order: Array) -> bool:
	return order.size() == 3 and order[0] == 0 and order[1] == 1 and order[2] == 2

func _whole(value: Variant, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(value) and value >= 0 and value <= high

func _correct_pair(c: Dictionary, statement: int, document: int, verdict: int) -> bool:
	if verdict != int(c.pair_verdicts[statement]): return false
	if document == int(c.pair_documents[statement]): return true
	# The complete index is also a valid counterexample to either 'all' claim.
	for alternate: Variant in c.get("alternate_documents",{}).get(str(statement),[]):
		if document == int(alternate): return true
	return false

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1 or not value.get("records") is Dictionary or not value.get("active") is String: return false
	if value.active != "" and not records.has(value.active): return false
	if value.records.size() != definitions.size(): return false
	for c: Dictionary in definitions:
		var r: Variant = value.records.get(c.id)
		if not r is Dictionary or not r.get("complete") is bool or not r.get("collected") is Array or not r.get("order") is Array or not r.get("pairs") is Dictionary: return false
		if not r.get("reveal_steps",[0,0,0]) is Array or r.get("reveal_steps",[0,0,0]).size() != 3: return false
		for step: Variant in r.get("reveal_steps",[0,0,0]):
			if not _whole(step,3): return false
		if not r.get("history",[]) is Array or r.get("history",[]).size() > 128: return false
		for event: Variant in r.get("history",[]):
			if not event is Dictionary or event.size() != 4: return false
			if not event.get("kind") in ["action","relation","pin"] or not _whole(event.get("index"),2) or not _whole(event.get("choice"),2) or not event.get("feedback") is String: return false
			if event.feedback.length() > 512 or r.collected.size() != c.documents.size(): return false
			if event.kind == "action" and c.mode != "contradiction" or event.kind == "relation" and c.mode != "timeline" or event.kind == "pin" and c.mode != "testimony": return false
		if not r.get("pin_choices",{}) is Dictionary: return false
		if not r.get("relations",{}) is Dictionary or not r.get("support_refs",[]) is Array: return false
		for key: Variant in r.get("relations",{}):
			if c.mode != "timeline" or not key in ["0","1"] or not _whole(r.relations[key],1): return false
		var refs: Array = r.get("support_refs",[])
		if not refs.is_empty() and c.mode != "testimony": return false
		if refs.size() > 2: return false
		if (not r.get("relations",{}).is_empty() or not refs.is_empty()) and r.collected.size() != c.documents.size(): return false
		for ref_index: Variant in refs:
			if not _whole(ref_index,2) or not int(ref_index) in [0,2] or refs.count(ref_index) != 1: return false
		if r.get("time_checked",false) and r.has("relations") and not relations_correct(r.relations): return false
		if r.get("pin_choices",{}).get("1",-1) == 2 and r.has("support_refs") and refs.size() != 2: return false
		if not r.get("pin_choices",{}) is Dictionary or not r.get("judging",false) is bool or not r.get("pins",[]) is Array: return false
		if r.get("judging",false) and c.mode != "testimony": return false
		for key: Variant in r.get("pin_choices",{}):
			if c.mode != "testimony" or not key in ["0","1","2"] or not _whole(r.pin_choices[key],2): return false
		if r.get("judging",false) and r.complete:
			if r.get("pins",[]).size() != 3: return false
			for i: int in 3:
				if r.pin_choices.get(str(i),-1) != [1,2,0][i]: return false
		if not r.get("citations",{}) is Dictionary or not r.get("viewed_fields",{}) is Dictionary or not r.get("pins",[]) is Array: return false
		for key: Variant in r.get("citations",{}):
			if not key in ["0","1"] or c.mode != "contradiction" or not _whole(r.citations[key],c.documents[int(key)].fields.size()-1): return false
		for key: Variant in r.get("viewed_fields",{}):
			if not key in ["0","1"] or c.mode != "contradiction" or not r.viewed_fields[key] is Array: return false
			var seen_fields: Array = []
			for field: Variant in r.viewed_fields[key]:
				if not _whole(field,c.documents[int(key)].fields.size()-1) or field in seen_fields: return false
				seen_fields.append(field)
		var seen_pins: Array = []
		for pin: Variant in r.get("pins",[]):
			if c.mode != "testimony" or not _whole(pin,2) or pin in seen_pins: return false
			seen_pins.append(pin)
		if (not r.get("citations",{}).is_empty() or not r.get("viewed_fields",{}).is_empty() or not r.get("pins",[]).is_empty()) and r.collected.size() != c.documents.size(): return false
		var compared: Variant = r.get("compared",r.complete and c.mode == "contradiction")
		if not compared is bool: return false
		if compared and (c.mode != "contradiction" or r.collected.size() != c.documents.size()): return false
		if c.mode == "contradiction" and r.complete and not compared: return false
		var revealed: Variant = r.get("time_revealed",r.complete and c.mode == "timeline")
		var checked: Variant = r.get("time_checked",r.complete and c.mode == "timeline")
		if not revealed is bool or not checked is bool: return false
		if (revealed or checked) and (c.mode != "timeline" or r.collected.size() != c.documents.size()): return false
		if checked and (not revealed or not _correct_order(r.order)): return false
		if c.mode == "timeline" and r.complete and not checked: return false
		for list: Array in [r.collected,r.order]:
			var seen: Array = []
			for i: Variant in list:
				if not (i is int or i is float) or not is_finite(float(i)) or float(i) != floorf(i) or i < 0 or i >= c.documents.size() or i in seen: return false
				seen.append(i)
		if c.mode != "timeline" and not r.order.is_empty(): return false
		if c.mode != "testimony" and not r.pairs.is_empty(): return false
		for key: Variant in r.pairs:
			if not key in ["0","1","2"]: return false
			var index := int(key)
			var pair_value: Variant = r.pairs[key]
			if not pair_value is Array or pair_value.size() != 2: return false
			if not _whole(pair_value[0],2) or not _whole(pair_value[1],1): return false
			if not _correct_pair(c,index,int(pair_value[0]),int(pair_value[1])): return false
		if (not r.order.is_empty() or not r.pairs.is_empty() or r.complete) and r.collected.size() != c.documents.size(): return false
		if r.complete and c.mode == "timeline" and not _correct_order(r.order): return false
		if r.complete and c.mode == "testimony" and r.pairs.size() != 3: return false
		if not r.complete and c.mode == "testimony" and r.pairs.size() == 3 and not r.get("judging",false): return false
	return true

func from_dict(value: Dictionary) -> bool:
	if not valid(value): return false
	active = value.active
	records = value.records.duplicate(true)
	for id: String in records:
		var record: Dictionary = records[id]
		record["reveal_steps"] = record.get("reveal_steps",[3,3,3] if record.complete else [0,0,0])
		record.reveal_steps = record.reveal_steps.map(func(step: Variant) -> int: return int(step))
		record["history"] = record.get("history",[])
		for event: Dictionary in record.history:
			event.index = int(event.index); event.choice = int(event.choice)
		record["relations"] = record.get("relations",{"0":0,"1":1} if record.get("time_checked",record.complete and definition(id).mode == "timeline") else {})
		for key: String in record.relations: record.relations[key] = int(record.relations[key])
		record["support_refs"] = record.get("support_refs",[0,2] if record.get("pin_choices",{}).get("1",-1) == 2 else [])
		record.support_refs = record.support_refs.map(func(i: Variant) -> int: return int(i))
		record["citations"] = record.get("citations",{})
		record["viewed_fields"] = record.get("viewed_fields",{})
		record["pins"] = record.get("pins",[])
		record["pin_choices"] = record.get("pin_choices",{})
		record["judging"] = record.get("judging",false)
		for key: String in record.pin_choices: record.pin_choices[key] = int(record.pin_choices[key])
		for key: String in record.citations: record.citations[key] = int(record.citations[key])
		for key: String in record.viewed_fields: record.viewed_fields[key] = record.viewed_fields[key].map(func(i: Variant) -> int: return int(i))
		record.pins = record.pins.map(func(i: Variant) -> int: return int(i))
		record["compared"] = record.get("compared",record.complete and definition(id).mode == "contradiction")
		record["time_revealed"] = record.get("time_revealed",record.complete and definition(id).mode == "timeline")
		record["time_checked"] = record.get("time_checked",record.complete and definition(id).mode == "timeline")
		record.collected = record.collected.map(func(i: Variant) -> int: return int(i))
		record.order = record.order.map(func(i: Variant) -> int: return int(i))
		for key: String in record.pairs:
			record.pairs[key] = record.pairs[key].map(func(i: Variant) -> int: return int(i))
	feedback = ""
	street_choice = -1
	street_at_source = false
	return true
