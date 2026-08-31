/// 内容ハッシュの入力の**正規化された表現**（決定 **D115-3** の柵）.
///
/// ★★ この版はハッシュを 1 バイトも作らない ★★
/// `docs/同期設計メモ.md` §32-6 のコミット 11 に対応する。
/// **D115-3** が「★入力の正規化された表現を★固定してからでないと、2 台がハッシュを
/// 交換できない」と定めており、★**「決めてから交換する」という順序だけを先に固定する。**
/// ★畳む側（SHA-256 / **D115-2**）はコミット 12 である。
///
/// ★★ なぜ `loveca_core` に置くか（★§32-6 が「12 の時点で決める」と書いた分）★★
/// 1. ★**入力は `Deck` そのものである。** 5 フィールドの並びも意味も
///    `entities/deck.dart` が持っており、★**`Deck` に列が増えたときに
///    「掴む対象を見直す」判断が要るのはこのファイルの隣である。**
/// 2. ★**`loveca_db` は答えを文字列として持つだけで、計算しない**
///    （`docs/同期設計メモ.md` §25-4）。→ ★DB 層に置く理由が無い。
/// 3. ★**`loveca-ui` に置くと Flutter の後ろに入る。** Phase 5 / Phase 6 で
///    同じ表現を作り直せなくなり、★**それは「2 台が交換できない」そのものである。**
///
/// ★★ 払う代償を隠さない ★★
/// ★コミット 12 が `crypto` を足すと、★**`loveca_core` にとって最初の依存になる**
/// （`docs/同期設計メモ.md` §25-4 の「記録すること」）。★**このファイル自身は依存を 1 つも増やさない。**
///
/// ★★ 総合ルールの条番号は 1 つも引かない ★★
/// これはゲームの規則ではなく**同期の表現**である（`deck_edit_op.dart` と同じ扱い）。
/// 根拠として引くのは決定番号である。
library;

import 'dart:convert';

import '../entities/deck.dart';

/// 表現の版。★**先頭に必ず入る。**
///
/// ★★ これを変えると、保存済みの基準ハッシュが全部意味を失う ★★
/// 器（**D114-1**）は「前回同期時点の内容ハッシュ」を持つ。★表現が変われば
/// 同じ内容から違う値が出るので、★**全デッキが衝突になる**
/// （`docs/同期設計メモ.md` §25-4 の 畳-2 の壊れ方と同じ形）。
/// → ★**変えるときは、器の側の作り直しと同時に行うこと。**
const String canonicalDeckContentVersion = 'loveca.deck.content/1';

/// [deck] の内容を、★**端末と版をまたいで 1 つに定まるバイト列**にする。
///
/// ★★ 掴む対象は 5 フィールドである（決定 **D111-4**）★★
/// `name` / `memo` / `coverPrintingId` / `tags` / ★**並びと枚数の列**。
/// ★これは `DeckDraft.isDirtyAgainst`（`loveca-ui`）が比べる 5 つと同じである。
/// ★**`Deck.toJson()` を使ってはならない** —— `updatedAt` / `revision` /
/// `lastDeviceId` を含むので**保存のたびに必ず変わり**、候補 L（**D111-2**）の
/// 「内容が一致するものを落とす」段が 1 度も働かなくなる（★L が G に退化する）。
///
/// ★★ 入らないものを明示する ★★
/// `deckId` / `createdAt` / `updatedAt` / `deletedAt` / `revision` /
/// `lastDeviceId` / `masterDataVersion` は**1 つも入らない**。
///
/// ★★ とくに [Deck.deletedAt] が入らないことの帰結 ★★
/// **D116-12** が実読で書いている ——「★**削除は内容ハッシュに 1 ビットも現れない。
/// 見る手段はログ 1 つだけである。**」
/// → ★**論理削除だけが起きたデッキは、この関数の出力が 1 バイトも変わらない。**
/// ★**それは欠陥ではなく D111-4 の帰結である。**読む側が知っていなければならない
/// （`deck_conflict.dart` の判定がこの性質を doc で受けている）。
///
/// ★★ 並びを落とさない（決定 **D99**）★★
/// `entries` も `tags` も**リストの順のまま**入れる。★並べ替えは保存される
/// （`deck_entries.ord`）ので、`isDirtyAgainst` は並びを見る。★ここで並べ替えると
/// 「並べ替えただけの変更」が黙って消える。
///
/// ★★ 文字列を 1 文字も変換しない ★★
/// 大小・全角半角・Unicode の合成の正規化を**一切しない。**
/// ★理由は 1 つ —— ★**`isDirtyAgainst` が変換しないからである**（**D111-4** の「揃える」）。
/// ★ここだけ畳むと、★**画面が「変更あり」と言うのにハッシュが一致する**状態が作れる。
///
/// ★★ 区切り文字だけの連結にしない（**D115-3** の柵 2）★★
/// `name` / `memo` / `tags` は**自由文**であり、★利用者が区切りに使った文字を
/// 中に入れられる。★**そのままでは別のデッキと同じ表現を作れる。**
/// → ★**各値の前に「UTF-8 でのバイト数」を置く。**★長さが先に来れば、
/// 続くバイトが値の一部か次の値かが**中身によらず定まる。**
/// ★**規約ではなく形で守る。**
List<int> canonicalDeckContentBytes(Deck deck) {
  final out = <int>[];

  void writeRaw(String ascii) => out.addAll(utf8.encode(ascii));

  /// 1 つの値。★`<UTF-8 のバイト数>:<バイト列>`。
  void writeValue(String value) {
    final bytes = utf8.encode(value);
    writeRaw('${bytes.length}:');
    out.addAll(bytes);
  }

  /// null を取りうる値。★**`null` と空文字を別の表現にする。**
  /// ★`coverPrintingId` は「未設定」と「空の刷り番号」が別の状態でありうる。
  void writeOptional(String? value) {
    if (value == null) {
      writeRaw('-');
      return;
    }
    writeRaw('+');
    writeValue(value);
  }

  /// 列。★**件数を先に置く。**長さ前置だけでは
  /// 「`['ab']` と `['a','b']`」を分けられない位置が作れる。
  void writeCount(int count) => writeRaw('$count;');

  writeRaw(canonicalDeckContentVersion);
  writeValue(deck.name);
  writeValue(deck.memo);
  writeOptional(deck.coverPrintingId);

  writeCount(deck.tags.length);
  for (final tag in deck.tags) {
    writeValue(tag);
  }

  writeCount(deck.entries.length);
  for (final entry in deck.entries) {
    writeValue(entry.printingId);
    // ★枚数も同じ形で書く。★`printingId` との境界を中身に依存させない。
    writeValue('${entry.count}');
  }

  return out;
}
