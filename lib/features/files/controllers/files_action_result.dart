import '../../../core/widgets/app_notification.dart';

/// Outcome of a file operation that the UI surfaces as a snackbar.
///
/// A `null` result from a controller method means "nothing to show" —
/// typically because the user cancelled a picker or the controller
/// already dispatched its own progress message via a callback.
class FilesActionResult {
  final String message;
  final NotificationType type;

  const FilesActionResult._(this.message, this.type);

  const FilesActionResult.success(String message)
    : this._(message, NotificationType.success);

  const FilesActionResult.error(String message)
    : this._(message, NotificationType.error);

  const FilesActionResult.info(String message)
    : this._(message, NotificationType.info);
}
