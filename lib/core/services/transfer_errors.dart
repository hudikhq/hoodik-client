/// Thrown by the main-thread transfer loops when a user-initiated cancel
/// aborts an in-flight upload or download.
///
/// Callers catch by type so the cancellation doesn't surface as a generic
/// failure in the transfer overlay — the UI already marked the transfer
/// cancelled at the point the cancel request was observed.
class TransferCancelledException implements Exception {
  final String fileId;
  const TransferCancelledException(this.fileId);

  @override
  String toString() => 'Transfer cancelled';
}
