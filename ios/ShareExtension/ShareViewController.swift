/// Share Extension for Hoodik.
///
/// Subclasses `FSIShareViewController` (copied locally from `flutter_sharing_intent`)
/// so the shared files are saved in the exact format the Flutter plugin expects
/// (encoded `SharedFile` array in the App Group's UserDefaults).
///
/// The controller is embedded directly rather than imported via module to avoid
/// pulling Flutter framework dependencies into the app extension.
class ShareViewController: FSIShareViewController {

}
