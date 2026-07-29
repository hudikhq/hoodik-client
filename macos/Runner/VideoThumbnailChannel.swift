import Cocoa
import FlutterMacOS
import AVFoundation

/// Native macOS implementation of video-thumbnail extraction. The
/// `video_thumbnail` Flutter package only ships Android + iOS impls,
/// so the macOS app has its own thin bridge that uses
/// `AVAssetImageGenerator` to pull a single PNG-encoded frame at the
/// requested timestamp.
///
/// Method-channel contract (matches the Dart side in
/// `lib/core/services/thumbnail_generator.dart`):
///
///   • channel name: `io.hoodik.app/thumbnail`
///   • method:        `videoThumbnail`
///   • arguments:     `{ "path": String, "maxDimension": Int, "timeMs": Int }`
///   • returns:       `FlutterStandardTypedData(bytes:)` (PNG) or null on
///                    decode failure; `FlutterError` for argument /
///                    extraction errors.
///
/// Thread model: the AV image generator can spend tens of ms decoding,
/// so the actual extraction runs on a background queue and the
/// FlutterResult is hopped back to main before being called.
enum VideoThumbnailChannel {
    static let channelName = "io.hoodik.app/thumbnail"

    static func register(with binaryMessenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "videoThumbnail":
                handleVideoThumbnail(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func handleVideoThumbnail(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String, !path.isEmpty else {
            result(FlutterError(
                code: "BAD_ARG",
                message: "videoThumbnail requires {path: String, ...}",
                details: nil
            ))
            return
        }
        let maxDimension = (args["maxDimension"] as? Int) ?? 200
        let timeMs = (args["timeMs"] as? Int) ?? 1000

        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        // `maximumSize` aspect-fits the frame inside this box — the
        // resulting PNG is at most maxDimension on its longer side.
        generator.maximumSize = CGSize(
            width: CGFloat(maxDimension),
            height: CGFloat(maxDimension)
        )
        // Sub-second seek tolerance keeps the thumbnail near the
        // requested timestamp without forcing a frame-accurate seek
        // (which can be expensive on long videos).
        generator.requestedTimeToleranceBefore = CMTime(value: 500, timescale: 1000)
        generator.requestedTimeToleranceAfter = CMTime(value: 500, timescale: 1000)

        let cmTime = CMTime(value: Int64(timeMs), timescale: 1000)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                guard let pngData = bitmapRep.representation(
                    using: .png,
                    properties: [:]
                ) else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "ENCODE_FAILED",
                            message: "Failed to encode extracted frame as PNG",
                            details: nil
                        ))
                    }
                    return
                }
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: pngData))
                }
            } catch {
                // Most common reason here is the file is unreadable
                // (sandbox quirk) or has no decodable video track at
                // the requested time. The Dart side downgrades any
                // FlutterError to "no thumbnail" — uploads still
                // succeed.
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "EXTRACT_FAILED",
                        message: error.localizedDescription,
                        details: String(describing: error)
                    ))
                }
            }
        }
    }
}
