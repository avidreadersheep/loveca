/// 試作が触るパスの解決.
///
/// ★`loveca-data/data/` は読むだけ★
/// 書き込みは `loveca-ui/spike/.cache/` の下だけに閉じる（git 管理外）。
///
/// 実行時の CWD は `flutter run` の起動方法で変わるため、CWD には依存しない。
/// リポジトリのルート（`loveca-data` と `loveca-ui` を両方持つディレクトリ）を
/// 実行ファイルと CWD の両方から上へ探して確定させる。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// `--dart-define=LOVECA_DIST_DIR=...` で上書きできる。
const _distDefine = String.fromEnvironment('LOVECA_DIST_DIR');

class SpikePaths {
  SpikePaths._(this.repoRoot, this.distDir);

  final Directory repoRoot;
  final Directory distDir;

  static SpikePaths? _cached;

  static SpikePaths resolve() => _cached ??= _resolve();

  static SpikePaths _resolve() {
    final root = _findRepoRoot();

    Directory dist;
    if (_distDefine.isNotEmpty) {
      dist = Directory(_distDefine);
    } else if (Platform.environment['LOVECA_DIST_DIR'] case final v?
        when v.isNotEmpty) {
      dist = Directory(v);
    } else {
      dist = Directory(p.join(root.path, 'loveca-data', 'data', 'dist'));
    }
    return SpikePaths._(root, dist);
  }

  /// `loveca-data` と `loveca-ui` を両方持つディレクトリを上へ探す。
  static Directory _findRepoRoot() {
    for (final start in [
      Directory.current.path,
      p.dirname(Platform.resolvedExecutable),
    ]) {
      var dir = Directory(start).absolute;
      for (var i = 0; i < 12; i++) {
        final hasData = Directory(p.join(dir.path, 'loveca-data')).existsSync();
        final hasUi = Directory(p.join(dir.path, 'loveca-ui')).existsSync();
        if (hasData && hasUi) return dir;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    // 見つからなければ CWD を返す。呼び出し側が dist の不在として扱う。
    return Directory.current.absolute;
  }

  bool get distExists => distDir.existsSync();

  File get versionJson => File(p.join(distDir.path, 'version.json'));
  File get manifestJson => File(p.join(distDir.path, 'manifest.json'));

  Directory get thumbDir => Directory(p.join(distDir.path, 'images', 'thumb'));

  /// `imageHash` から thumb の実ファイルへ。
  ///
  /// ★URL / パスを組み立てて良いのはここまで★
  /// 公式サイトの `picture` からファイル名を組み立ててはいけない（CLAUDE.md §5-(3)）。
  /// dist の画像は `{imageHash}.webp` という**こちらが決めた**規約なので組み立てて良い。
  String thumbPath(String imageHash) =>
      p.join(thumbDir.path, '$imageHash.webp');

  /// 試作の書き込み先。git 管理外。
  Directory get cacheDir =>
      Directory(p.join(repoRoot.path, 'loveca-ui', 'spike', '.cache'));

  File get dbFile => File(p.join(cacheDir.path, 'loveca_spike.db'));

  Directory get measurementsDir =>
      Directory(p.join(cacheDir.path, 'measurements'));

  @override
  String toString() => 'repoRoot=${repoRoot.path}\ndist=${distDir.path} '
      '(exists=$distExists)\ncache=${cacheDir.path}';
}
