/// ローカルの `dist` ディレクトリから配信ファイルを読む.
///
/// ★このファイルと lib/native.dart が loveca_db で唯一 `dart:io` を import する★
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

  /// ★★ バイト列で読む (決定 D121-1 = 画-5) ★★
  /// ★`readAsString` を通さない —— 画像は UTF-8 として復号できないので、
  ///   ★★その場で `FileSystemException` になる★★ (実測。既定は
  ///   `allowMalformed: false`)。★黙って壊れるのではなく **読めない**。
  ///   ★仮に通したとしても置換文字に化けて元に戻せない。
  @override
  Future<List<int>> readBytes(String path) async {
    readPaths.add(path);
    return File('${root.path}/$path').readAsBytes();
  }
}
