# 匯出 Android APK

1. 安裝 JDK 17 與 Android SDK（裝 Android Studio 最簡單）
2. Godot：編輯器 → 編輯器設定 → Export → Android，填入 Java SDK 與 Android SDK 路徑
3. 專案 → 安裝 Android 建置範本（使用 Gradle 建置時才需要）
4. 專案 → 匯出 → 新增 → Android
   - Package / Unique Name：例如 `com.apsmkimo.apexfighter`
   - Screen Orientation：Portrait（專案已預設）
   - 測試用 Debug keystore 會自動產生
5. 手機開啟開發者選項與 USB 偵錯，接上電腦後按編輯器右上角的 Android 圖示即可直接安裝執行

## 正式版簽章

- 用 `keytool` 產生 release keystore
- **keystore 與密碼不要放進 Git**（`.gitignore` 已排除 `*.keystore`、`*.jks`）
- 上架 Google Play 要匯出 AAB 格式
