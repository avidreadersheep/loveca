/// 端末の領域へ画像を書く（★§32-6 の **8** の 2 番目 / 決定 **D149**）.
///
/// ★★ このファイルと `lib/native.dart` と `local_dir_source.dart` と
/// `open_sqlite.dart` が★loveca_db で `dart:io` を import する全部である ★★
/// （`CLAUDE.md` §2 —— ★★汚染範囲は `lib/native.dart` と `lib/src/native/` に閉じる★★）。
///
/// ## ★★ 置き場を★1 バイトも決めない ★★
///
/// ★**根は★呼び出し側が渡す**（★先例は `LocalDirectoryMasterFileSource` /
/// `AccountFileStore` / `DeviceFileStore` —— ★★どれも置き場を持たない★★）。
/// ★**決めるのは `loveca-ui` である**（`AppPaths` —— ★`path_provider` に触れてよい唯一の場所）。
///
/// ## ★★ 柵 —— ★★dist のディレクトリへ書かない（**D137-4** の柵 2）★★
///
/// ★**この class は★★渡された根の下にしか書かない★★**（★下の 2 段）。
/// ★**「その根が dist でないこと」は★★ここでは確かめられない★★** ——
///   ★**根が何であるかを★この class は知らない。★★配線の側で見る★★**
///   （`loveca-ui/test/data/master_repository_test.dart` の走査）。
///
/// ## ★★ 柵 —— ★★受け取った字面を★そのまま繋がない（**D134-7** / §60 と同じ 2 段）★★
///
/// ★**`path` は★★配信物のマニフェストに書かれた字面である★★**（★アプリが作った値ではない）。
/// → ★**段 1: ★区切りごとに見る ／ ★段 2: ★繋いだ結果が★根の下に在ることを確かめる。**
/// ★★**手当てを 2 つ重ねる**★★（★§60 が「片方だけ外しても落ちない」ことを測って記録した形）。
///
/// ## ★★ 一時ファイルへ書いて★置き換える（★先例は `DeckFileStore` / `DeviceFileStore`）★★
///
/// ★**途中で落ちても★★半分書けた画像が残らない★★**。
/// ★★**「安全である」とは書かない**★★（**D-28** —— ★★`.tmp` が残ることは在る★★）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../import/master_image_sink.dart';

/// 端末のディレクトリへ書く [MasterImageSink]。
class LocalDirectoryMasterImageSink implements MasterImageSink {
  LocalDirectoryMasterImageSink(this.root);

  /// 書き込む根。★★配信物の `images/...` を★この下に置く★★。
  final Directory root;

  /// 実際に書いた path（★試験と診断のため / ★`LocalDirectoryMasterFileSource` と同じ形）。
  final List<String> writtenPaths = [];

  /// 実際に消した path。
  final List<String> deletedPaths = [];

  @override
  Future<void> write(String path, List<int> bytes) async {
    final file = _fileFor(path);
    if (file == null) {
      // ★★ 投げる —— ★★黙って捨てない★★ ★★
      //   ★**`MasterImporter` は★ファイルごとに受けて★1 件ずつ記録する**（★実読）ので、
      //     ★★取り込み全体は止まらず、★この 1 件が「未解消」として残る★★。
      throw ArgumentError('★根の外を指す path: $path');
    }
    await file.parent.create(recursive: true);
    // ★★ 一時ファイルへ書いて置き換える ★★
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    writtenPaths.add(path);
  }

  @override
  Future<void> delete(String path) async {
    final file = _fileFor(path);
    // ★★ 無ければ黙って戻る（★`MasterImageSink` の契約）★★
    if (file == null) return;
    if (file.existsSync()) await file.delete();
    deletedPaths.add(path);
  }

  /// 根の下の実ファイルを返す。★★根の外を指していれば `null`★★。
  File? _fileFor(String path) {
    final segments = p.posix.split(path);
    // ★★ 段 1 —— ★区切りごとに見る（★`DistFileStore.isSafeSegments` と同じ規則）★★
    if (!isSafeImageSegments(segments)) return null;

    final rootPath = p.normalize(root.absolute.path);
    final file = File(p.joinAll(<String>[rootPath, ...segments]));

    // ★★ 段 2 —— ★繋いだ結果が★根の下に在ること ★★
    if (!p.isWithin(rootPath, p.normalize(file.absolute.path))) return null;
    return file;
  }

  /// ★段 1 —— ★区切りごとに見る。
  ///
  /// ★★ 断るもの（★★1 つずつ対で固定した★★）★★
  /// ★段が 0 個 ／ ★空の段 ／ ★`.` ／ ★`..` ／ ★区切り記号を含む段 ／ ★ドライブ（`:` を含む段）。
  static bool isSafeImageSegments(List<String> segments) {
    if (segments.isEmpty) return false;
    for (final s in segments) {
      if (s.isEmpty || s == '.' || s == '..') return false;
      if (s.contains(':')) return false;
      if (s.contains('/')) return false;
      if (s.contains(String.fromCharCode(92))) return false;
    }
    return true;
  }
}
