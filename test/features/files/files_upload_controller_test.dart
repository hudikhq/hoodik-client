import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/providers.dart';
import 'package:hoodik_app/core/services/file_operations.dart';
import 'package:hoodik_app/features/files/controllers/files_upload_controller.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeFileOperations extends Fake implements FileOperations {}

/// Reports the load phase the way the iOS/Android native side does —
/// `picking` once asset export starts, `done` when finished — then
/// completes with no files, as if the user cancelled.
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakeFilePicker(this.container, {this.throwAfterLoading = false});

  final ProviderContainer container;
  final bool throwAfterLoading;

  /// [uploadPreparingProvider] observed right after the native side
  /// signalled `picking` — the moment the "Preparing…" overlay must show.
  bool? preparingDuringLoad;

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
}
