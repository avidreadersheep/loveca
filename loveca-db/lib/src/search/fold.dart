/// 検索用の表記ゆれ折りたたみ（決定 D40）.
///
/// ★★ 正本の値には絶対に適用しない ★★
/// CLAUDE.md §5-(5)「未知の名前は勝手に変えない」を守るため、
/// `card_names.value` などの保存列は**公式の表記のまま**にする。
/// この関数を通すのは検索索引（`card_search` と `cards.search_blob`）と
/// 検索クエリの 2 か所だけで、いずれも派生物である。
/// 新作品・新ユニットが入っても正本が壊れることは構造上ありえない。
///
/// ## なぜ必要か
///
/// 実データのユニット名は全角半角が混在している。
///
/// ```
/// CYaRon！(全角)   CatChu!(半角)   5yncri5e!(半角)   みらくらぱーく！(全角)
/// ```
///
/// 利用者が `CYaRon!` と半角で打つと当たらない。
/// 索引側とクエリ側に**同じ関数**を通すことで、この差を消す。
/// SQLite の trigram 自身がどう畳むかは正しさに影響しない（両側に等しく効くため）。
///
/// ## 適用順
///
/// 実データの全検索対象テキストを走査したところ、NFKC で変化する文字は
/// **22 種だけ**だった（`：！＋１＆（）２６［］３？５４９＊～８－０` と
/// `µ`(MICRO SIGN) → `μ`）。全 NFKC を持ち込まず、範囲を限った静的規則にしてある。
///
/// 1. 半角カナ `U+FF61–FF9F` → 全角（濁点 `ﾞ` / 半濁点 `ﾟ` は合成）
/// 2. 全角 ASCII `U+FF01–FF5E` → 半角、全角空白 `U+3000` → 半角空白
/// 3. `µ` `U+00B5` MICRO SIGN → `μ` `U+03BC` GREEK SMALL MU
/// 4. 小文字化（`String.toLowerCase()`。Unicode 全域・ロケール非依存）
///
/// ★順序依存は無い。★ 明示しておかないと後から順を入れ替えられて静かに壊れる。
///
/// - **3 と 4**: `µ`(U+00B5) の Unicode 小文字写像は**自身**なので `toLowerCase()` は
///   恒等。先に 3 を通しても後に通しても `μ` になる。加えて `Μ`(U+039C GREEK
///   CAPITAL MU) は 4 が `μ` に落とすため `Μ's` と打っても当たる
/// - **2 と 4**: `Ａ`(U+FF21) は「2→4」で `A`→`a`、「4→2」で `ａ`→`a`。どちらも `a`
/// - **1 と 2**: `U+FF61–FF9F` と `U+FF01–FF5E` は範囲が交わらないので独立
///
/// ★冪等（`fold(fold(x)) == fold(x)`）★
/// 各段の出力が前段の入力域に戻らない。1 の出力は全角カナ（`U+FF61–FF9F` 外）、
/// 2 の出力は ASCII（`U+FF01–FF5E` 外）、3 の出力は `U+03BC`（`U+00B5` ではない）、
/// 4 は Unicode の単純小文字写像なので冪等。2 の後に全角 ASCII が 1 文字も残らないため、
/// 4 が全角文字を再生成することもない。テストで固定してある。
library;

/// trigram トークナイザが機能する最小の文字数。
///
/// ★これ未満の語は `MATCH` が**エラーにならず静かに 0 件**を返す★
/// 実測で `花帆`(2 文字) は 0 件、`LIKE` なら 35 件。黙って 0 件を返すのは
/// A-3（数字なし表記を 59 種で無言に落としていた）と同じ失敗の型なので、
/// 呼び出し側は [isTrigramSearchable] で分岐して `LIKE` に切り替える。
const int minTrigramLength = 3;

/// 折りたたみ後の [query] が trigram で引けるか。
///
/// 文字数は**符号位置単位**で数える（SQLite の trigram と同じ単位）。
bool isTrigramSearchable(String query) =>
    query.runes.length >= minTrigramLength;

/// 検索用に表記を折りたたむ。索引側とクエリ側の両方でこれを通す。
String fold(String input) {
  if (input.isEmpty) return input;

  final out = StringBuffer();
  final runes = input.runes.toList(growable: false);

  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];

    // 1. 半角カナ → 全角（濁点・半濁点を合成する）
    if (r >= _halfKanaStart && r <= _halfKanaLast) {
      var ch = _fullWidthKana[r - _halfKanaStart];
      if (i + 1 < runes.length) {
        final next = runes[i + 1];
        if (next == _halfVoiced) {
          final voiced = _voicedOf(ch);
          if (voiced != null) {
            ch = voiced;
            i++;
          }
        } else if (next == _halfSemiVoiced) {
          final semi = _semiVoicedOf(ch);
          if (semi != null) {
            ch = semi;
            i++;
          }
        }
      }
      out.write(ch);
      continue;
    }
    // 合成先が無い単独の濁点・半濁点は全角の記号に寄せる。
    if (r == _halfVoiced) {
      out.writeCharCode(0x309B);
      continue;
    }
    if (r == _halfSemiVoiced) {
      out.writeCharCode(0x309C);
      continue;
    }

    // 2. 全角 ASCII → 半角 / 全角空白 → 半角空白
    if (r >= 0xFF01 && r <= 0xFF5E) {
      out.writeCharCode(r - 0xFEE0);
      continue;
    }
    if (r == 0x3000) {
      out.writeCharCode(0x20);
      continue;
    }

    // 3. MICRO SIGN → GREEK SMALL MU（グループ名 μ's のため）
    if (r == 0x00B5) {
      out.writeCharCode(0x03BC);
      continue;
    }

    out.writeCharCode(r);
  }

  // 4. 小文字化
  return out.toString().toLowerCase();
}

/// 複数の断片を 1 本の検索用テキストに畳む。
///
/// `cards.search_blob`（2 文字以下の語のための `LIKE` 対象）を作るのに使う。
/// 区切りに改行を入れるのは、断片をまたぐ偽のトライグラムを作らないため。
String foldJoin(Iterable<String> parts) =>
    fold(parts.where((p) => p.isNotEmpty).join('\n'));

// ---------------------------------------------------------------------------

const int _halfKanaStart = 0xFF61; // ｡
const int _halfKanaLast = 0xFF9D; // ﾝ
const int _halfVoiced = 0xFF9E; // ﾞ
const int _halfSemiVoiced = 0xFF9F; // ﾟ

/// `U+FF61`〜`U+FF9D` に 1 対 1 で対応する全角形（61 文字）。
const String _fullWidthKana = '。「」、・ヲァィゥェォャュョッー'
    'アイウエオカキクケコサシスセソタチツテトナニヌネノ'
    'ハヒフヘホマミムメモヤユヨラリルレロワン';

const String _voicedBase = 'カキクケコサシスセソタチツテトハヒフヘホウワヲ';
const String _voicedForm = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボヴヷヺ';
const String _semiVoicedBase = 'ハヒフヘホ';
const String _semiVoicedForm = 'パピプペポ';

String? _voicedOf(String base) {
  final i = _voicedBase.indexOf(base);
  return i < 0 ? null : _voicedForm[i];
}

String? _semiVoicedOf(String base) {
  final i = _semiVoicedBase.indexOf(base);
  return i < 0 ? null : _semiVoicedForm[i];
}
