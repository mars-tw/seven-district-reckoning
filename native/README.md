# 原生匯出

原生識別與版本見 `native/build-config.json`。Android 版本為 1.0.0／build 8；iOS Xcode 預設仍是 build 1。遊戲來源版本另列為 0.4.0。

此流程使用官方 Godot 4.7.2；獨立工具安裝器會核對發布者的下載雜湊，不讀商店憑證。

```text
python tools/install_native_toolchain.py --output <isolated-tools> --android-sdk <android-sdk>
python tools/export_mobile.py --target android --godot <official-editor> --jdk <jdk> --android-sdk <android-sdk> --bundletool <bundletool.jar>
```

Android 輸出是未簽署 APK／AAB，會核對識別、版本、target API 36、ARM64、遊戲資源及非 debug 狀態。正式簽署由中央發布工具使用本 App 的金鑰處理，不使用其他 App 或 debug key。

Godot 4.7.2 已實際在 Windows 匯出這個遊戲的 Xcode 原始專案；Windows 沒有完成 iOS 編譯或產生 IPA。

```text
python tools/export_mobile.py --target ios --source-only --godot <official-editor>
```

輸出位置與 Xcode scheme 見 build-config。將整個 ios 輸出資料夾打包，包含 `.xcodeproj`、`.pck`、`.xcframework`、圖示、launch storyboard 與 PrivacyInfo；不要把本機 build logs 加入 ZIP。來源 ZIP 的檔案雜湊與編譯命令另列在本機 `release/ios/source-verification.json`。

在安裝 Xcode 的 Mac 上可執行完整未簽署 archive：

```text
python tools/export_mobile.py --target ios --godot <official-editor>
```

`.github/workflows/native-export.yml` 只接受手動啟動，兩個 job 分別在 Linux 建置 Android、在 macOS 15／Xcode 26.3 建置 iOS；它不簽署、不呼叫商店、不部署。CI 尚待實際執行，語法檢查不代表雲端建置已通過。

遊戲內已有 Godot 觸控節點，接到原本移動／動作輸入；不是外層網頁 JS 控制。這輪的非 Web headless 場景檢查包含實際 ScreenTouch／ScreenDrag、玩家物理移動、放開輸入及暫停／繼續。它不等於 Android／iOS 實機、軟鍵盤或喇叭驗收，也不代表已獲商店審核。
