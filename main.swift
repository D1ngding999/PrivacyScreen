//
// PrivacyScreen —— 一键隐私黑屏 (macOS)
//
//   ⌃⌥B  按一下：背光直接调到 0，屏幕物理变黑
//          （机器不休眠、不锁屏，再回来不要求输入密码）
//   ⌃⌥B  再按一下：恢复到原来的亮度
//
// 亮度走 DisplayServices 私有框架（开源 brightness 工具同源）。
// 若 API 不可用或调用失败，自动退化为纯黑遮挡层（同样一键恢复）。
// 修改快捷键：改 hotKeys 里的 keyCode / 修饰键，重新运行 install.sh。
//

import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

// MARK: - 背光亮度（DisplayServices 私有框架）
// 实际签名（从本机 dyld 共享缓存反汇编确认）：
//   int   DisplayServicesGetBrightness(CGDirectDisplayID, float *out)   0=成功
//   int   DisplayServicesSetBrightness(CGDirectDisplayID, float level)  0=成功, 1000=失败

enum DisplayBrightness {
    typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static let get: GetFn? = symbol("DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetFn.self) }
    static let set: SetFn? = symbol("DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetFn.self) }

    private static func symbol(_ name: String) -> UnsafeMutableRawPointer? {
        let paths = [
            "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices",
            "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/A/DisplayServices",
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        ]
        for path in paths {
            if let handle = dlopen(path, RTLD_LAZY), let sym = dlsym(handle, name) {
                return sym
            }
        }
        return nil
    }

    static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    static func brightness(_ id: CGDirectDisplayID) -> Float? {
        guard let fn = get else { return nil }
        var value: Float = 0
        return fn(id, &value) == 0 ? value : nil
    }

    @discardableResult
    static func setBrightness(_ id: CGDirectDisplayID, _ level: Float) -> Bool {
        guard let fn = set else { return false }
        return fn(id, level) == 0
    }
}

// MARK: - 纯黑遮挡层（亮度 API 失败时的兜底）

final class OverlayController {
    private var windows: [NSWindow] = []
    private(set) var visible = false

    func toggle() {
        if visible {
            for w in windows { w.orderOut(nil); w.close() }
            windows.removeAll()
            NSCursor.unhide()
            visible = false
        } else {
            for screen in NSScreen.screens {
                let w = NSWindow(contentRect: screen.frame,
                                 styleMask: .borderless,
                                 backing: .buffered,
                                 defer: false)
                w.isOpaque = true
                w.backgroundColor = .black
                w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                w.hasShadow = false
                w.isReleasedWhenClosed = false
                w.setFrame(screen.frame, display: true)
                w.orderFrontRegardless()
                windows.append(w)
            }
            NSCursor.hide()
            visible = true
        }
    }
}

func debugLog(_ msg: String) {
    let line = "PrivacyScreen[\(Date.now)]: \(msg)\n"
    if let data = line.data(using: .utf8) { FileHandle.standardError.write(data) }
}

// MARK: - 黑屏开关

final class PrivacyController {
    private var savedBrightness: [CGDirectDisplayID: Float] = [:]
    private let overlay = OverlayController()
    private var blackedByBrightness = false
    private var blackedByOverlay = false

    var blackedOut: Bool { blackedByBrightness || blackedByOverlay }

    func toggle() {
        debugLog("toggle 触发 (当前黑屏中=\(blackedOut), 亮度API=\(DisplayBrightness.get != nil && DisplayBrightness.set != nil))")
        if blackedByOverlay {
            overlay.toggle()
            blackedByOverlay = overlay.visible
            return
        }
        if blackedByBrightness {
            restoreBrightness()
        } else {
            blackedByBrightness = cutBrightness()
            if !blackedByBrightness {   // API 失败 → 遮挡层兜底
                debugLog("亮度调用失败，改用遮挡层兜底")
                overlay.toggle()
                blackedByOverlay = overlay.visible
            }
        }
    }

    private func cutBrightness() -> Bool {
        let ids = DisplayBrightness.activeDisplays()
        var saved: [CGDirectDisplayID: Float] = [:]
        var anySuccess = false
        for id in ids {
            let before = DisplayBrightness.brightness(id)
            saved[id] = before ?? 0.5
            let ok = DisplayBrightness.setBrightness(id, 0)
            debugLog("display \(id): 原亮度 \(String(describing: before)) → 设 0 \(ok ? "成功" : "失败")")
            if ok { anySuccess = true }
        }
        guard anySuccess else { debugLog("活动显示器数量=\(ids.count)，无一成功"); return false }
        savedBrightness = saved
        NSCursor.hide()
        return true
    }

    private func restoreBrightness() {
        for (id, value) in savedBrightness {
            let ok = DisplayBrightness.setBrightness(id, value)
            debugLog("display \(id): 恢复亮度 \(value) \(ok ? "成功" : "失败")")
        }
        savedBrightness.removeAll()
        blackedByBrightness = false
        NSCursor.unhide()
    }
}

let controller = PrivacyController()

// MARK: - 全局快捷键注册

struct HotKey {
    let modifiers: UInt32   // Carbon 修饰键掩码
    let keyCode: UInt32     // 虚拟键码 kVK_*
    let id: UInt32
    let action: () -> Void
}

let hotKeys: [HotKey] = [
    HotKey(modifiers: UInt32(controlKey | optionKey),
           keyCode: UInt32(kVK_ANSI_B), id: 1) { controller.toggle() },
    // 测试别名：如果 ⌃⌥B 被别的程序抢占，这个还能触发
    HotKey(modifiers: UInt32(controlKey | optionKey | cmdKey),
           keyCode: UInt32(kVK_ANSI_B), id: 2) { controller.toggle() },
]

var actionByID: [UInt32: () -> Void] = [:]

let hotKeyHandler: EventHandlerUPP = { _, event, _ in
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    if status == noErr, let action = actionByID[hotKeyID.id] {
        action()
    }
    return noErr
}

func registerHotKeys() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                             eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, nil)

    for hk in hotKeys {
        actionByID[hk.id] = hk.action
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x50525659) /* 'PRVY' */, id: hk.id)
        let status = RegisterEventHotKey(hk.keyCode, hk.modifiers, id,
                                         GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            FileHandle.standardError.write("PrivacyScreen: 注册快捷键失败 id=\(hk.id) status=\(status)\n".data(using: .utf8)!)
        }
    }
}

// MARK: - main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // 后台运行，不出现在 Dock / 切换器

// --probe 自检：读亮度 → 做一次完整“黑屏 1 秒→恢复”循环，全部走真实调用路径
if CommandLine.arguments.contains("--probe") {
    guard DisplayBrightness.get != nil, DisplayBrightness.set != nil else {
        print("DisplayServices 符号不存在，将使用遮挡层兜底")
        exit(1)
    }
    for id in DisplayBrightness.activeDisplays() {
        print("display \(id): 当前亮度 \(String(describing: DisplayBrightness.brightness(id)))")
    }
    controller.toggle()                       // 黑屏
    print("已黑屏，1 秒后恢复…")
    usleep(1_000_000)
    controller.toggle()                       // 恢复
    for id in DisplayBrightness.activeDisplays() {
        print("display \(id): 恢复后亮度 \(String(describing: DisplayBrightness.brightness(id)))")
    }
    exit(0)
}

registerHotKeys()
app.run()
