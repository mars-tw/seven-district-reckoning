# 七期：斷鏈行動｜新內容第十三輪

PREPARED｜main｜0.26.0 → 0.27.0。已讀共用規則、AGENTS、game-optimization-round、token-efficient-ai-dispatch、繁中文案技能、R11／R12 三位評審全部意見與 R12 交付、美術規格。沒有 CLAUDE.md 或 AUDIT_full.md。只做本機 commit；不派工、不推送、不開可見視窗。

共同入口：暫停 → 查證 → 街坊查證簿・三宗新案。

| Muse R12 唯一驗收項目 | 設計／驗收／預計證據 |
|---|---|
| 1．親手揭時 | 三張紙材遮時貼可水平拖動、長按逐步揭開，鬆手停止，往回拖可遮回。每張三分之一、三分之二、全開，未全開貼件停用；原時間完整顯示。`phone-before_night-reveal-*.png`，測試停住、回遮、完成與存檔。 |
| 2．第三案先呈現完整原話 | 判定卡顯示人物全名、完整原話、所用時間；18：00 是獨立灰色虛線「分界，不是原件」。釘帶列出人名與主張。`phone-three_voices-judgement-*.png`、錯釘及修復圖。 |
| 3．第一案完整閉環 | 必須親手標甲乙收費句，三個同句式處置輪換位置；理由不足不能封存。封存同時列甲乙原句、處置與錯選。`phone-second_help-paper-b-*.png`、sealed。 |
| 4．兩段式錯因 | 每案首次錯選只給核對線索，第二次才展開對照；錯選與當時提示保存。第二、三案局部修正保留已完成操作。`phone-*-first-error.png`／second-error 與冷重載。 |
| 5．紙卡與街區結果 | 紙卡延伸至安全區，黑邊 ≤ 畫面 5%，自動檢查包含紙外區。三案結果分別呈現雙原件留存、收據歸位、前後紀錄並列；同機位前／中／後及重載。現有紙材與模型可覆用，不以幾何占位冒充新美術。 |

併修 R12 逐項問題：讀檔訊息 1.5 秒內消失、不被刷新復活；體力留在獨立 HUD；美晴使用既有高解析角色資產與一致姓名牌；提示列統一「互動」。紙卡黃框留 4px 安全距、標題「原件」獨立行、不讓分隔號落行首。未完成改墨色，已引用與正確加厚左線，封存結論預設選取。決策頁能重開完整原件並保持標記、錯選、當前頁。

預計修改：`godot/scripts/content/content_investigations.gd`、`investigation_field.gd`、`godot/scripts/ui/{investigation_panel,investigation_paper,investigation_time_mask,game_hud}.gd`、必要街區模型引用／字型子集、版本文件、`tests/content_r13.gd`、既有測試必要新互動步驟（不刪除或放寬斷言）、`tools/test_game.py`、`tools/content_r13_*`、本輪證據、兩張商店原圖與交付報告。

所有既存未提交檔記錄 SHA-256；隔離快照對受保護追蹤檔採 HEAD。不動 `.gitignore`、export presets、touch controls、qa JSON、native 或其他既有未追蹤檔。清理只刪已追蹤、已被取代的舊輪圖片／影片；保留商店圖、Markdown、測試讀取檔及未追蹤檔，列精確清單、數量、位元組，之後重跑全套。

八面向沿用驗證：美術與場景同風格、按鈕 ≥44px／界內不交疊、選單可返回、人物有臉、模型保留真骨架、技能與確認回饋不退步、色彩守門、原動畫回歸。Godot 全程無頭；同來源 Web 匯出用單一 headless Chromium，六視口實際操作、完成、冷重載與零外連。原尺寸 PNG 放 r13，review-set 15 張每案 5 張；商店新增 1290×2796 與 2064×2752。

實體裝置、真人試玩、乾淨機況效能、Muse 實際複評為 BLOCKED，需設備、測試者／審查員。並發 p95 三跑中位僅參考。秘密掃描零命中、保護檔雜湊未變後，git add 每批至多十個明確路徑，繁中 commit。

EXECUTED｜執行調整：確認美晴原皮膚為 128×128 斜紋材質後，使用 `image_gen.imagegen` 新製 1 項皮膚 diffuse；保留 1254×1254 原始檔，執行時為 512×512。貼件框改成紙卡容器外的獨立疊層，另加框線與標題至少相距 4px 的座標斷言。均屬原驗收中的臉部與壓字問題，未擴增案件或原生功能。
