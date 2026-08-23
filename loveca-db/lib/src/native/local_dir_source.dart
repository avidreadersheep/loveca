/// ローカルの `dist` ディレクトリから配信ファイルを読む.
///
/// ★このファイルと open_sqlite.dart が loveca_db で唯一 `dart:io` に触れる場所★
///
/// 開発時の取り込みと、実データを使うテストのためのもの。
/// ネットワーク経由の実装は Phase 4 で配信経路が固まってから足す。
library;

import 'dart:io';

import '../import/master_file_source.dart';

class LocalDirectoryMasterFileSource implements MasterFileSource {
  LocalDirectoryMasterFileSource(this.root);

  /// `version.json` / `manifest.json` / `cards/` / `meta/` が入っているディレクトリ。
  final Directory root;

  /// 実際に読まれた path。差分更新の確認に使う。
  final List<String> readPaths = [];

  @override
  Future<String> read(String path) async {
    readPaths.add(path);
    return File('${root.path}/$path').readAsString();
  }
}
