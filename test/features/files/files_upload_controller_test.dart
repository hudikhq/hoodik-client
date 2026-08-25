import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/core/services/media_picker_channel.dart';
import 'package:hoodik_app/core/services/sync_service.dart';
import 'package:hoodik_app/core/services/transfer_manager.dart';
import 'package:hoodik_app/features/files/controllers/files_upload_controller.dart';
import 'package:hoodik_app/features/files/providers/files_notifier.dart';
import 'package:hoodik_app/features/files/providers/files_state.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeFileOperations extends Fake implements FileOperations {}

class _ScriptedMediaPicker extends MediaPickerChannel {
  _ScriptedMediaPicker(this.events);

  final List<MediaPickEvent> events;

  @override
  Stream<MediaPickEvent> pickMedia() => Stream.fromIterable(events);
}

class _RecordingSyncService extends Fake
    with ChangeNotifier
    implements SyncService {
  final uploaded = <String>[];

  @override
  Future<void> uploadFileOrQueue({
    required String localPath,
    String? parentDirId,
  }) async {
    uploaded.add(localPath);
  }
}

class _QuietFilesNotifier extends FilesNotifier {
  @override
  FilesState build(String? arg) => FilesState();

  @override
  Future<void> load() async {}
}

/// Reports the load phase the way the iOS/Android native side does —
/// `picking` once asset export starts, `done` when finished — then
/// completes with no files, as if the user cancelled.
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakeFilePicker(this.container, {this.throwAfterLoading = false});

  final ProviderContainer container;
  final bool throwAfterLoading;

  /// [uploadPreparingProvider] observed right after the native side
  /// signalled `picking` — the moment the "Preparing…" feedback must show.
  bool? preparingDuringLoad;

  /// Types of the transfer rows visible at the same moment.
  List<TransferType>? transferTypesDuringLoad;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    onFileLoading?.call(FilePickerStatus.picking);
    preparingDuringLoad = container.read(uploadPreparingProvider);
    transferTypesDuringLoad = container
        .read(transferManagerProvider)
        .transfers
        .map((t) => t.type)
        .toList();
    if (throwAfterLoading) throw Exception('picker died mid-export');
    onFileLoading?.call(FilePickerStatus.done);
    return null;
  }
}

void main() {
  (ProviderContainer, FilesUploadController) setUpController({
    bool throwAfterLoading = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        fileOperationsProvider.overrideWithValue(_FakeFileOperations()),
      ],
    );
    addTearDown(container.dispose);
    FilePicker.platform = _FakeFilePicker(
      container,
      throwAfterLoading: throwAfterLoading,
    );
    return (container, container.read(filesUploadControllerProvider(null)));
  }

  test('media pick raises preparing during load and clears it after', () async {
    final (container, controller) = setUpController();

    final result = await controller.pickAndUploadMedia();

    expect(result, isNull);
    final picker = FilePicker.platform as _FakeFilePicker;
    expect(picker.preparingDuringLoad, isTrue);
    expect(container.read(uploadPreparingProvider), isFalse);
  });

  // The load phase renders as a transfer row rather than a blocking
  // overlay, and the row vanishes outright once the paths land — a
  // "prepared" entry in the done list would echo every upload after it.
  test('the load phase parks a transfer row and removes it after', () async {
    final (container, controller) = setUpController();
    final tm = container.read(transferManagerProvider);

    await controller.pickAndUploadMedia();

    expect(tm.transfers, isEmpty);

    final picker = FilePicker.platform as _FakeFilePicker;
    expect(picker.transferTypesDuringLoad, [TransferType.uploadPrepare]);
  });

  test('file pick raises preparing during load and clears it after', () async {
    final (container, controller) = setUpController();

    final result = await controller.pickAndUploadFiles();

    expect(result, isNull);
    final picker = FilePicker.platform as _FakeFilePicker;
    expect(picker.preparingDuringLoad, isTrue);
    expect(container.read(uploadPreparingProvider), isFalse);
  });

  test('preparing clears even when the picker throws', () async {
    final (container, controller) = setUpController(throwAfterLoading: true);

    await expectLater(controller.pickAndUploadMedia(), throwsException);

    expect(container.read(uploadPreparingProvider), isFalse);
  });

  // The native path: per-item rows carry the export, each file uploads the
  // moment it lands, a failed export stays visible as a failed row.
  group('native media pick', () {
    (ProviderContainer, FilesUploadController, _RecordingSyncService)
    setUpNative(List<MediaPickEvent> events) {
      MediaPickerChannel.supportedOverride = true;
      addTearDown(() => MediaPickerChannel.supportedOverride = null);

      final sync = _RecordingSyncService();
      final container = ProviderContainer(
        overrides: [
          fileOperationsProvider.overrideWithValue(_FakeFileOperations()),
          syncServiceProvider.overrideWith((ref) => sync),
          mediaPickerChannelProvider.overrideWithValue(
            _ScriptedMediaPicker(events),
          ),
          filesNotifierProvider.overrideWith(_QuietFilesNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      return (
        container,
        container.read(filesUploadControllerProvider(null)),
        sync,
      );
    }

    test('uploads each item as its export lands', () async {
      final (container, controller, sync) = setUpNative(const [
        MediaPickSelection([
          PickedMediaItem(index: 0, name: 'IMG_0001'),
          PickedMediaItem(index: 1, name: 'clip'),
        ]),
        MediaPickProgress(index: 0, fraction: 0.4),
        MediaPickReady(index: 0, path: '/tmp/IMG_0001.heic'),
        MediaPickReady(index: 1, path: '/tmp/clip.mov'),
      ]);

      final result = await controller.pickAndUploadMedia();

      expect(result, isNull);
      expect(sync.uploaded, ['/tmp/IMG_0001.heic', '/tmp/clip.mov']);
      expect(container.read(transferManagerProvider).transfers, isEmpty);
    });

    test('a failed export stays visible and surfaces the error', () async {
      final (container, controller, sync) = setUpNative(const [
        MediaPickSelection([
          PickedMediaItem(index: 0, name: 'good'),
          PickedMediaItem(index: 1, name: 'bad'),
        ]),
        MediaPickReady(index: 0, path: '/tmp/good.mov'),
        MediaPickFailed(index: 1, message: 'iCloud download failed'),
      ]);

      final result = await controller.pickAndUploadMedia();

      expect(result, isNotNull);
      expect(sync.uploaded, ['/tmp/good.mov']);
      final rows = container.read(transferManagerProvider).transfers;
      expect(rows, hasLength(1));
      expect(rows.single.fileName, 'bad');
      expect(rows.single.status, TransferStatus.failed);
    });

    test('a cancelled sheet uploads nothing', () async {
      final (container, controller, sync) = setUpNative(const [
        MediaPickSelection([]),
      ]);

      final result = await controller.pickAndUploadMedia();

      expect(result, isNull);
      expect(sync.uploaded, isEmpty);
      expect(container.read(transferManagerProvider).transfers, isEmpty);
    });
  });
}
