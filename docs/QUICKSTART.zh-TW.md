# AppMixer 使用說明

[English README](../README.md)

AppMixer 是 Mac 選單列工具，目標是讓你**調低 Chrome，同時保留 Spotify 的音量**。每個 App 都有獨立滑桿與靜音按鈕。

<img src="images/appmixer-preview.png" alt="AppMixer 0.2.0 示範介面，包含音量、登入啟動與更新選項" width="360">

這是 **0.2.0 模擬預覽截圖**，沒有擷取真實音訊；預覽中的外部操作按鈕會停用。

## 下載與安裝

1. 前往 [GitHub Releases](https://github.com/EdmundLT/Mac-mixer/releases) 下載 DMG。
2. 開啟 DMG，把 **AppMixer.app** 拖到「應用程式」。
3. 開啟 AppMixer，點選螢幕上方選單列的**滑桿圖示**。
4. App 會嘗試啟用音量控制；macOS 若詢問音訊錄製權限，需要你親自決定是否允許。

需要 **Apple Silicon Mac、macOS 14.2 以上**。建議先使用內建揚聲器；AirPods 或其他音訊裝置可能不支援。

目前公開下載為 **0.1.0**，沒有下述登入啟動／自動更新選項。包含這些功能的 **0.2.0** 候選版本已送 Apple 公證，但尚未發布 Release。請以各版本發布說明確認簽署、公證狀態。

## 操作方式

| 英文介面 | 用途 |
| --- | --- |
| App 名稱旁的滑桿 | 調整該 App 的音量，範圍 0–100%。 |
| 喇叭按鈕 | 靜音／取消靜音，保留滑桿設定。 |
| Enable Volume Control | 啟用或重試音量控制。 |
| Stop & Restore | 停止處理，恢復各 App 原本輸出。 |
| Quit | 結束 AppMixer。 |
| Launch at Login · 0.2.0 | 自行選擇登入 Mac 時啟動；若需要核准，按設定入口處理。 |
| Check for Updates… · 0.2.0 | 手動檢查更新。 |
| Automatically Check for Updates · 0.2.0 | 自動檢查更新，預設關閉；安裝更新仍需確認。 |

請先在 Chrome／Spotify 播放你選擇的內容，AppMixer 才會列出播放中的 App。Chrome 輔助程序會合併成一組，不提供分頁控制。

0.1.0 沒有內建更新器，需要手動安裝一次包含 Sparkle 的新版。初始更新清單目前沒有可安裝項目。

## 遇到問題

- **沒有 App：**先開始播放，再打開選單列面板。
- **權限錯誤：**到「系統設定 → 隱私權與安全性」檢查 AppMixer 的音訊錄製權限，再按 Enable Volume Control。
- **裝置不支援：**先在 macOS 聲音設定選擇內建揚聲器。
- **休眠／換裝置後停止：**重新按 Enable Volume Control。
- **下載後被 macOS 阻擋：**確認你信任來源後，在「隱私權與安全性」檢視被阻擋的 App，不要關閉 Gatekeeper。

音訊只在本機記憶體處理，不儲存、不上傳；不安裝虛擬驅動，也不更改系統預設輸出。更新功能會連線 GitHub 取得更新資訊。

**目前仍為原型。** 已完成編譯、19 項模擬／狀態測試、介面與更新清單驗證；真實音訊隔離、退出／崩潰恢復、長時間播放、重新登入啟動及完整更新安裝仍待驗收。公證通過也不代表音訊功能已驗收。
