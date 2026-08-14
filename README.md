# 宿舍管理 App（Capacitor 原生壳）

把现有 Laravel / Livewire 宿舍管理系统套进一个**真正的手机原生 App** 里：
- Android → 编译出可安装的 **APK**
- iOS → 编译出可安装的 **IPA**（需 Apple 开发者账号签名）

App 本身只是一个**全屏 WebView 壳**，`server.url` 指向你跑着的 Laravel 后端。
**你的全部业务代码（Laravel/Livewire）一行都不用改**，手机上看到的就是网页版的全屏形态，有桌面图标、可卸载、可内部分发。

---

## 一、后端前置（手机要能访问到 Laravel）

App 的 WebView 会加载 `http://<你的局域网IP>:8000`，请确认：

1. Laravel 开发服务器绑定到 `0.0.0.0`（已在用）：
   ```bash
   php artisan serve --host=0.0.0.0 --port=8000
   ```
2. 查本机局域网 IP（手机和这台电脑在同一 Wi-Fi）：
   ```bash
   ipconfig   # 看 无线局域网适配器 WLAN 的 IPv4，如 192.168.1.50
   ```
3. 防火墙放行 8000 端口（Windows  Defender 防火墙 → 高级设置 → 入站规则 → 新建 8000 TCP）。
4. 手机浏览器先直接访问 `http://192.168.1.50:8000` 验证能打开登录页——能开，App 就能用。

> 默认地址写在 `capacitor.config.ts`（`http://61.240.21.74:8000`，公网可达）。
> 出包时可在 GitHub Actions 手动触发时填 `server_url` 覆盖，**无需改代码**。

---

## 二、推送到 GitHub + 云编译出包（推荐，零本地安装）

本工程已配好两个 GitHub Actions 工作流（`.github/workflows/`）：

- `build-android.yml` → `ubuntu`  runner 自动出 **APK**
- `build-ios.yml` → `macos` runner 编译（iOS 真机安装需你提供 Apple 签名密钥）

### 1. 初始化并提交（已在本地完成）
```bash
cd F:\SS\dorm-app
git init
git add .
git commit -m "宿舍管理 App: Capacitor 原生壳 (Android/iOS)"
```

### 2. 在 GitHub 新建仓库（如 `dorm-app`），然后推送
```bash
git remote add origin https://github.com/<你的用户名>/dorm-app.git
git branch -M main
git push -u origin main
```

### 3. 触发构建
- **Android**：推送 `main` 后自动构建；或到仓库 **Actions → Build Android APK → Run workflow**，可填 `server_url`。
- 构建完在 **Actions → 该次运行 → Artifacts** 下载 `dorm-app-android-apk`（即 `app-debug.apk`）。

### 4. 手机安装 APK
- 把 `app-debug.apk` 传到手机（微信/数据线/下载），点击安装；
- Android 会提示"允许安装未知来源应用"，授权后完成；
- 桌面出现红色"宿"图标，打开即全屏使用宿舍系统。

---

## 三、iOS 真机安装（需 Apple 开发者账号）

iOS 工作流默认只**编译验证**（不签名、不出 IPA）。要出可安装的 IPA，需在仓库
**Settings → Secrets and variables → Actions** 添加 4 个密钥：

| Secret 名 | 内容 |
|---|---|
| `IOS_CERTIFICATE` | 开发者证书 `.p12` 的 **base64**（不含换行） |
| `IOS_CERT_PASSWORD` | `.p12` 导出密码 |
| `IOS_PROVISIONING_PROFILE` | `.mobileprovision` 的 **base64** |
| `IOS_TEAM_ID` | Apple 团队 ID |

生成 base64（macOS）：
```bash
base64 -i cert.p12 | tr -d '\n'     # 填 IOS_CERTIFICATE
base64 -i profile.mobileprovision | tr -d '\n'   # 填 IOS_PROVISIONING_PROFILE
```
配好后到 **Actions → Build iOS IPA → Run workflow**，完成后下载 `dorm-app-ios-ipa`（`App.ipa`），
用 Apple Configurator / 隔空投送 / TestFlight 安装。

> 描述文件与 App ID 需匹配 `com.dorm.admin`，并在 Apple 开发者后台注册该 App ID 与设备 UDID。

---

## 四、改后端地址（不重推也能改）

- **最简**：改 `capacitor.config.ts` 里的 `url`，重新 `git push` 触发构建；
- **不改代码**：GitHub Actions 手动触发时填 `server_url` 输入框；
- **本地真机调试**：`npx cap sync android` 后用 Android Studio 打开 `android/` 跑真机。

---

## 五、本地直接编译（可选，需自备工具链）

仅在你想在自己电脑上出包时：

```bash
npm install
npx cap sync android        # 或 ios
# Android：用 Android Studio 打开 android/ 点 Run；或：
npm run build:android
# iOS：用 Xcode 打开 ios/App/App.xcworkspace
```

本地需安装：Node 22、Java JDK 17、Android SDK（API 36）、Android Studio（Android）；
iOS 还需 macOS + Xcode + CocoaPods。云编译路线已帮你屏蔽这些安装成本。

---

## 目录结构
```
dorm-app/
├─ capacitor.config.ts        # App 配置（名称/包名/后端地址/cleartext）
├─ www/                       # 占位（实际内容由 server.url 加载）
├─ android/                   # 原生 Android 工程（已开 cleartext、品牌图标）
├─ ios/                       # 原生 iOS 工程（已加 ATS 例外、品牌图标）
└─ .github/workflows/         # 云编译工作流
   ├─ build-android.yml
   └─ build-ios.yml
```
