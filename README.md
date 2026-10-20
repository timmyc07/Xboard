# Xboard

免費、原生的 macOS 剪貼簿紀錄工具。按 **⌥V（Option + V）** 搜尋複製過的文字、圖片與檔案，選取後貼回原本的應用程式。

- SwiftUI + AppKit；macOS 14 以上，Apple Silicon 與 Intel。
- 繁體中文與英文，跟隨系統語言。
- 文字、RTF、圖片、GIF 與檔案參照；搜尋、類型／來源篩選、鍵盤選取、快速預覽。
- 釘選沒有筆數限制。未釘選紀錄預設保留最近 200 筆，可在設定中輸入任意 10 筆以上的數量。
- 支援自動清除期限、排除 App、暫停紀錄、略過下一次複製。
- AES-GCM 本機加密，金鑰只存在此 Mac 的鑰匙圈。不需帳號、訂閱或伺服器。
- 更多工具保留上游的常用文字、連續複製、OCR、截圖標註與 GIF 錄製。這些功能不會預設攔截其他全域快捷鍵。

## 建立與使用

需要 Xcode 26 或更新版本（含 macOS 26 SDK）。

```sh
./scripts/build-app.sh
open build/Xboard.app
```

或開啟 `Xboard.xcodeproj`，選擇 `Xboard` scheme 和 My Mac。

1. 第一次啟動會打開設定；允許 macOS 提出的剪貼簿存取要求。
2. 正常複製文字、圖片或檔案，再按 ⌥V。
3. 輸入關鍵字搜尋，↑↓ 選取，Return 貼上，Esc 關閉。
4. 點面板下方「啟用自動貼上」，在「系統設定 → 隱私權與安全性 → 輔助使用」啟用 Xboard，可自動貼回原 App。未授權時，選取會把內容放回剪貼簿；切回目標 App 按 ⌘V 即可。複製歷史不需要這項權限，因此能記錄但無法自動貼上時，請先檢查此處。
5. ⌥V 會占用該組合原本的特殊字元輸入；若和輸入法衝突，可在設定更改快捷鍵。安全密碼欄位可能阻擋 Option 字元快捷鍵。

`build/Xboard.app` 與 `build/Xboard.zip` 是本機 ad-hoc 簽署版本，沒有 Apple 公證。正式發佈需要 Developer ID 與公證；不需在程式碼或 `.env` 中放入憑證。每次更換本機建置後，macOS 可能要求重新授權輔助使用或鑰匙圈。鑰匙圈授權在背景處理，等待或拒絕授權時不會覆寫既有資料；新項目僅暫存在記憶體，可在設定重試。

## 本機資料

資料保存在 `~/Library/Application Support/Xboard/`，與上游 clipboard App 的資料分開。歷史與常用文字以 AES-GCM 加密，金鑰服務識別為 `io.github.timmyc07.Xboard.local-storage`，不透過 iCloud 同步。刪除鑰匙圈金鑰將無法解密現有紀錄。

釘選不受筆數與期限清除影響。清空紀錄會刪除 App 的歷史，但不會刪除原始檔案或清空系統剪貼簿；檔案紀錄是參照，原始檔案移動或刪除後可能無法取用。所有設定都在 App 內，不需要 `.env`。

## 開發

```sh
xcodebuild -project Xboard.xcodeproj -scheme Xboard -destination 'platform=macOS' -derivedDataPath build/DerivedData test
```

[開源與產品調查、技術決策](docs/research.md) · [技術實作](docs/implementation.md) · [驗證結果與待驗證項目](docs/validation.md)。上游歷史文件保存在 `docs-upstream/`，其中的產品名稱、上架狀態與路線圖屬於上游。

## 授權與來源

本專案衍生自 MIT 授權的 [Kelsiito/clipboard](https://github.com/Kelsiito/clipboard)，保留原始 Git 歷史、授權和圖示。詳見 [LICENSE](LICENSE) 與 [第三方來源](THIRD_PARTY_NOTICES.md)。
