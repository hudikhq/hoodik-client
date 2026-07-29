import '../../../core/api/api_client.dart';
import '../../../core/api/shares_models.dart';

/// Page through every incoming share and map each into a [FileItem] for the
/// "Shared with me" virtual folder. Shared by the files list notifier and the
/// tree view so both surface the recipient's shares identically.
Future<List<FileItem>> fetchIncomingShareItems(ApiClient client) async {
  const pageSize = 100;
  final shares = <IncomingShare>[];
  var offset = 0;
  while (true) {
    final page = await client.shares.getSharesMine(
      limit: pageSize,
      offset: offset,
    );
    shares.addAll(page.items);
    offset += page.items.length;
    if (page.items.isEmpty || shares.length >= page.total) break;
  }
  return shares.map(FileItem.fromIncomingShare).toList();
}

/// Whether the caller has at least one incoming share — the cheap `limit: 1`
/// probe that decides whether the synthetic "Shared with me" folder is shown.
Future<bool> hasIncomingShares(ApiClient client) async {
  final page = await client.shares.getSharesMine(limit: 1, offset: 0);
  return page.total > 0;
}
