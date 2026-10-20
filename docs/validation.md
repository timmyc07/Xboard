# 本機驗證紀錄

日期：2026-10-20。

## 環境與結果

- macOS 26.6.2、Apple Silicon；Xcode 27.1、Swift 6.4（專案為 Swift 5 語言模式）。
- XCTest：**64 項通過、0 失敗、0 略過**。
- Release 建置成功；Universal executable 同時包含 arm64 與 x86_64。
- 安裝副本通過 `codesign --verify --deep --strict`。這是 ad-hoc 簽署，未進行 Apple 公證。
- `git diff --check` 通過。

## 已涵蓋

- 預設 Option + V、選用 GIF／連續貼上快捷鍵不預設註冊。
- 多於三筆釘選、降低未釘選上限、去重、搜尋、圖片與檔案資料。
- AES-GCM 來回、竄改拒絕、解密失敗保留檔案。
- 真實 macOS 登入鑰匙圈來回：使用獨立 UUID 測試服務，測試後移除該測試項目。
- 延後載入與失敗後重試：合併待存紀錄、保留儲存的釘選，已載入後重試不復活已刪除資料。
- 繁體中文設定畫面、預設 ⌥V 顯示、未設定的選用快捷鍵、設定數字欄位。
- 從 App 選單開啟剪貼簿面板、搜尋欄位、Esc 關閉、手動 ⌘V 提示。
- 鑰匙圈等待授權期間，設定與面板仍可操作；主執行緒沒有阻塞在 Keychain API。

先前以合成文字進行本機複製與加密儲存檢查。更換 ad-hoc 建置後，現有鑰匙圈項目可能再次要求使用者授權；本次沒有代為批准新的系統安全權限。

## 尚未完成的實機驗證

- 實體鍵盤的全域 ⌥V，以及不同輸入法、Secure Input 密碼欄位與快捷鍵衝突。
- 使用者授予輔助使用後，在不同原生、瀏覽器與 Electron App 的自動貼上。
- macOS 14–25 與 Intel 實機。Universal 編譯成功不代表上述執行環境已驗證。
- 登入項目、螢幕錄影權限、所有額外工具的完整人工回歸。
- 長時間運作、大量圖片歷史的耗電／記憶體／磁碟量測。
- Developer ID 簽署、公證、對外發行與 GitHub Actions 遠端執行。

## 重現方式

```sh
xcodebuild -project OptionV.xcodeproj -scheme OptionV \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData test
./scripts/build-app.sh
codesign --verify --deep --strict build/OptionV.app
file build/OptionV.app/Contents/MacOS/OptionV
git diff --check
```

建置結果在 `build/OptionV.app`、`build/OptionV.zip`；測試報告在 `build/DerivedData/Logs/Test/`。這些輸出與畫面截圖都在忽略提交的 `build/` 目錄。
