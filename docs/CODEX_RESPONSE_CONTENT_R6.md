# 七期：斷鏈行動｜新內容第六輪交付

VERIFIED｜版本 **0.20.0**。2026-10-19 執行 2026-10-18 工作單，本機 main 分支。本輪依 `CONTENT_REVIEW_R5_MUSE.md` 五項驗收修整三宗既有新案。

三案入口：「暫停 → 查證 → 街坊查證簿・三宗新案」。先走訪現場留存原文，再回案卷推論。人物、機構與案件均為虛構，內容只處理識破矛盾與保留依據。

- **第二次求助，第二次收費**：甲新增期限、收件句，乙新增期限、聯絡句；與原文一樣可直接點選。點錯只留查看底線及欄位說明，不會新增或取代黃標。甲乙兩個收費句都標好，才開放核對及暫停付款封存。
- **晚班之前的收據**：上方只留待放原件，下方三格是唯一排序區。拿起的原件跟隨觸點、有陰影及微幅放大；原位保留虛線框與文件簡稱。預定格整格填黃，寫明「放下後：第 X 格」。文件關係句跟著原件，放下立即更新「目前」。保留點選替代、改排、撤回與打亂待放牌位；揭時後把收據貼在輪值資料旁。
- **三張嘴，一句真話**：每筆先選「推翻林／推翻陳／支持吳」，再釘入紀錄帶。可先釘入錯判、拔釘重選，不扣分；三筆相符才開放封存。實際選擇寫入存檔，封存勾叉從這份選擇讀回。封存頁撤下風格不一致的寫實簿冊插畫，沿用案卷紙面。

## Muse 五項驗收與原尺寸證據

審查只需開啟 [15 張精選圖](content/r6/review-set/)，每案五張。每張都是 390×844 原圖的位元組相同複本；沒有縮放、拼貼、後製游標或補畫標記。[圖集索引與雜湊](content/r6/review-set.json)。

| 五項驗收 | 操作結果與證據（皆位於 `docs/content/r6/`） |
| --- | --- |
| ①同頁錯點不前進，收費句才黃標 | 精選 01 `phone-second_help-wrong-sentence.png` 為錯點期限，02 `phone-second_help-paper-a-marked.png` 是同頁正確黃標；兩張核對鍵均禁用。03 `phone-second_help-paper-b-marked.png` 補上乙件後才開放。乙錯點另見 `phone-second_help-paper-b-wrong-sentence.png`。 |
| ②拖行牌、插入線、目標格同步 | 精選 06–08：`phone-before_night-drag-preview-{1,2,3}.png`。同一原件依序跟隨左、中、右觸點；原位虛線、整格黃底與落點文字同時保留。 |
| ③唯一排序區，沒有上方第二套答案 | 三張放入後，上方只顯示原件已放完。`phone-before_night-middle-to-left.png`、`phone-before_night-arranged.png` 保留任意錯序、改排與逐格一致的「目前」。精選 06–08 也是從已放原件直接拖回改排。 |
| ④玩家先判定再釘，錯判可重選 | 精選 11 `phone-three_voices-judgment-before-pin.png`：未選前不能釘。12 `phone-three_voices-judgment-chosen.png`：末筆已選推翻林、尚未釘。13 `phone-three_voices-player-results.png`：三筆保留玩家結果、尚未封存。錯釘及重選另見 `phone-three_voices-wrong-pin.png`、`phone-three_voices-pinning-last.png`。 |
| ⑤三案封存與從清單重開相同 | 精選 04／05、09／10、14／15 分別是各案 `phone-<案件>-sealed.png` 與 `phone-<案件>-reopened.png`。重開頁標明「封存回顧」，黃標／暫停付款、完整順序／貼件位置、紀錄帶／勾叉均保留。 |

第一案案號查看底線另見 `phone-second_help-wrong-field.png`；紙上黃標經實際冷重載後見 `phone-second_help-paper-a-reloaded.png`。第二案另留 `phone-before_night-shuffled.png`；`phone-before_night-arranged.png` → `phone-before_night-undo.png` → `phone-before_night-tap-alternative.png` 是同一觸控流程的放滿、撤回後空出末格、點牌補回三張對照。三案 `phone-<案件>-sealed-reloaded.png` 是全部完成後的 IndexedDB 冷重載回顧。畫面以外的操作與磁碟讀回證據保存在 [manifest](content/r6/manifest.json)。不把單張圖當作「曾經重載」的充分證明。

## 測試與來源

VERIFIED｜Godot 完整 **36 套、67,450 項檢查，零失敗**；包含匯入解析、主線整合、全部既有回歸及新增 R6。[完整 Godot 測試](content/r6/final-tests.json)。測試來源與 Web 匯出來源指紋一致。

VERIFIED｜Web 六種視口 390×844、320×568、1290×2796、2064×2752、844×390、1024×768，均實際觸控完成三案，通過 44px 命中區、控制與文字邊界／重疊、存檔及冷重載檢查。共 **110 張原圖**，讀回驗證 **362 個顯示字元**，外站請求及瀏覽器錯誤零筆。撤回補圖另以同一個 390×844 觸控流程擷取三張前後對照，同一份 PCK、未合成。[撤回序列](content/r6/undo-sequence.json)、[總驗證](content/r6/verification.json)。這些是瀏覽器視口驗證。

既有測試與斷言保留。R1 操作路徑改為檢查錯點時核對鍵禁用，並逐筆選判定再釘件；保留原本錯答不得前進、正常完成與自動存檔斷言。新增 R6 檢查錯句不標黃、正確黃標不被錯點覆蓋、逐筆判定、拔釘、顯式封存、磁碟重載、損壞存檔拒絕、唯一排序區、跟隨觸點及九種尺寸版面。拖起後回到起點 8px 內仍持續跟隨，也有獨立斷言。

Web 測試使用既有 Playwright 腳本路線，headless Chromium 加工作單指定的四個 ANGLE D3D11／GPU 旗標。測試以可見控制的實際觸控完成三案；只用真正 Godot 無頭世界產生的未完成近來源快照省略長距離旅行，先前在瀏覽器完成的案件紀錄會保留，不注入目標案完成狀態。未宣稱全程靠移動輸入走完街區。[快照證據](content/r6/fixture-generation.json)。

所有 Godot 都以 `--headless` 執行，沒有開編輯器視窗；實際引擎為 **4.7.stable.official.5b4e0cb0f**。獨立來源快照使用受管版本的 export、touch 與設定，不納入他人草稿。開始時列入保護的 **233 個**檔案保留原樣。VERIFIED：既有秘密掃描器與指定金鑰模式均零命中；只讀待提交索引，沒有讀取憑證目錄。

## 美術、商店圖與缺件

新增生成美術 **0 張**。沿用既有生成紙張、人物、街景、字型及授權；本輪新增的是操作排字、虛線、拖行陰影與落點回饋。未把介面圖形當成新人物或完成美術。規格沿用 `docs/art/ART_DIRECTION.md`，未修改既有骨架或角色造型。

新增商店原圖 **4 張**：`docs/store/screenshots/{1290x2796,2064x2752}-content-r6-{before_night-attachment-picked,three_voices-judgment-chosen}.png`，由同尺寸實拍原圖複製，沒有刪除既有商店圖。[商店圖讀回](store/screenshots/CONTENT_R6_STATUS.json)。

**Apple 4.3 風險：中，屬產品評估。** 都市現場、紙內判斷、遮時文件關係及逐筆有界反證有明確題材差異，沒有換血量或套用通用養成模板；仍有文字閱讀比重與街景精度差距，未取得本輪外部複審及實機證據。依 [Apple 官方 4.3](https://developer.apple.com/app-store/review/guidelines/#spam) 對相同 App 重複提交及缺乏可辨識差異的要求判斷，2026-10-19 查閱，不代表商店核准。

**BLOCKED：Muse ≥8 複審、實體 iPhone／iPad／Android、真人試玩。** 需要審查員、裝置及測試者，未捏造分數或裝置結果。效能依本線工作單另案處理，本輪沒有 p95 ≤18ms 宣稱。人物與紙面插畫的精度差距沿用既有美術驗收邊界。

本輪只做本機 commit；沒有 push、部署、操作商店後台、派工或傳訊。未新增廣告、付費、外連、SDK、帳號或線上功能。

speak-human-tw mode 2 摘要：原「已選」會涵蓋錯欄，容易誤以為已完成判斷，改為錯點欄位原因、正確句黃標與缺件提示；原上方三張牌與下方答案並存，改為「待放原件」及唯一排序區；原「把三筆逐一釘上」只描述動作，改為「先判定，再釘入紀錄帶」。虛構案號、原件承諾、時間、姓名及推論界限保留。
