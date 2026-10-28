# PrivacyScreen

一个 macOS 屏幕隐私保护小工具：按一下快捷键，屏幕背光直接调到 0（物理全黑）；再按一下，恢复原亮度。

**不休眠、不锁屏、回来不需要输密码**——适合路过同事、会议室投影、短暂离开等需要"立刻遮屏"但不想打断工作流的场景。

## 快捷键

| 按键 | 功能 |
|---|---|
| `⌃⌥B` | 切换黑屏 / 恢复 |
| `⌃⌥⌘B` | 同上（备用键位，防止 `⌃⌥B` 被其他应用占用） |

## 特点

- 真·全黑：把显示器亮度调到 0，而不是盖一个黑色窗口
- 零权限：全局快捷键用 Carbon `RegisterEventHotKey`，**不需要**辅助功能 / 录屏权限
- 不触发锁屏：系统从未进入睡眠，唤醒密码策略完全不沾边
- 精确恢复：记住黑屏前每块显示器的亮度并原样还原
- 兜底：若亮度 API 在个别机型/系统上不可用，自动退化为全屏纯黑遮挡层
- 后台常驻：LaunchAgent 方式开机自启，无 Dock 图标、无窗口，崩溃自动拉起

## 安装

**一行命令（推荐）**——不需要 git，不需要装任何开发工具，直接下载预编译的通用二进制（Intel / Apple Silicon 均可）：

```bash
curl -fsSL https://raw.githubusercontent.com/D1ngding999/PrivacyScreen/main/install.sh | bash
```

或者本机编译（需要 Command Line Tools，`xcode-select --install`）：

```bash
git clone https://github.com/D1ngding999/PrivacyScreen.git
cd PrivacyScreen
bash install.sh
```

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/D1ngding999/PrivacyScreen/main/uninstall.sh | bash
```

## 自定义快捷键

编辑 `main.swift` 中 `hotKeys` 数组的 `keyCode`（常量来自 `Carbon.HIToolbox`，如 `kVK_ANSI_D`）和修饰键，重新运行 `./install.sh`。

## 技术说明

亮度使用私有框架 `DisplayServices`（与开源 `brightness` 工具同源）。不同 macOS 版本签名有变化——本项目在 macOS 27 / Apple Silicon 上通过反汇编 dyld 共享缓存确认真实签名：

```c
int DisplayServicesGetBrightness(CGDirectDisplayID, float *out);   // 0 = 成功
int DisplayServicesSetBrightness(CGDirectDisplayID, float level);  // 0 = 成功, 1000 = 失败
```

注意旧文档/旧版本常写的 `float DisplayServicesGetBrightness(CGDirectDisplayID)` 在新系统上会**直接段错误**（函数会往第二个参数写结果）。

排查问题时可看日志：`~/Library/Logs/PrivacyScreen.log`。

## 已知限制

- 外接显示器若系统不支持软件调光，会由遮挡层兜底（外接屏背光仍亮，但内容被盖住）
- 黑屏期间机器完全活跃：声音、网络、正在跑的任务都不受影响，别忘了锁屏的场景其实该用 `⌃⌘Q`
- 若 `⌃⌥B` 被输入法或其他应用抢占，用 `⌃⌥⌘B` 或改成自己的键位

## License

未附带开源许可证，自用/修改随意；如需正式开源请自行添加（如 MIT）。
