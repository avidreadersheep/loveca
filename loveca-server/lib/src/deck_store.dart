/// ★★ デッキの保管 —— ★★利用者 1 人につき JSON のファイル 1 つ（決定 **D134-6** ＝ 保-3）★★
///
/// ★★ §35-9 が「まだ決まっていない」と書いていた分である ★★
/// ★**D131-4** が★アカウントの保管を決め、★**§48-12 の 2** が
/// ★★**「デッキの保管は★別の量である。★寿命も大きさも違う」**★★ と書いた。
/// → ★**この回で決めた**（★軸 6 つで候補 5 つを全欄埋めた / `docs/同期設計メモ.md` §54-10）。
///
/// ---
///
/// ## ★★ なぜアカウントと同じ形（JSON 1 つに全件）にしないか ★★
///
/// ★★**デッキは★同期のたびに変わる**★★ —— ★**全件を 1 ファイルに置くと、
/// ★1 デッキ直すたびに★★全利用者ぶんを書き直す★★。**
/// ★**アカウントは★作るときにしか増えない**ので、★あちらは 1 ファイルで足りる。
/// → ★★**同型としてまとめない**★★（`docs/同期設計メモ.md` §7-7）。
///
/// ## ★★ 柵 —— ★★受け取った字面をファイル名にしない（決定 **D134-7**）★★
///
/// ★★**利用者名は★呼ぶ側が決める**★★（**D133-4** ＝ ★誰でもアカウントを作れる）。
/// → ★**そのままファイル名にすると★★別の場所を指す名前を送れる★★。**
/// → ★★**名前は★利用者名の SHA-256 の 16 進にする。**★★
/// ★**利用者名そのものは★ファイルの★中に持つ**（★★戻せなくならないため★★）。
///
/// ★★**`deckId` はファイル名にならない**★★ —— ★**JSON の鍵として持つ**ので、
/// ★**同じ危険が無い**（★鍵は★どんな字面でもよい）。
///
/// ## ★★ 中身を 1 バイトも見ない（決定 **D105-2**）★★
///
/// ★**サーバーは保管庫である。★判断しない。**
/// → ★[putDeck] が受け取る `content` は★★字面のまま保管し、★字面のまま返す★★。
/// ★**`loveca_core` を 1 つも呼ばない**（★線 α は空のまま / **D115-6**）。
/// ★**内容ハッシュも★目印も★このパッケージは持たない**（★あれは★アプリ側の量である
/// / **D114-1** / **D124-7**）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// 保管しているファイルの版。
///
/// ★**アカウントの保管（`account_file_store.dart`）とは★★別の版である★★。**
/// ★**別のファイルで、★別のときに形が変わりうる。**
const int deckFileVersion = 1;

/// 預けたデッキの保管（決定 **D134-6**）。
///
/// ★★ 1 人ぶんを 1 ファイルに持つ ★★
/// ★**読み書きのたびにファイルを開く**（★アカウントの保管と違い、★★全部を覚えない★★）——
/// ★**人数に上限が無い**ため（**D133-4**）。★**呼ばれる回数の上限は★未決である**（**N-26**）。
class DeckFileStore {
  DeckFileStore(this._dir);

  final Directory _dir;

  /// ★★ ファイル名は★利用者名の SHA-256 の 16 進（★柵 / **D134-7**）★★
  File _fileFor(String userName) {
    final digest = sha256.convert(utf8.encode(userName)).toString();
    return File('${_dir.path}${Platform.pathSeparator}$digest.json');
  }

  Map<String, String> _readAll(String userName) {
    final file = _fileFor(userName);
    if (!file.existsSync()) return <String, String>{};
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('★保管の中身が表ではない');
    }
    final version = decoded['version'];
    if (version != deckFileVersion) {
      throw FormatException('★知らない版: $version');
    }
    final decks = decoded['decks'];
    if (decks is! Map<String, Object?>) {
      throw const FormatException('★decks が表ではない');
    }
    final rows = <String, String>{};
    decks.forEach((deckId, content) {
      if (content is! String) {
        throw const FormatException('★decks の値が文字列ではない');
      }
      rows[deckId] = content;
    });
    return rows;
  }

  void _writeAll(String userName, Map<String, String> rows) {
    if (!_dir.existsSync()) _dir.createSync(recursive: true);
    final file = _fileFor(userName);
    // ★★ 途中で落ちても元が残る（★アカウントの保管と同じ形）★★
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(jsonEncode({
      'version': deckFileVersion,
      // ★★ 利用者名は★ここに持つ（★ファイル名からは戻せない）★★
      'userName': userName,
      'decks': rows,
    }));
    temp.renameSync(file.path);
  }

  /// 預かる。★★新しく預かったなら `true`、★上書きなら `false` ★★（決定 **D134-8**）。
  bool putDeck(String userName, String deckId, String content) {
    final rows = _readAll(userName);
    final isNew = !rows.containsKey(deckId);
    rows[deckId] = content;
    _writeAll(userName, rows);
    return isNew;
  }

  /// 返す。★無ければ `null`（★★「無い」と「空」を分ける★★）。
  String? fetchDeck(String userName, String deckId) => _readAll(userName)[deckId];

  /// その利用者が預けている件数（★試験と診断のため）。
  int countFor(String userName) => _readAll(userName).length;
}
