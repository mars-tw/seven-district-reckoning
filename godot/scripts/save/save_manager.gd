class_name AlphaSave
extends RefCounted
## User-local schema-1 save envelope. Loading never repairs or overwrites damaged files.

static var last_message: String = ""


static func _slot_path(slot: int) -> String:
	return "user://save%d.json" % slot


static func _read_envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8 * 1024 * 1024:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("schema", 0) != 1 or not envelope.get("data", null) is Dictionary:
		return {}
	if envelope["data"].get("schema", 1) != 1:
		return {}
	return envelope


static func save_state(data: Dictionary, slot: int = 1) -> Error:
	if slot < 1 or slot > 99 or (data.has("schema") and data["schema"] != 1):
		last_message = "存檔版本或欄位不支援，現有檔案已保留。"
		return ERR_INVALID_DATA
	var path := _slot_path(slot)
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	# Explicit save requests still preserve a corrupt primary for recovery or diagnosis.
	if FileAccess.file_exists(path) and _read_envelope(path).is_empty():
		last_message = "原存檔損毀或版本不支援，已保留原檔。可繼續遊玩，請先備份並移開原檔再儲存。"
		return ERR_FILE_CORRUPT
	var envelope := {"schema": 1, "saved_at": Time.get_datetime_string_from_system(true), "data": data.duplicate(true)}
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_message = "無法建立暫存檔；現有存檔已保留。"
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_envelope(temp_path).is_empty():
		DirAccess.remove_absolute(temp_path)
		last_message = "存檔寫入未完成；現有存檔已保留。"
		return write_error if write_error != OK else ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			last_message = "無法建立備份；現有存檔已保留。"
			return backup_error
	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		last_message = "無法完成存檔替換；原檔與備份已保留。"
		return rename_error
	last_message = "已儲存。"
	return OK


static func load_state(slot: int = 1) -> Dictionary:
	if slot < 1 or slot > 99:
		last_message = "存檔欄位不支援。"
		return {}
	var path := _slot_path(slot)
	var envelope := _read_envelope(path)
	if not envelope.is_empty():
		last_message = "已讀取存檔。"
		return envelope["data"].duplicate(true)
	var backup := _read_envelope(path + ".bak")
	if not backup.is_empty():
		last_message = "已讀取上一份有效備份；原存檔保持原樣。"
		return backup["data"].duplicate(true)
	last_message = "存檔損毀或版本不支援，原檔已保留。" if FileAccess.file_exists(path) else "還沒有可讀取的存檔。"
	return {}
