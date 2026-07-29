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
    tmpDir = Directory.systemTemp.createTempSync('hoodik-invariants-');
    _initGitRepo(tmpDir.path);
    _copyScripts(scriptsDir.path, tmpDir.path);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('invariants.sh', () {
    test('forbidden marker added to lib/ fails with exit code 6', () {
      _tagCurrentHead(tmpDir.path, 'v0.0.1');
      _writeFile(tmpDir, p.join('lib', 'smoke.dart'), '''
void main() {
  // TODO: placeholder
}
''');
      final result = _runInvariants(tmpDir.path);
      expect(result.exitCode, 6, reason: result.stdout + result.stderr);
      expect(result.stdout, contains('forbidden_markers'));
      expect(result.stdout + result.stderr, contains('TODO'));
    });

    test('forbidden marker under lib/src/rust/ is excluded', () {
      _tagCurrentHead(tmpDir.path, 'v0.0.1');
      _writeFile(tmpDir, p.join('lib', 'src', 'rust', 'generated.dart'), '''
// TODO: generated code should be exempt
void main() {}
''');
      final result = _runInvariants(tmpDir.path);
      expect(
        result.stdout,
        contains('forbidden_markers    ok'),
        reason: result.stdout + result.stderr,
      );
    });

    test('new .dart file over 500 lines fails with exit code 6', () {
      _tagCurrentHead(tmpDir.path, 'v0.0.1');
      final buffer = StringBuffer('void main() {}\n');
      for (var i = 0; i < 600; i++) {
        buffer.writeln('// line $i');
      }
      _writeFile(tmpDir, p.join('lib', 'huge.dart'), buffer.toString());
      final result = _runInvariants(tmpDir.path);
      expect(result.exitCode, 6, reason: result.stdout + result.stderr);
      expect(result.stdout + result.stderr, contains('huge.dart'));
      expect(result.stdout + result.stderr, contains('ceiling'));
    });

    test('grandfather file that shrunk below baseline passes', () {
      _writeFile(
        tmpDir,
        p.join('lib', 'legacy.dart'),
        List.generate(400, (i) => '// baseline line $i').join('\n'),
      );
      _writeFile(
        tmpDir,
        p.join('scripts', 'release-check', 'grandfather.json'),
        '''
{
  "baselineTag": "v0.0.1",
  "baselineDate": "2026-04-20",
  "files": [
    {"path": "lib/legacy.dart", "lines": 500, "target": 300}
  ]
}
''',
      );
      _commitAll(tmpDir.path, 'grandfather baseline');
      _tagHead(tmpDir.path, 'v0.0.1');
      final result = _runInvariants(tmpDir.path);
      expect(
        result.stdout,
        contains('grandfather          ok'),
        reason: result.stdout + result.stderr,
      );
    });

    test('grandfather file that grew past baseline fails', () {
      _writeFile(
        tmpDir,
        p.join('lib', 'legacy.dart'),
        List.generate(400, (i) => '// line $i').join('\n'),
      );
      _writeFile(
        tmpDir,
        p.join('scripts', 'release-check', 'grandfather.json'),
        '''
{
  "baselineTag": "v0.0.1",
  "baselineDate": "2026-04-20",
  "files": [
    {"path": "lib/legacy.dart", "lines": 300, "target": 200}
  ]
}
''',
      );
      _commitAll(tmpDir.path, 'baseline too small');
      _tagHead(tmpDir.path, 'v0.0.1');
      final result = _runInvariants(tmpDir.path);
      expect(result.exitCode, 6, reason: result.stdout + result.stderr);
      expect(
        result.stdout,
        contains('grandfather          fail'),
        reason: result.stdout + result.stderr,
      );
    });

    test('repo with no git tag drops into permissive mode and passes', () {
      _writeFile(tmpDir, p.join('lib', 'ok.dart'), 'void main() {}\n');
      final result = _runInvariants(tmpDir.path);
      expect(result.exitCode, 0, reason: result.stdout + result.stderr);
      expect(
        result.stdout,
        contains('permissive mode'),
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

void _tagCurrentHead(String path, String tag) {
  _commitAll(path, 'baseline');
  _git(path, ['tag', tag]);
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

ProcessResult _runInvariants(String cwd) {
  return Process.runSync('bash', [
    'scripts/release-check/invariants.sh',
  ], workingDirectory: cwd);
}
