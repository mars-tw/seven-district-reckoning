# 隱私與政策核對

版本 0.7.0。VERIFIED：本輪原始碼與本機既有未簽章來源清單。BLOCKED：最新簽章 iOS／Android 成品、實機封包與商店現行宣告。沒有登入或修改商店。

## 實際行為

| 路徑 | 用途與資料 | 傳出裝置？ |
|---|---|---|
| `godot/scripts/save/save_manager.gd` | 本機主線／角色／案卷存檔；暫存、備份與讀回驗證 | 否 |
| `content/chapter_revisits.gd`、`systems/run_records.gd`、`device_profiles.gd` | 本機後記、最佳紀錄與操作偏好 | 否 |
| `content/fraud_case.gd` | 固定虛構說詞、遮名收據與判讀階段；沒有輸入個資欄位 | 否 |
| `main.gd` 的 JavaScriptBridge | Web 外殼與同頁 Godot 的裝置／遊戲狀態橋接 | 同頁記憶體，無上傳呼叫 |
| Web 入口與 Cloudflare worker | 下載同來源 JS、WASM、PCK、字型、圖示與靜態頁；主機會接收到必要的網路連線資訊 | Web 首次載入需要同來源請求；不能把網站說成完全不連網 |
| Web 頁尾 GitHub 連結 | 使用者點選後瀏覽原始碼／授權／下載頁 | 點擊才前往 GitHub；不是遊戲自動追蹤 |

遊戲腳本未發現 HTTPRequest、HTTPClient、WebSocket、ENet、Firebase、分析、廣告、登入或購買 SDK；沒有相機、麥克風、通訊錄或定位 API 使用。原生匯出設定的 internet／access_network_state／record_audio／外部儲存權限均為 false，但這些設定是原有未提交工作，本輪沒有把它們當已發布成品。

離線：無頭 Godot 原生流程直接讀隨包素材，沒有網路前置條件。瀏覽器證據另阻擋所有非本機來源請求。這不能代替手機飛航模式、背景恢復與簽章成品的封包驗證；Web 初次下載不支援斷網冷開。

## iOS PrivacyInfo.xcprivacy

本 repo 沒有已受管且對應 0.7.0 的原生送審包。唯讀檢查既有 `deliverables/native/ios/PrivacyInfo.xcprivacy`：`NSPrivacyTracking=false`；檔案時間戳 DDA9.1／C617.1、開機時間 35F9.1、磁碟空間 E174.1／85F4.1。這些是引擎 required-reason API 宣告，與本機檔案／計時用途分開記錄，不等於收集個資。

既有來源證明 `release/ios/source-verification.json` 標記 Windows 匯出、未簽章、未編譯裝置 archive，不能冒稱新版本的最終清單。清單沒有 tracking domains 或 collected data 條目；未看到收集行為，但上架前仍須核對所有 SDK 與最終 app bundle。

外部唯讀工具 `native-kit/ci_verify_godot_ios.py` 會核對 Tracking 與上述 API reasons，及來源／成品 manifest 雜湊；它沒有驗證所有 collected-data 條目，不能單憑此工具宣稱完整隱私審查通過。本輪未修改 native-kit。

依 [Apple 隱私清單文件](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)，應在實際 app 與其 SDK 包中核對清單；本輪只完成上述來源稽核。

## Google 資料安全草稿

| 欄位 | 依目前遊戲原始碼擬答 |
|---|---|
| 是否收集使用者資料 | 否；本機存檔沒有傳送給開發者 |
| 是否與第三方分享資料 | 否 |
| 廣告／追蹤／分析 | 無 |
| 是否建立帳號 | 否 |
| 帳號刪除 | 不適用；沒有帳號 |
| 本機紀錄刪除 | 由作業系統清除 App 資料／解除安裝；iOS 備份是否保留由系統設定決定 |
| 傳輸加密 | 原生遊戲無應用層傳輸，非「已驗證所有傳輸均加密」；網站靜態下載另行處理 |

此表是 PREPARED，沒有讀回 Play Console 現行答案。Google 要求宣告涵蓋 App 與 SDK 的實際行為，提交前須依最終 AAB 核對。[Google Data safety 說明](https://support.google.com/googleplay/android-developer/answer/10787469)

## 缺件

- 0.7.0 簽章成品、iOS 清單與 AAB manifest 的 hash／版本讀回。
- Android 與 iOS 飛航模式冷啟動、真實背景／回前景、強制關閉重開測試。
- 商店現行隱私宣告及穩定公開隱私政策網址；本輪僅準備 `PRIVACY_POLICY_ZH_TW.md`，未發布。
- 本作不定位兒童類；不借用兒童類遊戲的政策驗收結果。年齡分級仍須依受騙情節、動作衝突與實際素材填寫。
