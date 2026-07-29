import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/utils/bundled_licenses.dart';

/// The editor bundle is minified, which strips the license banners of the
/// libraries inside it. MIT and Apache-2.0 both require the notice to travel
/// with every copy, so these entries are the app binary's only copy of it —
/// if this registration silently breaks, the shipped app is non-compliant and
/// nothing else would fail.
void main() {
  setUp(LicenseRegistry.reset);
  tearDown(LicenseRegistry.reset);

  Future<List<LicenseEntry>> collect() async {
    registerBundledEditorLicenses();
    return LicenseRegistry.licenses.toList();
  }

  test('registers every library bundled in the editor', () async {
    final packages = (await collect())
        .expand((entry) => entry.packages)
        .toSet();

    expect(packages, {'Milkdown', 'ProseMirror', 'refractor', 'DOMPurify'});
  });

  test('every entry carries non-trivial license text', () async {
    for (final entry in await collect()) {
      final text = entry.paragraphs.map((p) => p.text).join('\n');
      expect(
        text.length,
        greaterThan(200),
        reason: '${entry.packages.join(", ")} has suspiciously short text',
      );
      expect(text, contains('Copyright'));
    }
  });

  test(
    'the MIT entries carry the clause that obliges us to ship them',
    () async {
      final entries = await collect();
      for (final name in ['Milkdown', 'ProseMirror', 'refractor']) {
        final entry = entries.firstWhere((e) => e.packages.contains(name));
        final text = entry.paragraphs.map((p) => p.text).join(' ');
        expect(
          text,
          contains('shall be included in'),
          reason: '$name must retain the MIT inclusion clause',
        );
      }
    },
  );

  test('DOMPurify is taken under Apache-2.0, not MPL', () async {
    final entry = (await collect()).firstWhere(
      (e) => e.packages.contains('DOMPurify'),
    );
    final text = entry.paragraphs.map((p) => p.text).join(' ');

    // Choosing MPL-2.0 from the dual licence would oblige us to publish the
    // source of the MPL-covered files; Apache-2.0 only wants the notice.
    expect(text, contains('Apache License'));
    expect(text, contains('Cure53'));
  });
}
