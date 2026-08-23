/// 配信ファイルの取得手段.
///
/// ★取得手段を抽象にしてある理由★
/// 取り込みロジックを `dart:io` からも HTTP からも切り離しておくと、
/// テストがメモリ上で完結し、Phase 4 で配信経路が固まったときに
/// この実装だけを足せば済む。
library;

/// `manifest.json` の `path` を渡すと中身の文字列を返す。
abstract interface class MasterFileSource {
  Future<String> read(String path);
}

/// メモリ上の辞書から返す。テスト用。
class MapMasterFileSource implements MasterFileSource {
  MapMasterFileSource(this.files);

  final Map<String, String> files;

  /// ★実際に読まれた path を記録する★
  /// 差分更新が「ハッシュの違うファイルだけ取る」になっているかを
  /// テストから確認するために要る。
  final List<String> readPaths = [];

  @override
  Future<String> read(String path) async {
    readPaths.add(path);
    final content = files[path];
    if (content == null) {
      throw StateError('配信物に $path がありません');
    }
    return content;
  }
}
