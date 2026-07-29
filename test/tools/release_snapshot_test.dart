import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final repoRoot = _findRepoRoot();
  final scriptsDir = Directory(p.join(repoRoot, 'scripts', 'release-check'));
  if (!scriptsDir.existsSync()) {
    throw StateError('scripts/release-check not found at ${scriptsDir.path}');
  }

  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('hoodik-release-snapshot-');
    _initGitRepo(tmpDir.path);
    _copyScripts(scriptsDir.path, tmpDir.path);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('release-snapshot.sh', () {
    test('rewrites line counts + baselineTag + baselineDate', () {
      _writeFile(
        tmpDir,
        p.join('lib', 'legacy.dart'),
        List.generate(123, (i) => '// line $i').join('\n'),
      );
      _writeFile(
        tmpDir,
        p.join('scripts', 'release-check', 'grandfather.json'),
        '''
{
  "baselineTag": "v0.0.1",
  "baselineDate": "2026-01-01",
  "files": [
    {"path": "lib/legacy.dart", "lines": 500, "target": 300}
  ]
}
''',
      );
      _commitAll(tmpDir.path, 'baseline');
      _tagHead(tmpDir.path, 'v1.2.3');

      final result = _runSnapshot(tmpDir.path);
      expect(result.exitCode, 0, reason: result.stdout + result.stderr);

      final updated = _readGrandfather(tmpDir.path);
      expect(updated['baselineTag'], 'v1.2.3');
      final today = DateTime.now().toUtc();
      final todayStr =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(updated['baselineDate'], todayStr);

      final files = (updated['files'] as List).cast<Map<String, dynamic>>();
      expect(files, hasLength(1));
      expect(files[0]['path'], 'lib/legacy.dart');
      expect(files[0]['lines'], 123);
      expect(files[0]['target'], 300);

      expect(result.stdout, contains('baseline updated to v1.2.3'));
      expect(result.stdout, contains('500 -> 123'));
    });

    test('drops entries whose files no longer exist', () {
      _writeFile(
        tmpDir,
        p.join('lib', 'kept.dart'),
        List.generate(50, (i) => '// line $i').join('\n'),
      );
      _writeFile(
        tmpDir,
        p.join('scripts', 'release-check', 'grandfather.json'),
        '''
{
  "baselineTag": "v0.0.1",
  "baselineDate": "2026-01-01",
  "files": [
    {"path": "lib/kept.dart", "lines": 400, "target": 200},
    {"path": "lib/gone.dart", "lines": 900, "target": 500}
  ]
}
''',
      );
      _commitAll(tmpDir.path, 'before snapshot');
      _tagHead(tmpDir.path, 'v2.0.0');

      final result = _runSnapshot(tmpDir.path);
      expect(result.exitCode, 0, reason: result.stdout + result.stderr);

      final updated = _readGrandfather(tmpDir.path);
      final files = (updated['files'] as List).cast<Map<String, dynamic>>();
      expect(files, hasLength(1));
      expect(files[0]['path'], 'lib/kept.dart');
      expect(files[0]['lines'], 50);
      expect(result.stdout, contains('lib/gone.dart: 900 -> removed'));
    });

    test('fails clearly when no git tag exists', () {
      _writeFile(
        tmpDir,
        p.join('lib', 'legacy.dart'),
        List.generate(10, (i) => '// line $i').join('\n'),
      );
      _writeFile(
        tmpDir,
        p.join('scripts', 'release-check', 'grandfather.json'),
        '''
{
  "baselineTag": "v0.0.0",
  "baselineDate": "2026-01-01",
  "files": [
    {"path": "lib/legacy.dart", "lines": 500, "target": 300}
  ]
}
''',
      );
      _commitAll(tmpDir.path, 'baseline without tag');

      final result = _runSnapshot(tmpDir.path);
      expect(result.exitCode, isNonZero);
      expect(
        result.stderr,
        contains('no git tag found'),
        reason: result.stdout + result.stderr,
      );
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(dir.path, 'scripts', 'release-check')).existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('Could not find repo root from ${Directory.current.path}');
}

void _initGitRepo(String path) {
  _git(path, ['init', '-q']);
  _git(path, ['config', 'commit.gpgsign', 'false']);
  _git(path, ['config', 'user.email', 'tools-test@hoodik.local']);
  _git(path, ['config', 'user.name', 'tools-test']);
  _git(path, ['commit', '--allow-empty', '-m', 'init', '-q']);
}

void _copyScripts(String scriptsDir, String tmpRoot) {
  final dest = Directory(p.join(tmpRoot, 'scripts', 'release-check'));
  dest.createSync(recursive: true);
  _copyDirContents(scriptsDir, dest.path);
}

void _copyDirContents(String src, String dst) {
  for (final entity in Directory(src).listSync(recursive: false)) {
    final name = p.basename(entity.path);
    final target = p.join(dst, name);
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
      _copyDirContents(entity.path, target);
    } else if (entity is File) {
      entity.copySync(target);
      if (name.endsWith('.sh')) {
        Process.runSync('chmod', ['+x', target]);
      }
    }
  }
}

void _writeFile(Directory root, String relative, String content) {
  final file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void _commitAll(String path, String message) {
  _git(path, ['add', '-A']);
  _git(path, ['commit', '-m', message, '-q']);
}

void _tagHead(String path, String tag) {
  _git(path, ['tag', tag]);
}

void _git(String cwd, List<String> args) {
  final r = Process.runSync('git', args, workingDirectory: cwd);
  if (r.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed in $cwd:\n${r.stderr}');
  }
}

ProcessResult _runSnapshot(String cwd) {
  return Process.runSync('bash', [
    'scripts/release-check/release-snapshot.sh',
  ], workingDirectory: cwd);
}

Map<String, dynamic> _readGrandfather(String cwd) {
  final file = File(
    p.join(cwd, 'scripts', 'release-check', 'grandfather.json'),
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}
