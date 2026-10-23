# Xboard macOS 介面規劃

更新日期：2026-10-23。目標是修復面板裁切與縮圖失真、提高可讀性，並保留現有工具與鍵盤流程。

## 原圖與程式碼根因

- 面板固定為 460 × 326，清單又固定為 186 高；列高、系統控制項內距與底列爭用空間，造成第三列截斷。清單樣式修飾也應套在各列，避免依賴預設列內距。
- 整窗縮放、垂直位移動畫可能超出透明 NSPanel 的實際繪製邊界，增加裁切與畫面不完整的風險。
- 縮圖使用 fill 填滿正方形，寬圖與長圖必然被裁切；這與圖片資料損壞不同。
- 背後 App 的文字穿透玻璃，與內容、陰影圖示重疊，降低對比與辨識度。

## 版面分區

| 區域 | 規劃 |
| --- | --- |
| 標頭 | App 名稱、符合目前搜尋／篩選的筆數、固定尺寸關閉按鈕；使用系統字體與語意色 |
| 搜尋 | 搜尋框、清除與篩選入口集中一列，保留種類、日期、來源 App、釘選與 OCR 篩選 |
| 清單 | 使用剩餘高度捲動，逐列設定內距；選取狀態使用系統強調色，避免內容滑入底列 |
| 底列 | 以分隔線保留獨立區域，顯示鍵盤提示或輔助使用授權入口，文字可換行 |

面板偏好尺寸為 **520 × 420 pt**。開啟時依目標螢幕的 `visibleFrame` 縮小至可用範圍，保留四周 12 pt；位置以輸入游標／目標視窗為準，邊緣不足時翻轉並限制在螢幕內。須驗證負座標副螢幕、上方螢幕與縮小的工作區。

## 材質、縮圖與可及性

- 標準材質使用原生 `windowBackgroundColor` 實色，文字使用 primary／secondary、選取使用 accentColor，支援系統、淺色與深色外觀。
- Liquid Glass 僅在 macOS 26+ 使用，玻璃前加入 85% 語意底色以提高可讀性；舊版使用系統 regularMaterial。啟用「減少透明度」或「提高對比」時，兩種材質都採原生實色，並隨系統偏好更新。
- 縮圖採 fit 完整顯示比例，固定容器補足留白；既有資料解碼失敗時顯示類型圖示。擷取時逐一驗證來源格式，跳過無效資料；GIF 優先，其他格式保留來源順序與原碼。OCR 與縮圖統一由 NSImage 解碼，涵蓋 SVG 等原生圖片。有效圖片的儲存與貼上維持原始資料。
- 保留每列智慧貼上、Quick Look、圖片編輯／GIF 儲存與釘選入口；常用文字儲存、OCR、刪除與貼上等完整操作仍可由選單存取。
- ⌘1–⌘9 採原生鍵盤捷徑，觸發時重新查詢目前搜尋／篩選結果，避免貼出舊項目。
- 為圖示按鈕提供明確可及性名稱，列提供貼上動作與選取狀態；裝飾圖示不重複朗讀。移除整窗位移／縮放動畫，避免繪製裁切並減少動態干擾。

## 功能保留與驗證範圍

下表列出應驗證項目，不代表測試已通過；實際建置、測試與畫面結果記於[驗證紀錄](validation.md)。

| 功能 | 保留要求與驗證方式 |
| --- | --- |
| 搜尋與鍵盤 | 開啟聚焦搜尋；↑↓、Return、Esc、⌘1–⌘9；清除／篩選後選取仍有效 |
| 歷史篩選 | 種類、日期、來源、釘選、OCR；空紀錄與無符合結果顯示正確，筆數反映篩選 |
| 內容操作 | 文字／圖片／GIF／檔案貼上；智慧格式、Quick Look、OCR、圖片編輯、GIF 儲存、釘選、存入 Library、刪除入口完整 |
| 圖片預覽 | 寬圖、長圖、透明圖、GIF 與無效資料；預覽完整、不拉伸、不影響原資料 |
| 外觀與可及性 | 淺／深色、標準／玻璃、減少透明度、提高對比；檢查文字辨識、VoiceOver 與鍵盤可操作性 |
| 視窗相容性 | 小工作區、多螢幕與螢幕邊緣；清單捲動不覆蓋標頭／底列 |
| 資料與其他工具 | 延用加密、權限、忽略 App、暫停、Library、Stack、截圖與 GIF 流程；執行既有回歸測試 |

## 依據與相容性界線

- 開源參考：[Maccy](https://github.com/p0deje/Maccy) 的原生介面與鍵盤優先流程；沿用 Xboard 現有架構，無新增執行期依賴。
- Apple 官方依據：[Fitting images into available space](https://developer.apple.com/documentation/swiftui/fitting-images-into-available-space)、[accessibilityReduceTransparency](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)、[glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))。
- 文件查詢使用 Context7 `/websites/developer_apple_swiftui`，該索引未提供版本區分，不能視為特定 macOS SDK 的保證。依專案最低 macOS 14、Swift 5 語言模式，以本機 Xcode／macOS SDK 編譯核對 API availability，並保留 macOS 26 的條件判斷；具體工具版本與結果見驗證紀錄。
- 圖片與 OCR 依據：[NSPasteboard.types](https://developer.apple.com/documentation/appkit/nspasteboard/types)、[NSImage.isValid](https://developer.apple.com/documentation/appkit/nsimage/isvalid)、[NSImage.cgImage](https://developer.apple.com/documentation/appkit/nsimage/cgimage(forproposedrect:context:hints:))；Context7 的 Apple AppKit 索引亦未提供特定 macOS 版本，API availability 另依 SDK 核對。
- macOS 14+ 是部署目標；舊版 macOS 與 Intel 尚未完成本次實機驗證。跨架構編譯不能替代各版本、硬體與螢幕組合的實機測試。
