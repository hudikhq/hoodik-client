import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/api/shares_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scriptable [SharesClient] for the share-dialog widget tests. Each field is
/// pre-set by a test; methods record what the dialog sent and return the
/// scripted response (or throw the scripted error).
class FakeSharesClient extends Fake implements SharesClient {
  /// What `discoverUser` returns. When [discoverError] is set, the method
  /// throws it instead; a null result with no error models the 404 path.
  DiscoveredUser? discoverResult;
  DiscoverException? discoverError;
  String? lastDiscoverEmail;

  Map<String, dynamic>? createBody;
  bool throwOnCreate = false;

  (String, String, Map<String, dynamic>)? revokeArgs;

  List<AppShare> recipients = const [];

  /// The roster `getShareRecipients` serves once a share has been created.
  /// Models the server returning the freshly granted recipient, so a test can
  /// assert the dialog reloads the list after a successful grant. Left null
  /// when the roster shouldn't change.
  List<AppShare>? recipientsAfterCreate;

  int getRecipientsCalls = 0;

  @override
  Future<DiscoveredUser?> discoverUser(String email) async {
    lastDiscoverEmail = email;
    if (discoverError != null) throw discoverError!;
    return discoverResult;
  }

  @override
  Future<List<AppShare>> createShare(Map<String, dynamic> envelope) async {
    createBody = envelope;
    if (throwOnCreate) throw Exception('server rejected');
    if (recipientsAfterCreate != null) recipients = recipientsAfterCreate!;
    return const [];
  }

  @override
  Future<void> revokeShare(
    String fileId,
    String userId,
    Map<String, dynamic> body,
  ) async {
    revokeArgs = (fileId, userId, body);
  }

  @override
  Future<List<AppShare>> getShareRecipients(String fileId) async {
    getRecipientsCalls++;
    return recipients;
  }
}

class FakeApiClient extends Fake implements ApiClient {
  FakeApiClient(this._shares);

  final SharesClient _shares;

  @override
  SharesClient get shares => _shares;
}
