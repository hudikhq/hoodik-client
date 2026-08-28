import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // AppKit's system Window menu binds Cmd+W to performClose:.
    // Notes tabs need that chord; close-window moves to Cmd+Shift+W.
    rebindWindowCloseShortcut()
  }

  private func rebindWindowCloseShortcut() {
    guard let windowMenu = NSApp.windowsMenu else { return }
    for item in windowMenu.items where item.action == #selector(NSWindow.performClose(_:)) {
      item.keyEquivalentModifierMask.insert(.shift)
      item.title = "Close Window"
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
