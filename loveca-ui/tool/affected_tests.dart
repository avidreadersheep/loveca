/// ★★ 変更されたファイルから「★どのパッケージの試験を走らせる必要が在るか」を判定する ★★
///
/// ★★ なぜ置くか —— ★★D-15 (j) を 1 件踏んだからである（2026-09-03）★★ ★★
/// ★`loveca_core` の `DeckValidator.canAdd` の意味を変えた回に、
/// ★★`loveca-core` と `loveca-ui` だけを走らせて「`loveca-db` は 280 のまま」と書いた★★。
/// ★**`loveca-db` は `canAdd` を引いており、★★実際には 1 件落ちていた★★**。
/// → ★**作法を「★`loveca_core` の公開の口の意味を変えるときは 5 パッケージ全部を走らせる」にした。**
/// → ★★**しかし★人が守る作法は忘れられる**★★（**D-2** —— ★★同じ回で実際に忘れた★★）。
///
/// ★★ この道具は「★強制」しない。★★判定★★するだけである ★★
/// ★**強制はできない** —— ★★試験を走らせるのは人であり、★走らせなかったことを★この道具は観測できない★★
/// （★★**隠さない**★★ / **D-28**）。
/// ★**できるのは「★★何を走らせる必要が在るか★★」を★変更から導いて出すことだけである。**
///
/// ★★ 判定の根は★リポジトリである。★決め打ちの一覧を持たない（**D-31**）★★
/// ★**パッケージは★`pubspec.yaml` を実際に探して見つける。**
/// ★**依存の向きも★`pubspec.yaml` の `path:` から読む**（★書き写さない）。
/// → ★**パッケージを 1 つ足しても★この道具は自分で気づく**（★受けは `test/docs/affected_tests_test.dart`）。
///
/// ★★ 使い方 ★★
///
///     cd loveca-ui && dart run tool/affected_tests.dart             ★git から変更を読む
///     cd loveca-ui && dart run tool/affected_tests.dart --files a b ★字面で渡す（★試験もこの口を使う）
///
/// ★★ git から読むときに見るもの（★3 つとも見る）★★
/// ★`git status --porcelain`（★作業ツリー ＋ ★★ステージ済み ＋ ★未追跡★★）と
/// ★`git diff HEAD --name-only`。
/// ★★**未追跡とステージ済みを両方見る**★★ ——
/// ★**D-40 / D-43 が★どちらも「その回に新しく置いたファイル」で踏んだ型である。**
///
/// ★★ 覆わないもの（★言い切る）★★
/// ★**1) 走らせたかどうか** —— ★★観測できない★★（上のとおり）。
/// ★**2) 「先に数える」の中身** —— ★★どの試験が落ちるかは★走らせないと分からない★★。
/// ★**3) 依存が `pubspec.yaml` に現れない結びつき** —— ★例: ★★HTTP 越しのやり取りの形★★
///   （**D126-3** —— ★`loveca-server` と `loveca-ui` は★★依存を 1 本も持たないのに★鍵の字面を共有している★★）。
///   → ★★**その手当ては★走査テストの側に在る**★★（★この道具は 1 ミリも助けない）。
library;

import 'dart:io';

/// パッケージ 1 つ。★[dir] はリポジトリ相対（POSIX）。
typedef PackageSpec = ({
  String dir,
  String name,
  String command,
  Set<String> deps,
});

/// ★リポジトリのルート以下から★パッケージを見つける。
///
/// ★★ 2 種類ある。★混ぜない ★★
/// ★**Dart / Flutter** ＝ `pubspec.yaml` を持つディレクトリ。
/// ★**Python** ＝ `tests/run_all.py` を持つディレクトリ（`CLAUDE.md` §3 が★その形で走らせている）。
List<PackageSpec> discoverPackages(String repoRoot) {
  final out = <PackageSpec>[];
  final root = Directory(repoRoot);
  if (!root.existsSync()) return out;
  final children = root.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final child in children) {
    final dir = child.path.split(Platform.pathSeparator).last;
    if (dir.startsWith('.')) continue;
    final pubspec = File('${child.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final text = pubspec.readAsStringSync();
      out.add((
        dir: dir,
        name: pubspecName(text) ?? dir,
        command: usesFlutter(text) ? 'flutter test' : 'dart test',
        deps: pathDependencyDirs(text),
      ));
      continue;
    }
    if (File('${child.path}/tests/run_all.py').existsSync()) {
      out.add((
        dir: dir,
        name: dir,
        command: 'python tests/run_all.py',
        deps: <String>{},
      ));
    }
  }
  return out;
}

/// ★pubspec の `name:`。
String? pubspecName(String pubspec) {
  for (final line in pubspec.split('\n')) {
    if (line.startsWith('name:')) return line.substring(5).trim();
  }
  return null;
}

/// ★`flutter test` で走るか。
///
/// ★★ 字面を広げない（**D-37 の裏**）★★
/// ★見るのは `sdk: flutter` の行だけである。★★`flutter:` という語だけでは足りない★★ ——
/// ★`loveca-ui` の pubspec には★アセットの節の `flutter:` も在り、★それは依存ではない。
bool usesFlutter(String pubspec) =>
    RegExp(r'^\s+sdk:\s*flutter\s*$', multiLine: true).hasMatch(pubspec);

/// ★`path:` で引かれている★同じリポジトリ内のディレクトリ名。
///
/// ★★ 名前ではなくディレクトリで持つ ★★
/// ★パッケージ名（`loveca_core`）とディレクトリ名（`loveca-core`）は★★字面が違う★★。
/// ★**変更されたファイルのパスと突き合わせるのはディレクトリのほうである。**
Set<String> pathDependencyDirs(String pubspec) {
  final out = <String>{};
  for (final m in RegExp(r'^\s+path:\s*\.\./([^\s#]+)\s*$', multiLine: true)
      .allMatches(pubspec)) {
    out.add(m.group(1)!.replaceAll(RegExp(r'/+$'), ''));
  }
  return out;
}

/// ★[packages] の★**逆向き**の推移閉包。★ディレクトリ名 → そこに依存するもの全部。
///
/// ★★ ここが D-15 (j) の本体である ★★
/// ★`loveca-core` が変われば `loveca-db` と `loveca-ui` の試験が★★動きうる★★。
/// ★**「動きうる」であって「動く」ではない**（★★走らせないと分からない★★ / **D-28**）。
Map<String, Set<String>> dependentsOf(List<PackageSpec> packages) {
  final direct = <String, Set<String>>{
    for (final p in packages) p.dir: <String>{},
  };
  for (final p in packages) {
    for (final dep in p.deps) {
      direct.putIfAbsent(dep, () => <String>{}).add(p.dir);
    }
  }
  final closure = <String, Set<String>>{};
  for (final start in direct.keys) {
    final seen = <String>{};
    final stack = <String>[...(direct[start] ?? const <String>{})];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (!seen.add(cur)) continue;
      stack.addAll(direct[cur] ?? const <String>{});
    }
    closure[start] = seen;
  }
  return closure;
}

/// ★変更されたファイル [changedPaths]（★リポジトリ相対 / POSIX）から、
/// ★★走らせる必要が在るパッケージのディレクトリ名★★を返す。
///
/// ★★ 規則は 3 つ。★1 つずつ理由を書く ★★
/// ★**(1)** ★パッケージの下のファイルが変われば★そのパッケージ。
/// ★**(2)** ★そのパッケージに（推移的に）依存するものも全部
///          （★★これを落としたのが D-15 (j) の 1 件である★★）。
/// ★**(3)** ★★どのパッケージにも属さないファイル★★（`docs/` / ★リポジトリ直下の `.md` など）が変われば、
///          ★★`test/docs/` を持つパッケージ★★（＝ [docWatchers]）。
///          ★**理由**: ★★そこの試験がリポジトリの文書を実際に読んでいる★★
///          （★件数の台帳 / ★報告の規約 / ★決定番号 / ★測定の日付 / ★偽と測った主張の写し）。
Set<String> affectedPackages({
  required List<PackageSpec> packages,
  required Set<String> docWatchers,
  required Iterable<String> changedPaths,
}) {
  final dependents = dependentsOf(packages);
  final dirs = {for (final p in packages) p.dir};
  final out = <String>{};
  for (final raw in changedPaths) {
    final path = raw.replaceAll('\\', '/').trim();
    if (path.isEmpty) continue;
    final owner = ownerOf(path, dirs);
    if (owner == null) {
      // ★(3) ★どのパッケージにも属さない。
      out.addAll(docWatchers);
      continue;
    }
    out.add(owner); // ★(1)
    out.addAll(dependents[owner] ?? const <String>{}); // ★(2)
  }
  return out;
}

/// ★[path] を持つパッケージ。★無ければ `null`。
///
/// ★★ 先頭一致で見る。★名前一致では見ない ★★
/// ★`loveca-core/lib/src/rules/deck_validator.dart` の持ち主は★★先頭の段★★である。
/// ★**名前で当てると `docs/loveca-core の話.md` のようなパスまで拾う**（★★持ち主ではない★★）。
String? ownerOf(String path, Set<String> dirs) {
  for (final dir in dirs) {
    if (path == dir || path.startsWith('$dir/')) return dir;
  }
  return null;
}

/// ★`test/docs/` を持つパッケージ。★規則 (3) の宛先。
Set<String> docWatcherDirs(String repoRoot, List<PackageSpec> packages) => {
      for (final p in packages)
        if (Directory('$repoRoot/${p.dir}/test/docs').existsSync()) p.dir,
    };

/// ★git から変更されたパスを読む。★★3 つとも見る★★（★doc の「git から読むときに見るもの」）。
Set<String> changedPathsFromGit(String repoRoot) {
  final out = <String>{};
  final porcelain = Process.runSync('git', ['status', '--porcelain'],
      workingDirectory: repoRoot);
  for (final line in (porcelain.stdout as String).split('\n')) {
    if (line.length < 4) continue;
    final path = line.substring(3).trim();
    // ★改名は `旧 -> 新` の形で出る。★両方見る。
    if (path.contains(' -> ')) {
      out.addAll(path.split(' -> ').map((s) => s.replaceAll('"', '').trim()));
      continue;
    }
    out.add(path.replaceAll('"', ''));
  }
  final diff = Process.runSync('git', ['diff', 'HEAD', '--name-only'],
      workingDirectory: repoRoot);
  out.addAll((diff.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty));
  return out;
}

void main(List<String> args) {
  // ★この道具は `loveca-ui/` から走る（★`tool/` の先例と同じ）。★リポジトリのルートは 1 つ上。
  const repoRoot = '..';
  final packages = discoverPackages(repoRoot);
  final watchers = docWatcherDirs(repoRoot, packages);

  final Set<String> changed;
  final filesIndex = args.indexOf('--files');
  if (filesIndex >= 0) {
    changed = args.sublist(filesIndex + 1).toSet();
  } else {
    changed = changedPathsFromGit(repoRoot);
  }

  if (changed.isEmpty) {
    stdout.writeln('変更されたファイルが 1 つも無い。');
    return;
  }

  final affected = affectedPackages(
      packages: packages, docWatchers: watchers, changedPaths: changed);

  stdout.writeln('変更 ${changed.length} 件 / '
      '走らせる必要が在るのは ${affected.length} パッケージ');
  final byDir = {for (final p in packages) p.dir: p};
  for (final dir in affected.toList()..sort()) {
    final pkg = byDir[dir];
    if (pkg == null) continue;
    stdout.writeln('  cd $dir && ${pkg.command}');
  }
  final skipped = (byDir.keys.toSet()..removeAll(affected)).toList()..sort();
  if (skipped.isNotEmpty) {
    stdout.writeln('走らせなくてよい: ${skipped.join(' / ')}');
  }
}
