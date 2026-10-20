# Changelog

## 0.27.0
- 三案手動揭時、完整原話判定、兩階段錯因、紙卡與街區結果修正。


## 0.26.0｜新內容第十二輪

修正街區對話混入距離、貼件落點、揭時遮罩、三案狀態樣式、合看符號與紙卡固定頂端排版。

## 0.25.0｜新內容第十一輪

- 收據卡與下方說明同步顯示拿起狀態；貼回後才封存。
- 兩種錯選處置各以朱紅框及「你選的」標出，對應各自錯因。
- 索引明列兩份原件與 18：00 分界，交代提供者及定位用途。
- 收據三步共用標題與分頁位置，保護摘要及反查依據的換行。
- 僅修指定四項，保留既有玩法；本機測試與原尺寸證據見 docs/CODEX_RESPONSE_CONTENT_R11.md。

## 0.24.0｜新內容第十輪

- 三份原件以實際連線呈現引用，錯段紅虛線並停用揭時；錯因明寫你選的與應為方向。
- 浮件限制於紙面安全帶、保護詞組換行；逐張揭時後，貼回收據才封存。
- 第一案補清文件先後與並存依據，回放持續蓋章；第三案區分原始紀錄與玩家推論。
- 本機測試與原尺寸證據見 docs/CODEX_RESPONSE_CONTENT_R10.md。

## 0.23.0｜新內容第九輪

- 收據改為具名引用箭頭、逐段原文核對；浮件完整遮時標籤與三落點預覽。
- 封存後回來源可看 NPC 處置與留存原件；第一案保留有標示的分支回放。
- 全名判定、雙圈合看、單側缺件提示與真正放大；統一選取／錯誤色並整理回顧紙面。
- 保留離線自動存檔、既有測試與原推論界線。新增無頭操作、RWD 與原尺寸截圖證據。

## 0.22.0｜新內容第八輪

- 第一案的三個行動改為等長句，錯選逐句引用甲乙黃標。
- 收據排序格與拖曳預覽同步重排；完整浮件保留引用句與遮時欄。兩段關係的選取進度同屏，缺段不能揭時。
- 首筆、末筆、索引的人名一致；玩家合看不再掛原件書寫者。釘子以依據箭頭對應完整主張，錯釘即時指出原因。
- 已封存案件可唯讀重看自己的證據鏈、選擇及錯選回饋，重載後保留。
- 本機回歸、原尺寸證據與限制見 `docs/CODEX_RESPONSE_CONTENT_R8.md`。

## 0.21.0｜新內容第七輪

- 比較雙黃標後親自選付款、留證或指控，錯選不封存。
- 收據拖行牌移出落點區、原位不疊字；排序須核對兩段原文引用關係。
- 明定六點分界，支持「前後都有」須共同引用首末兩筆；判定頁保留原文。
- 封存統一紙面，清單顯示三種結果；不透明遮罩與禁則排字修整。
- 僅本機提交；外部複審、實體裝置與真人試玩仍需補驗。

## 0.7.0 — 反詐案卷與上架準備（R3，本機版本，未發布）

- 開場保存虛構客服訊息，在實際車店取得收據，逐項連結說詞、戶名與判斷；錯選可重試，完成後可重讀。
- 案卷納入主線原子存檔，支援舊存檔；新增冷啟動、原生觸控、背景恢復、跨程序讀回與多視口驗證，開啟選單時立即釋放觸控動作。
- 準備逐款區隔、共用素材稽核、隱私宣告草稿、英文審查備註與真實無頭截圖；未上傳或重送商店。

## 0.6.0 — 手機操作與章節回訪（R2，本機版本，未發布）

- 三份章節回訪各有三站走訪、現場線索、核對選答與人物後記。依序完成解鎖，保存三頁收藏、最佳用時與完成次數，每日推薦輪替已解鎖路線。
- 手機互動鍵依情境顯示交談、記錄或核對；加入短教學、觸控按下回饋，以及拖離取消後的手指隔離，避免誤轉鏡頭。
- 暫停選單改成行動、進度、其他三頁；返回與繼續固定在內容區外。新增回訪單頁卡與後記閱讀入口。
- Web 載入介面改用隨包提供的中文字型子集；重建字型涵蓋新增內容。
- 本輪只做無頭本機驗證及 commit。實際 WebGL 畫面計時採並發載量測，僅供參考，未通過實機出貨效能閘。

## 0.5.0 — 好玩與美觀優化輪（R1，本地版本，未發布）

- 開場：標題畫面改為街景背景＋「斷鏈」標誌與故事鉤子，主按鈕「開始行動」；新增四張可跳過的開場故事卡（虛構「恆曜投資教育」群組騙走阿遠存款、交給美晴），結尾提醒現實可撥 165。
- 導引與回饋：當前目標顯示 3D 光柱＋地面脈衝圈＋浮動箭頭，任務卡顯示目標距離；任務開場橫幅帶出角色台詞；完成目標／任務有提示與音效。
- 招牌玩法：任務卡加入五節「斷鏈」進度，每完成一個主線任務斷一節。
- 打擊感：命中火花、浮動傷害數字、受擊白閃、鏡頭震動、70 ms 骨架停頓、連擊計數、揮擊破風聲；不改傷害與判定窗。
- 重玩：章節結算顯示 S／A／B／C 評價，三種解法各自保存最佳評價（獨立設定檔，不進存檔），提示下一個沒試過的解法。
- 畫面：天空色環境光、glow 與色彩調整、角色邊緣光與鏡頭補光、車店前紅磚鋪面與地面細紋；選單暫停時鏡頭臂持續運作（修正標題背景從主角頭部內部算圖）。
- 介面：任務卡縮為左上窄卡並加安全值條；底部提示改置中膠囊；操作說明 45 秒後收起。觸控指令鈕移出畫面中央、改半透明圓角樣式；直式提示不再蓋住「連跑」。
- 聲音：本機 ACE-Step 生成街區配樂（選單時壓低音量）；新增五個原創合成音效。
- 字型子集重建為 277,324 bytes，涵蓋新文字。版本號 0.5.0。

## 0.4.0 — Taiwan life expansion and independent device profiles

Published: https://seven-district-reckoning.digimkt.workers.dev. Dedicated browser entries are `/phone/`, `/tablet/` and `/desktop/`; Windows x64 download is in the [0.4.0 release](https://github.com/mars-tw/seven-district-reckoning/releases/tag/v0.4.0).

- Expanded fictional 800 × 800 m map retaining the original core and adding eight Taiwan-inspired areas: morning market, night market, convenience street, parcel hub, community greenway, riverside, arcade heritage street and creative lane. Thirty-two stations support actual world interaction.
- Research ledger with 52 opened primary sources across 31 major themes and 98 detailed tags. Original adaptation covers street life, local food, markets, community events, recycling, creative activities and store-to-store parcel flows; third-party street photographs are not redistributed.
- Eight additional named fictional characters, two story episodes each, relationship trust, prerequisite unlocks and seven two-route choices. Eight dedicated Blender/GLB variants use licensed MakeHuman base topology, individualized proportions, clothing and original working accessories, retaining the 53-bone rigs and eight action clips.
- Eighteen repeatable food, convenience-store and parcel jobs with cargo, pickup, simulated code checking, recipient handover, return handling and rewards. The fictional orange parcel station is inspired by researched Shopee-style services; no real account, order, payment or personal-data integration is present.
- Thirteen original Taiwan street asset kits plus three food/store/parcel cargo models, with editable Blender sources, exported GLB/PBR materials and CC0 notices, including arcade shops, food stalls, convenience/parcel buildings, shelters, lanterns, recycling and riverside props. A life album records discovered stations and culture notes.
- Four directly playable culture activities: spinning-top rhythm, alternating clog steps, craft color recipes and a four-station walking/bicycle stamp route. Results, badges and best scores persist without changing delivery cash or character trust.
- Actual phone/tablet/desktop input, HUD, resolution, view-distance, LOD, audio and ambient-actor budgets. Indexed floating touch controls support independent movement, camera and brake fingers, with releases on cancellation, focus/orientation/profile changes and pause. Device preferences remain outside campaign saves.
- Four generated launch documents at `/`, `/phone/`, `/tablet/` and `/desktop/`, each with distinct defaults and instructions while sharing one root engine/PCK/WASM. Fixed profile commands and a jobs menu replace arbitrary browser actions; canvas backing ratios cap at 1.50/1.75/2.00 while respecting the actual device ratio and safe margins.
- Corrected root asset URLs, content-hash cache busting, canonical entry redirects, compressed WASM MIME and unencoded 404 responses. Build/deployment verification rejects stale files, wrong configuration and HTML fallback returned as game resources.
- Final frozen-source evidence: 17 suites / 8,561 checks pass, including 2,698 actual Root scene/UI checks, 245 culture checks and 99 web-shell contracts. The Root matrix completes all 41 shipping story/order/branch routes through 321 real station actions; all 32 stations have connected physical approaches. Public package/entry integrity passes 96 checks. All three modes boot and apply their actual budgets in hosted desktop Chromium/IAB; canvas life-menu interaction and desktop-save continuation through phone/tablet modes retain both position and device profile. This viewport/profile evidence does not certify physical phone/tablet FPS, heat or long sessions.
- An unsigned Windows x64 package embeds its one PCK, retains required runtime/asset notices and passes native PE/version, pack integrity, archive CRC and quiet five-frame original-title headless startup. This package check is distinct from rendered gameplay verification.
- The renamed OFL game font grows to 266,184 bytes (about 260 KiB) for the new text. Alpha 0.3's historical subset was about 191 KiB.

## 0.3.0 — Character, street and gameplay systems update

Published: https://seven-district-reckoning.digimkt.workers.dev.

- Six new human-proportioned characters for the hero, guard, pedestrian, Mei, Yu-an and Zhou. MakeHuman CC0 base meshes, 53-bone rigs and eight movement/action clips are included with editable Blender sources; facial performance and close-up realism remain future work.
- Six new urban assets: three office towers, a shopfront, sidewalk and bench. Floor modules, entrance details, original PBR street materials, crossings, markings and drainage detail improve the existing fictional 300 × 300 m district. This is not a GIS reconstruction of Taichung.
- Sprint stamina and four shop offers: healing, a stamina-cap upgrade, tool-damage improvement and bicycle acceleration tuning. Purchases require proximity to the bike shop and use a separate district-credit ledger.
- Three grant-once district challenges track actual walking distance, distinct side-quest completions and distinct legal tool targets. Vehicle travel, respawn jumps, repeated rewards, civilians and evidence do not count toward the corresponding challenges.
- A destination map, navigation marker, day/night cycle, quality/difficulty presets, camera sensitivity and sound settings. Map clicks set guidance without teleporting. Settings and district progression are saved, with Alpha 0.1/0.2 save compatibility retained.
- Website controls for the map, supplies/challenges and settings, plus a read-only resource summary. Browsers without native fullscreen can expand the game within the page; native rejection and synchronous API errors use the same fallback.
- 1,381 reported engine/gameplay/GUI checks pass, with the complete run and later UI increments documented separately. Character source/GLB validation passes 192 checks, urban assets 121 checks, and public HTTP/package integrity 32 checks. Actual Chrome startup, legacy-save loading, map navigation, night setting, supplies and landscape controls are verified. Real phone hardware and a full human campaign playthrough remain outside this evidence.

## 0.2.0 — Browser play and district expansion

Published: https://seven-district-reckoning.digimkt.workers.dev.

- Single-player Web export using Godot 4.7.2's single-thread template, with a custom game-first shell, genuine loading progress, retry, fullscreen and fixed game UI commands. The existing Windows 0.1.0 download remains available.
- Web camera control uses right-button drag; the native desktop camera retains mouse capture. In-game touch controls include movement, combat, interaction, mount/dismount, jump/brake, tool change, vehicle recovery, camera steps, assignments and pause.
- Six playable side quests and four repeatable activities, with saved completion, separate parts vouchers, street-view collection and personal best times. First-completion and unique photo rewards cannot be collected twice.
- Six surrounding districts inside the existing 300 × 300 m alpha map, eight ambient pedestrians, four moving cars and six parked cars using the shipped art. Ambient actors follow bounded routes and freeze while the game is paused.
- Optional world targets integrated with actual interactions, bicycle/car requirements, timed checkpoints and fully contained, aligned, stationary parking checks. Checkpoint retries and save/load preserve optional outcomes.
- Browser saves remain in IndexedDB for the same browser and site origin. Clearing site data removes them; browser and Windows saves are separate.
- The OFL font is subset and renamed to Seven District Sans TC (about 171 KiB); the original Noto Sans TC source stays in the repository and is excluded from Web export.
- 47 district scene/physics checks, 175 optional-manager/save checks and 214 actual-root integration checks; all 775 reported checks pass including the original baseline suites. Headless/fixture checks do not establish mobile-device performance or a complete human playthrough.

## 0.1.0 — First public alpha

- Godot 4.7.2 project with a third-person controller, camera collision, tool combat, guards, and destructible objects.
- Five first-chapter missions with smash, evidence, and rescue options.
- Driveable car and bicycle with animated wheels, braking, safe dismount, and recovery.
- Traditional Chinese HUD, mission phone, title/pause/chapter screens, minimap, and bundled OFL font.
- Atomic save/backup, inventory/energy/vehicle/guard restoration, and replayable world checkpoints.
- Twenty-five actual Blender/GLB exports with source meshes, license copies, attribution, rig clips, and reproducible tools.
- Engine, contract, control, and independent regression evidence. This alpha is not the full six-zone MVP or completion of all 50 planned tickets.
