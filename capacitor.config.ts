import type { CapacitorConfig } from '@capacitor/cli';

// 宿舍管理 App —— Capacitor 原生壳配置
// App 本身是全屏 WebView，加载下面 server.url 指向的 Laravel 后端。
// 业务代码零改动；改后端地址只需改这里（或云编译时通过 CAP_SERVER_URL 覆盖）。
const config: CapacitorConfig = {
  appId: 'com.dorm.admin',
  appName: '宿舍管理',
  webDir: 'www',
  server: {
    // 默认后端地址（公网/局域网均可）；云编译可用环境变量 CAP_SERVER_URL 覆盖（无需改文件）
    url: process.env.CAP_SERVER_URL || 'http://61.240.21.74:8000',
    // 放行 http（局域网无 HTTPS）。Android 自动开启 usesCleartextTraffic，iOS 注入 ATS 例外
    cleartext: true,
  },
  android: {
    // 允许 WebView 内混合内容（同源，基本用不到，留作保险）
    allowMixedContent: true,
  },
  ios: {
    // iOS 同样放行 http
    contentInset: 'always',
  },
};

export default config;
