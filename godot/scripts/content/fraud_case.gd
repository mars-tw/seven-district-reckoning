extends RefCounted
## Entirely fictional, offline evidence. Never accepts personal or banking data.
signal changed

const CLAIMS := ["受款帳戶是恆曜公司專戶", "補繳保證金即可出金", "名額只剩最後三位"]
const PROOFS := ["戶名：林○翔（個人）", "轉帳時間：上週五 14：32", "轉帳金額：三十八萬元"]
const REASONS := ["公司專戶的說詞與個人戶名矛盾", "轉帳在下午，所以一定是詐騙", "金額很大，所以保證能出金"]
const CONCLUSION := "客服聲稱收款的是公司專戶，收據卻列個人戶名。這份矛盾足以質疑說詞，不能證明收款人就是幕後主嫌。先停止轉帳，保存對話與收據，再尋求協助。"
var stage := 0
var selected_claim := -1
var feedback := ""

func reset() -> void:
	stage = 0
	selected_claim = -1
	feedback = ""

func preserve_message() -> bool:
	if stage != 0: return false
	stage = 1
	changed.emit()
	return true

func meet_witness() -> bool:
	if stage != 1: return false
	stage = 2
	feedback = "美晴：先比對戶名，別把客服的保證當證據。"
	changed.emit()
	return true

func select_claim(index: int) -> bool:
	if stage != 2 or index < 0 or index >= CLAIMS.size(): return false
	selected_claim = index
	feedback = ""
	return true

func link_proof(index: int) -> bool:
	if stage != 2 or selected_claim < 0 or index < 0 or index >= PROOFS.size(): return false
	if selected_claim != 0 or index != 0:
		feedback = "時間與金額能留證，卻無法單獨推翻公司專戶的說詞。找出戶名的矛盾。"
		selected_claim = -1
		return false
	stage = 3
	feedback = "兩張證物已連結。它們能支持哪一項判斷？"
	changed.emit()
	return true

func conclude(index: int) -> bool:
	if stage != 3 or index < 0 or index >= REASONS.size(): return false
	if index != 0:
		feedback = "證據能指出說詞矛盾，不能用時間或金額猜測有罪。可以重選。"
		return false
	stage = 4
	feedback = "案卷已封存｜可從暫停的「反詐案卷」重讀。"
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"schema":1,"stage":stage}

static func valid(data: Variant) -> bool:
	return data is Dictionary and data.get("schema") == 1 and (data.get("stage") is int or data.get("stage") is float) and is_finite(float(data["stage"])) and float(data["stage"]) == floorf(float(data["stage"])) and int(data["stage"]) >= 0 and int(data["stage"]) <= 4

func from_dict(data: Dictionary) -> bool:
	if not valid(data): return false
	stage = int(data["stage"])
	selected_claim = -1
	feedback = ""
	return true
