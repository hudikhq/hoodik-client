import 'package:dio/dio.dart';

import 'connectivity_error.dart';
import 'l10n_lookup.dart';

/// Map an exception to copy a user can act on, mirroring the status-code
/// mapping the login screen established. Connectivity failures and HTTP
/// statuses get localized messages; anything else falls back to the
/// exception's own text (with the `Exception: ` prefix stripped), since
/// app-thrown exceptions already carry human-written messages.
String humanizeError(Object error) {
  if (isConnectivityError(error)) return ambientL10n.errorNoConnection;
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == null) return ambientL10n.errorNoConnection;
    if (status == 401 || status == 403) return ambientL10n.errorNotAuthorized;
    if (status >= 500) return ambientL10n.errorServerUnavailable;
    return ambientL10n.errorRequestFailed(status);
  }
  return error.toString().replaceFirst('Exception: ', '');
}
