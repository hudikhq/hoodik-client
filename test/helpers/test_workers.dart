import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/api/api_client.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';
import 'package:hoodik_app/core/workers/worker_manager.dart';

class _WorkerApiClient extends Fake implements ApiClient {}

/// Spawn the real worker isolates for tests that exercise the encrypt path.
/// The note pipeline refuses to run without a live encrypt worker, so tests
/// covering it drive the same isolate the app does. Call from `setUpAll` and
/// dispose in `tearDownAll`.
Future<WorkerManager> startTestWorkers() async {
  final wm = WorkerManager(
    transferManager: TransferManager(),
    apiClient: _WorkerApiClient(),
  );
  await wm.init(baseUrl: 'https://unused.invalid');
  if (!wm.encryptWorkerActive) {
    throw StateError('encrypt worker failed to start in test harness');
  }
  return wm;
}
