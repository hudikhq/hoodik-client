import Flutter
import ObjectiveC
import UIKit
import WebKit

/// Strip WKWebView's default input accessory bar (up/down/Done) so the
/// markdown editor's own formatting toolbar sits flush against the
/// keyboard. The accessory view lives on `WKContentView`, a private SPI
/// class nested inside WKWebView's hierarchy; we replace the getter for
/// `-inputAccessoryView` on that class with one that returns nil. Safe
/// across iOS versions — if Apple ever renames the class the lookup
/// silently no-ops and the default accessory bar reappears.
private let suppressWebViewInputAccessoryOnce: Void = {
  guard let target = NSClassFromString("WKContentView") else { return }
  let selector = #selector(getter: UIResponder.inputAccessoryView)
  guard let method = class_getInstanceMethod(target, selector) else { return }
  let nilGetter: @convention(block) (Any) -> UIView? = { _ in nil }
  let imp = imp_implementationWithBlock(nilGetter)
  method_setImplementation(method, imp)
}()

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    _ = suppressWebViewInputAccessoryOnce

    #if DEBUG
    // Patrol's PatrolAppService needs to register before the implicit engine
    // spins up so XCUITest can enumerate Dart tests within its "preparing to
    // run" timeout. Debug-only: in Release this double-registers plugins (once
    // against the AppDelegate registry, once against the engine registry via
    // didInitializeImplicitFlutterEngine), and one of them asserts in
    // registerWithRegistrar:, crashing the app at launch.
    GeneratedPluginRegistrant.register(with: self)
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Re-register against the actual engine registry. Flutter deduplicates
    // internally, so this is cheap — keeps the deferred path working for
    // plugins that only register via this protocol.
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "HoodikBackupGuard")?.messenger() {
      registerBackupChannel(messenger: messenger)
    }
  }

  /// Excludes the local database (and its WAL/SHM sidecars) from iCloud/iTunes
  /// backups on request from Dart — see lib/core/storage/no_backup.dart. The DB
  /// holds only sealed key material, but a backup is still one more place it
  /// should never land.
  private func registerBackupChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "io.hoodik.app/backup",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
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
  }
}
