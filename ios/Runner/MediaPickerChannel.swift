import Flutter
import PhotosUI
import UIKit

/// Streams the Photos picker's load phase to Dart, one event at a time.
///
/// The plugin picker's future only completes once every selected asset has
/// been exported, with no per-item signal — a slow iCloud video leaves the
/// UI guessing for its whole download. PHPicker hands over its results the
/// moment the user confirms, and each `loadFileRepresentation` exposes an
/// `NSProgress`; this channel forwards both so the transfer overlay can
/// show named rows with real fractions while the exports run.
///
/// Events, all main-thread:
///   {type: "picked",   items: [{index, name}]}   — sheet dismissed
///   {type: "progress", index, fraction}          — export/download progress
///   {type: "ready",    index, path}              — file copied into our tmp
///   {type: "failed",   index, message}
///   {type: "done"}                               — every item settled
final class MediaPickerChannel: NSObject {
  static let shared = MediaPickerChannel()

  /// Exports run this many at a time. Selecting ten 4K videos must not
  /// start ten simultaneous transcodes.
  private static let maxConcurrentLoads = 3

  private var events: FlutterEventSink?
  private var picking = false
  private var observations: [Int: NSKeyValueObservation] = [:]
  private var lastReportedPercent: [Int: Int] = [:]

  static func register(messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(
      name: "io.hoodik.app/media_picker",
      binaryMessenger: messenger
    )
    method.setMethodCallHandler { call, result in
      switch call.method {
      case "pick":
        shared.present(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let events = FlutterEventChannel(
      name: "io.hoodik.app/media_picker/events",
      binaryMessenger: messenger
    )
    events.setStreamHandler(shared)
  }

  private func present(result: @escaping FlutterResult) {
    guard !picking else {
      result(FlutterError(code: "BUSY", message: "picker already open", details: nil))
      return
    }
    guard let root = Self.topViewController() else {
      result(FlutterError(code: "NO_VC", message: "no view controller to present from", details: nil))
      return
    }

    var config = PHPickerConfiguration()
    config.selectionLimit = 0
    config.filter = .any(of: [.images, .videos])
    // Same representation the plugin picker shipped for years (it passes
    // allowCompression=true, which maps to .compatible): recipients get
    // H.264/JPEG they can open anywhere. Originals are a deliberate future
    // setting, not a side effect of the progress work.
    config.preferredAssetRepresentationMode = .compatible

    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    picking = true
    root.present(picker, animated: true)
    result(true)
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private func send(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.events?(payload)
    }
  }

  private func loadAll(_ results: [PHPickerResult]) {
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("picked_media_\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    // A serial queue owns the scheduling state; the loads themselves run on
    // the provider's own background machinery.
    let scheduler = DispatchQueue(label: "io.hoodik.media-picker")
    var pending = Array(results.enumerated())
    var active = 0
    var settled = 0

    func settle() {
      settled += 1
      active -= 1
      if settled == results.count {
        self.send(["type": "done"])
        scheduler.async { self.observations.removeAll() }
      } else {
        scheduleNext()
      }
    }

    func scheduleNext() {
      scheduler.async {
        while active < Self.maxConcurrentLoads, !pending.isEmpty {
          let (index, item) = pending.removeFirst()
          active += 1
          self.load(index: index, provider: item.itemProvider, into: destination) {
            scheduler.async { settle() }
          }
        }
      }
    }

    scheduleNext()
  }

  private func load(
    index: Int,
    provider: NSItemProvider,
    into destination: URL,
    completion: @escaping () -> Void
  ) {
    let movie = UTType.movie.identifier
    let image = UTType.image.identifier
    let typeId = provider.hasItemConformingToTypeIdentifier(movie)
      ? movie
      : provider.hasItemConformingToTypeIdentifier(image) ? image : UTType.data.identifier

    let progress = provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, error in
      self.observations[index] = nil
      guard let url else {
        self.send([
          "type": "failed",
          "index": index,
          "message": error?.localizedDescription ?? "load failed",
        ])
        completion()
        return
      }

      // The provider deletes its URL when this closure returns, so the copy
      // has to happen here and now.
      let target = destination.appendingPathComponent(url.lastPathComponent)
      do {
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: url, to: target)
        self.send(["type": "ready", "index": index, "path": target.path])
      } catch {
        self.send(["type": "failed", "index": index, "message": error.localizedDescription])
      }
      completion()
    }

    lastReportedPercent[index] = -1
    observations[index] = progress.observe(\.fractionCompleted) { progress, _ in
      let percent = Int(progress.fractionCompleted * 100)
      guard percent != self.lastReportedPercent[index] else { return }
      self.lastReportedPercent[index] = percent
      self.send([
        "type": "progress",
        "index": index,
        "fraction": progress.fractionCompleted,
      ])
    }
  }
}

extension MediaPickerChannel: PHPickerViewControllerDelegate {
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    picking = false

    let items: [[String: Any]] = results.enumerated().map { index, item in
      ["index": index, "name": item.itemProvider.suggestedName ?? "item-\(index + 1)"]
    }
    send(["type": "picked", "items": items])

    if results.isEmpty {
      send(["type": "done"])
      return
    }
    loadAll(results)
  }
}

extension MediaPickerChannel: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    events = eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    events = nil
    return nil
  }
}
