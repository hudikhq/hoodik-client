import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Enforce a minimum content size so the UI never breaks when the user
    // resizes down. The notes editor needs ~700pt to show the sidebar.
    self.contentMinSize = NSSize(width: 800, height: 600)

    // Use a roomy default on first launch — the stock xib ships with
    // 800x600, which is cramped for the desktop sidebar + editor layout.
    // This is only applied when there's no saved window frame from a
    // previous session.
    self.setContentSize(NSSize(width: 1200, height: 800))

    // Let macOS remember the window size/position across launches.
    // Picks up the last saved frame (if any) and writes the new one on
    // resize/move. The key is scoped to the app bundle so it won't
    // collide with other Flutter apps.
    self.setFrameAutosaveName("io.hoodik.app.main-window")

    RegisterGeneratedPlugins(registry: flutterViewController)

    // macOS-only video thumbnail extraction. The `video_thumbnail`
    // Flutter package ships Android + iOS impls only, so this bridge
    // gives the macOS app feature parity for video previews.
    VideoThumbnailChannel.register(
      with: flutterViewController.engine.binaryMessenger
    )

    // Platform channel so Dart can update the native window title
    // reflectively (active note, current folder, etc.). Cosmetic only —
    // any failure is ignored on the Dart side.
    let channel = FlutterMethodChannel(
      name: "io.hoodik.app/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setTitle":
        if let title = call.arguments as? String {
          self?.title = title
          result(nil)
        } else {
          result(FlutterError(
            code: "BAD_ARG",
            message: "String expected for setTitle",
            details: nil
          ))
        }
      case "showAndActivate":
        guard let window = self else {
          result(FlutterError(
            code: "NO_WINDOW",
            message: "Main window is unavailable",
            details: nil
          ))
          return
        }

        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
          window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Excludes the local database (and its WAL/SHM sidecars) from Time Machine
    // and iCloud backups on request from Dart — see
    // lib/core/storage/no_backup.dart. The DB holds only sealed key material,
    // but a backup is still one more place it should never land.
    let backupChannel = FlutterMethodChannel(
      name: "io.hoodik.app/backup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    backupChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "excludeFromBackup":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
          result(FlutterError(
            code: "BAD_ARG",
            message: "excludeFromBackup requires {path: String}",
            details: nil
          ))
          return
        }
        var url = URL(fileURLWithPath: path)
        do {
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(true)
        } catch {
          result(FlutterError(
            code: "EXCLUDE_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
