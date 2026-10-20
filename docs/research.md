# 開源與產品調查、技術決策

調查日期：2026-10-20。以下是官方文件與原始碼的比較；未對每個產品進行實機效能評測。價格與發行狀態以連結當下內容為準。

## 開源候選

| 專案 | 語言／技術 | 授權、取得方式 | 適合參考的部分 | 本案決策 |
| --- | --- | --- | --- | --- |
| [Kelsiito/clipboard](https://github.com/Kelsiito/clipboard) | Swift、SwiftUI、AppKit；Apple frameworks，無第三方執行期套件 | MIT；原始碼建置，上游尚未正式簽署與公證 | 已有 Windows+V 形式的小面板、文字／圖片／檔案、加密、OCR | **採用為基底**，保留 Git 歷史與授權。修正快捷鍵、釘選限制、本機簽署下的 Keychain 與貼回焦點 |
| [Maccy](https://github.com/p0deje/Maccy) | Swift、原生 macOS UI | MIT；官方 GitHub Releases 與 Homebrew 可免費取得 | 鍵盤操作、搜尋、釘選、忽略敏感剪貼簿類型 | 作為行為參考。現有基底已具備主要流程，沒有再移植一套儲存或 UI |
| [Pesty](https://github.com/momenbasel/pesty) | Swift、SwiftUI；官方稱無第三方依賴 | MIT；直接下載／Homebrew 免費；App Store 一次性付費是可選管道 | 畫面下緣展開、來源顏色、卡片預覽與 pinboards | 作為介面參考。本案先保留緊湊面板，沒有複製其卡片介面或程式碼 |
| [Clipy](https://github.com/Clipy/Clipy) | Swift、Xcode | MIT；官方下載／自行建置 | 選單式歷史、常用文字、快捷鍵設定 | 可用的既有方案；本案使用已有的 SwiftUI 小面板，避免另外移植選單系統 |
| [CopyQ](https://github.com/hluk/CopyQ) | [C++17、Qt 6 Widgets、CMake](https://github.com/hluk/CopyQ/blob/master/CMakeLists.txt) | GPL-3.0；開源跨平台 | 分頁、命令列與腳本、自訂內容處理 | 功能範圍較廣；本案僅做原生 macOS，未引入 Qt 或其程式碼 |

免費取得與商店收費可以同時存在。Maccy 與 Pesty 都有免費發行管道；因此本案的價值是預設 ⌥V、繁體中文、簡單操作與可自行維護，不能宣稱市面上沒有可用的免費工具。

## 市面產品

| 產品 | 官方可確認的取得／收費方式 | 需求上的取捨 |
| --- | --- | --- |
| [Paste](https://pasteapp.io/pricing) | Personal 頁面顯示每年 US$29.99（換算 US$2.49／月）、7 天試用；頁面另有月繳與終身選項，地區及稅額可能不同 | 提供完整歷史、pinboards 與跨裝置同步。本案先完成單機功能，不需支付同步服務費 |
| [Raycast Clipboard History](https://www.raycast.com/core-features/clipboard-history) | 官方提供免費下載使用的剪貼簿歷史功能 | 適合已使用 Raycast 的人；OptionV 是獨立工具，使用者不必額外採用啟動器 |

上述產品的內部實作未經解析，不推測其私有框架、加密方式或資料庫。這次使用公開原始碼已能完成核心流程，沒有使用 REA 解包商業產品。

## 已選定的語言、框架與庫

| 範圍 | 本案採用 | 對應程式 |
| --- | --- | --- |
| 主語言／專案 | Swift，Swift 5 語言模式；Xcode 專案；最低 macOS 14 | `OptionV.xcodeproj` |
| 畫面與狀態 | SwiftUI、ObservableObject；AppKit NSPanel／NSWindow | `OptionVApp.swift`、`ClipboardPanelController.swift`、`SettingsView.swift` |
| 系統剪貼簿 | [AppKit NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)、changeCount 輪詢、UniformTypeIdentifiers | `PasteboardMonitor.swift`、`Models.swift` |
| 全域快捷鍵 | 系統 Carbon RegisterEventHotKey；預設 Option + V；註冊失敗保留舊組合 | `GlobalHotKey.swift`、`AppState.swift` |
| 搜尋／去重 | 記憶體篩選與 CryptoKit SHA-256 指紋；保留釘選與來源資訊 | `Models.swift`、`ClipboardStore.swift` |
| 儲存 | Foundation Codable；整份歷史加密後原子寫入本機檔案 | `ClipboardStore.swift` |
| 加密／金鑰 | [CryptoKit AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)、Security SecItem 與本機登入鑰匙圈 | `SecureLocalStorage.swift` |
| 貼回／權限 | AppKit 啟用原 App、ApplicationServices 檢查輔助使用、CoreGraphics 送出 ⌘V；沒有權限可手動貼上 | `AppState.swift` |
| 登入啟動 | [ServiceManagement SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) | `AppState.swift` |
| 額外工具 | Vision 本機 OCR、QuickLookUI、LocalAuthentication、ScreenCaptureKit／AVFoundation／ImageIO | 對應既有 service，主選單收在「更多工具」 |
| 本地化／測試 | String Catalog（繁體中文、英文）、XCTest | `Localizable.xcstrings`、`OptionVTests` |

本次沒有新增第三方執行期依賴。200 筆左右的歷史先沿用基底的記憶體搜尋與加密檔案，不增加 SQLite、GRDB、搜尋服務或後端。若實測大量圖片造成啟動或寫入延遲，再以量測結果決定儲存遷移；目前不宣稱可承受無限量歷史。

## 資料與權限流程

1. 剪貼簿變更後，排除暫停、忽略 App、敏感類型與本工具產生的貼回。
2. 讀取文字、RTF、圖片或檔案參照；讀取後再次核對 changeCount，避免混到兩次複製。
3. 依指紋去重，更新時間；釘選獨立於未釘選筆數與期限。
4. 金鑰在背景取得。尚未授權時僅留在記憶體，保留既有加密檔案；授權成功後合併紀錄。
5. ⌥V 開啟面板；搜尋、↑↓、Return 選取，Esc 關閉。
6. 恢復選取內容並啟用原 App。只有輔助使用已授權、焦點仍正確、剪貼簿未再變更才送出 ⌘V。

敏感類型依循 [NSPasteboard.org 的標記慣例](https://nspasteboard.org/)。沒有標記的敏感文字仍可能被記錄；使用者可排除 App、暫停或略過下一次複製。檔案只儲存參照，不複製或刪除原檔。

## 完成順序與後續條件

| 階段 | 本次結果／交付條件 |
| --- | --- |
| 來源與身分 | MIT 基底、OptionV 名稱、獨立 bundle ID／資料目錄、來源聲明 |
| 核心體驗 | 預設 ⌥V、繁體中文、搜尋與鍵盤選取、可調歷史數、解除三筆釘選限制 |
| 資料安全 | 加密讀寫、鑰匙圈背景授權與重試、保留解密失敗資料、避免貼到錯誤焦點 |
| 本機交付 | Universal app、ZIP、可重複建置腳本、64 項測試；詳細結果見 [驗證紀錄](validation.md) |
| 私人版本庫 | 已建立 [timmyc07/OptionV](https://github.com/timmyc07/OptionV)（Private），程式與上游歷史已推送至 `feat/option-v`，作為目前預設分支 |
| 對外發行 | 下一階段才申請／使用 Developer ID、公證、跨版本與 Intel 實機驗證；完成後才提供一般使用者下載 |

目前沒有實作雲端同步、帳號、付費訂閱或自動更新服務。
