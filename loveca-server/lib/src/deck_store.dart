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

  /// 預かる。★★取ったときの印を先に確かめる★★（**D139-1** ＝ 線 β ／ 決定 **D141**）。
  ///
  /// ## ★★ [expect] は★必須である。★省けない ★★
  ///
  /// ★**省けると、★★呼ぶ側が黙って上書きできる★★**（★★塞ぎたい「第 3 の書き込み」がそのまま残る★★）。
  /// → ★**型で守る** —— ★[DeckPrecondition] は★★2 つの値しか持たない★★ので、
  ///   ★**「印を持たない上書き」は★★書きようが無い★★。**
  ///
  /// ★★**決定 **D134-8** の「新しく預かったなら `true`」は 1 文字も動かない**★★ ——
  /// ★**返り値が★★3 つに増えただけである★★**（★[DeckPutResult]）。★**上書きは★依然として正しい**
  /// （★★同じデッキを何度でも預けられる。★印が合っている限り★★）。
  ///
  /// ## ★★ 印は★保管した字面のハッシュである（**D141-1**）★★
  ///
  /// ★**[deckContentMark] を参照。★★`loveca_core` の `deckContentHash` とは別物である★★**
  /// （**§7-7** —— ★★同じ形だが★見ている対象が違う★★）。
  ///
  /// ## ★★ 確かめてから書くまでを★1 つの読み書きに収める ★★
  ///
  /// ★**呼ぶ側で確かめてから [putDeck] を呼ぶ形にすると、★★そのあいだの書き込みを見落とす★★**
  /// （★★塞ぎたいものと同じ形である★★）。→ ★**この関数の中で★読んで・比べて・書く。**
  DeckPutResult putDeck(
    String userName,
    String deckId,
    String content, {
    required DeckPrecondition expect,
  }) {
    final rows = _readAll(userName);
    final current = rows[deckId];

    final ok = switch (expect) {
      ExpectAbsent() => current == null,
      ExpectMark(:final mark) =>
        current != null && deckContentMark(current) == mark,
    };
    if (!ok) return DeckPutResult.preconditionFailed;

    rows[deckId] = content;
    _writeAll(userName, rows);
    return current == null ? DeckPutResult.created : DeckPutResult.replaced;
  }

  /// 返す。★無ければ `null`（★★「無い」と「空」を分ける★★）。
  String? fetchDeck(String userName, String deckId) => _readAll(userName)[deckId];

  /// 預けているデッキの `deckId` を返す（★§32-6 の **21** が要る）。
  ///
  /// ## ★★ 並びは★字面の昇順である。★規則順ではない ★★
  ///
  /// ★**デッキの規則順は `loveca_core` の `deck_order.dart` が持つ**（**D99**）。
  /// ★★**このパッケージは★それを呼べない**★★（★線 α は空のまま / **D115-6** / **D126-3**）。
  /// → ★**字面（コードポイント）の昇順にする。★★意味を 1 つも持たない並びである★★。**
  ///
  /// ★★ なぜ並べるか —— ★保管した順にしない ★★
  /// ★**JSON の表は★★足した順を覚える★★**（★Dart の `Map` の性質）。
  /// → ★**そのまま返すと、★★どのデッキを先に預けたかが★並びに出る★★。**
  /// ★**害は今日 1 つも無い**（★見えるのは★本人だけである / **D105-3**）が、
  /// ★★**2 台が同じ集合を持っていても★並びが違う★★**ので、★呼ぶ側が★★並びで比べられない★★。
  ///
  /// ★★ 空の一覧と「利用者が無い」を分けない ★★
  /// ★**名乗れなければ 401 である**（★口の側 / **D105-3**）。
  /// → ★**ここに来る時点で★利用者は在る。★★空の一覧は「まだ 1 つも預けていない」だけ★★。**
  List<String> listDeckIds(String userName) {
    final ids = _readAll(userName).keys.toList()..sort();
    return ids;
  }

  /// その利用者が預けている件数（★試験と診断のため）。
  int countFor(String userName) => _readAll(userName).length;
}

/// ★★ 預けるときに★呼ぶ側が名乗る前提（**D141** の 印-1）★★
///
/// ★★ 2 つしか無い。★「前提を持たない」を★★書きようが無くする★★ ★★
/// ★**`String?` にすると `null` が「前提なし」にも「無いはず」にも読める**（★★意味が 2 つになる★★）。
/// → ★**型で分ける**（★先例は `loveca_core` の `SyncOutcome` / **D105-6**）。
sealed class DeckPrecondition {
  const DeckPrecondition();
}

/// ★まだ 1 つも預けていないはず（★初回）。
final class ExpectAbsent extends DeckPrecondition {
  const ExpectAbsent();
}

/// ★取ったときの印が [mark] だったはず。
final class ExpectMark extends DeckPrecondition {
  const ExpectMark(this.mark);

  /// [deckContentMark] が返す 16 進小文字。
  final String mark;
}

/// 預けた結果。
///
/// ★★ 3 つに分ける。★畳まない ★★
/// ★**[created] と [replaced] は★★状態コードが違う★★**（201 / 200 / **D134-8**）。
/// ★**[preconditionFailed] は★★どちらとも違う★★**（412 / **D141-2**）。
enum DeckPutResult {
  /// 新しく預かった。
  created,

  /// 上書きした（★印が合っていた）。
  replaced,

  /// ★★取ったときの印が合わない。★1 バイトも書いていない★★。
  preconditionFailed,
}

/// ★★ 保管した字面の印（**D141-1**）★★
///
/// ## ★★ `loveca_core` の `deckContentHash` とは★★別物である★★ ★★
///
/// | | `deckContentHash`（**D115-1**） | ★★[deckContentMark]（★これ）★★ |
/// |---|---|---|
/// | ★何を掴むか | ★**デッキの 5 フィールドを★★正規化した表現★★**（**D115-3**） | ★★**サーバーが保管している★字面そのもの**★★ |
/// | ★誰が計算するか | ★**アプリ側**（`loveca_core`） | ★★**サーバー**★★（★★毎回計算する。★持たない★★ / **D114-1**） |
/// | ★同じ値になるか | ★—— | ★★**ならない**★★（★★同じ名前でも★見ている対象が違う★★ / **§7-7**） |
///
/// ★★**サーバーは印を★★保管しない★★**★★ —— ★**要求のたびに計算する。**
/// ★**保管の形（`deckFileVersion`）は 1 も動かない**（**D114-1** / **D124-7** の (c)）。
///
/// ## ★★ 費用（2026-09-02 実測 / ★この機械 / ★2,000 回の平均）★★
///
/// | 中身の大きさ | ★1 回 |
/// |---|---|
/// | 1 KiB | ★**14.49 µs** |
/// | 8 KiB | ★**80.29 µs** |
/// | 64 KiB | ★**638.44 µs** |
///
/// ★★**「軽い」とは書かない**★★（**D-28**）—— ★**書けるのは上の表までである。**
/// ★**参考: ★同じ要求が通る `authenticate` は★★1.5 秒★★である**（`rate_limit.dart` の分母）。
String deckContentMark(String content) =>
    sha256.convert(utf8.encode(content)).toString();
