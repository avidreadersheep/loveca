/// 配信ファイルの取得手段.
///
/// ★取得手段を抽象にしてある理由★
/// 取り込みロジックを `dart:io` からも HTTP からも切り離しておくと、
/// テストがメモリ上で完結し、Phase 4 で配信経路が固まったときに
/// この実装だけを足せば済む。
library;

import 'dart:convert';

/// `manifest.json` の `path` を渡すと中身を返す。
///
/// ★★ バイナリを運べる (決定 D121-1 = 画-5 / `docs/同期設計メモ.md` §32-6 の 6) ★★
/// 画像を配るには **バイト列** が要る。文字列しか返せないと WebP を通せない。
/// ★★壊れ方は 2 通りある。混ぜないこと (実測)★★ ——
///   (1) `dart:io` の `readAsString` は **投げる** (`FileSystemException`)。
///       既定は `allowMalformed: false` なので、黙って壊れるのではなく読めない。
///   (2) `allowMalformed` を許すと置換文字 (U+FFFD) に化け、**元に戻せない**。
/// → ★どちらにしてもテキスト経路では画像を運べない。[readBytes] を足した。
abstract interface class MasterFileSource {
  /// テキストとして読む (UTF-8)。
  Future<String> read(String path);

  /// バイト列として読む。
  ///
  /// ★画像はこちらを使う。★テキストにも使えるが、
  ///   カードの JSON は [read] のままでよい (読み方を 2 つ持たない)。
  Future<List<int>> readBytes(String path);
}

/// メモリ上の辞書から返す。テスト用。
class MapMasterFileSource implements MasterFileSource {
  MapMasterFileSource(this.files, {Map<String, List<int>>? binaries})
      : binaries = binaries ?? const {};

  final Map<String, String> files;

  /// ★バイト列で持ちたいもの (画像など)。
  ///
  /// ★[files] と分けてある —— **UTF-8 にできないバイト列** を
  ///   テストから渡せないと、[readBytes] が本当にバイトを運んでいるかを
  ///   確かめられない (文字列に畳んだ時点で差が消える)。
  final Map<String, List<int>> binaries;

  /// ★実際に読まれた path を記録する★
  /// 差分更新が「ハッシュの違うファイルだけ取る」になっているかを
  /// テストから確認するために要る。
  /// ★[read] と [readBytes] の両方を記録する (どちらで読んでも「読んだ」)。
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

  @override
  Future<List<int>> readBytes(String path) async {
    readPaths.add(path);
    final binary = binaries[path];
    if (binary != null) return binary;
    final content = files[path];
    if (content == null) {
      throw StateError('配信物に $path がありません');
    }
    return utf8.encode(content);
  }
}
