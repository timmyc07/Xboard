# 本機驗證紀錄

日期：2026-10-20。

## 環境與結果

- macOS 26.6.2、Apple Silicon；Xcode 27.1、Swift 6.4（專案為 Swift 5 語言模式）。
- 改名前的核心 XCTest：**64 項通過、0 失敗、0 略過**。這次改名沒有重新執行測試套件。
- Release 建置成功；Universal executable 同時包含 arm64 與 x86_64。
- 安裝副本通過 `codesign --verify --deep --strict`。這是 ad-hoc 簽署，未進行 Apple 公證。
- `git diff --check` 通過。
- 私人 GitHub 儲存庫已建立，`feat/xboard` 推送成功，遠端提交與本機一致；未提交本機建置產物、鑰匙圈資料或 `.env`。

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

## Xboard 改名與貼上權限

- 專案、產品、模組、bundle ID、設定鍵、本機資料目錄、金鑰服務名稱與文件統一使用 Xboard。
- 專案根目錄整理為 `/Users/reikous/codes/Xboard`；既有工作區 Saved 內容不納入提交。
- 實際設定畫面確認「輔助使用」尚未授權，並已顯示項目放回剪貼簿的狀態。這會阻止自動送出 ⌘V，但不阻止記錄與選取。
- 面板新增「啟用自動貼上」入口，明確提示權限缺失；點選後向 macOS 提出授權請求並開啟對應設定頁。
- Xboard Release Universal 建置成功；未代為批准系統安全權限。
- 本機設定已轉移至新的 bundle ID；既有加密歷史與備份逐位元組相同。取得使用者授權後，已將同一鑰匙圈項目的服務名稱改為 Xboard，金鑰與原有存取控制維持不變。
- `/Users/reikous/Applications/Xboard.app` 已安裝並通過簽署檢查。舊版程式、加密紀錄及設定備份保存在忽略提交的 `build/rename-backup/`。
- 私人儲存庫與遠端 URL 已更名為 `timmyc07/Xboard`，預設分支為 `feat/xboard`。
- 使用者已完成 Xboard 的鑰匙圈與輔助使用授權；系統開關與 App 內的「加密儲存」「輔助使用」均確認為已啟用。未進行跨 App 自動貼上的完整實機回歸。

## 2026-10-21：英文 README 與系統語言

- README 全文改為英文，保留功能、隱私、建置與授權說明，並新增系統／個別 App 語言偏好的操作說明。
- 確認沿用 macOS 原生語言選擇：支援英文與繁體中文，無符合語言時使用英文；沒有新增自訂語言設定或覆寫系統偏好。
- 補齊標註工具、復原、編輯、標籤、GIF 篩選、預設常用文字標題與截圖／錄影錯誤訊息的繁中翻譯。
- 繁中環境完整 XCTest：**66 項通過、0 失敗、0 略過**；另在英文與日文偏好下各通過 2 項語言測試，涵蓋英文備援及區域語言匹配。
- Release Universal 建置成功，包含 arm64 與 x86_64；`codesign --verify --deep --strict` 通過。
- README 本機連結、翻譯格式參數與 `git diff --check` 通過。未重新進行所有畫面的人工操作、Intel 或舊版 macOS 實機驗證。

## 2026-10-23：原生介面、圖片與鍵盤操作

- 環境：macOS 26.6.2、Apple Silicon；Xcode 27.1、macOS SDK 27.0，Swift 5 語言模式；部署目標維持 macOS 14。
- 最終完整 XCTest：**73 項通過、0 失敗**。新增圖片格式驗證與原碼保存、SVG 背景 OCR、小工作區尺寸、負座標／上方螢幕配置等回歸測試。
- Release Universal 建置成功，含 arm64 與 x86_64；產物及安裝副本均通過 `codesign --verify --deep --strict`。
- 用同一份產品 View 與隔離合成資料開啟原生驗證視窗，檢查淺／深色、標準／玻璃、520 × 420 與 456 × 336 尺寸。寬圖與長圖完整等比例顯示，清單捲動與底列分隔正常。
- 實際 UI 斷言確認：搜尋欄聚焦時 ⌘4 能選取第四筆；搜尋後 ⌘1 使用目前結果；無結果時不貼出舊項目；↑↓／Return、Esc 清除與關閉、釘選、篩選筆數與「無符合結果」正常。
- ⌘數字改用原生鍵盤捷徑，並在觸發時重新解析搜尋／篩選結果，避免控制項保留舊動作時貼錯內容。
- 以安裝版原生選單開啟真正 NSPanel，確認繁中搜尋、空狀態、底列及圓角無外層裁切。
- 最終版本已安裝到 `/Users/reikous/Applications/Xboard.app`，執行檔與 `build/Xboard.app` 的 SHA-256 相同；更新前 App 備份在忽略提交的 `build/ui-refinement-backup/`。
- 本次重新簽署後，安裝版顯示等待鑰匙圈授權、輔助使用尚未授權；未代操作系統安全視窗。加密歷史未讀出前，真實歷史與跨 App 自動貼上不列為此次已驗證。合成測試的 ClipboardStore 使用獨立暫存目錄，未直接寫入使用者歷史。
- 未實測 macOS 14–25、Intel 實機、不同輸入法、VoiceOver 完整流程或系統「減少透明度／提高對比」開關；這些外觀偏好的處理已實作並編譯通過。舊的損壞圖片資料不會憑空重建。
- 新增變更未產生 Swift 編譯警告；完整 Release 仍有既有 GIF 影片讀取 API 的 deprecated 警告，錄影流程本次未重構。
- `git diff --check` 通過。沒有新增執行期依賴，未修改或提交 `.env`、金鑰及本機建置產物。介面決策與文件版本界線見[介面規劃](ui-plan.md)。

## 2026-10-23：點選貼上修復

- 修復共用貼上流程：採 macOS 14 的 cooperative activation，移除固定 120ms 的一次性檢查，最多等待 1.5 秒確認目的 App 在前景；切換其他 App、剪貼簿改變、權限撤回或新操作都會停止待處理貼上。
- 面板已開啟時再次呼叫開啟不會重設目的 App。缺少輔助使用時顯示原生提示與系統設定入口，不再只在隱藏的設定頁寫狀態。
- 新增 4 項交接判斷測試：超過 120ms 仍可等待、其他 App、剪貼簿變更／失權及逾時。最終完整 XCTest **77 項通過、0 失敗、0 略過**，以 xcresult 結構化摘要確認。
- Release Universal 建置成功；安裝副本通過嚴格簽署檢查，執行檔 SHA-256 與建置產物相同。未新增依賴，沒有改動加密歷史格式或提交 `.env`。
- 系統原先顯示 Xboard 開關開啟，但安裝程式回報未授權；重新啟動及單純切換開關後仍未生效。移除舊項目、由使用者重新加入目前安裝的 Xboard 後，App 內已確認「輔助使用已啟用」。安全授權由使用者本人完成。
- 已建立獨立的文字編輯測試文件；跨 App 的最終點選貼上驗證等待實體 ⌥V 開啟面板。自動操作工具送出的該組合目前只產生一般字元，不能據此判定實體快捷鍵失效，也不能用單元測試代稱跨 App 貼上已成功。
- macOS 14–25、Intel 實機與所有目的 App 尚未逐一測試；連續貼上佇列的消費時機維持既有行為。

## 重現方式

```sh
xcodebuild -project Xboard.xcodeproj -scheme Xboard \
  -destination 'platform=macOS' -derivedDataPath build/DerivedData test
./scripts/build-app.sh
codesign --verify --deep --strict build/Xboard.app
file build/Xboard.app/Contents/MacOS/Xboard
git diff --check
```

建置結果在 `build/Xboard.app`、`build/Xboard.zip`；測試報告在 `build/DerivedData/Logs/Test/`。這些輸出與畫面截圖都在忽略提交的 `build/` 目錄。
