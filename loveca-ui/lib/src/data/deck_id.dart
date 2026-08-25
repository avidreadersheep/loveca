/// `deckId` の生成（決定 D62 / `loveca-core/lib/src/entities/deck.dart` の P1）.
///
/// `Deck.deckId` は **UUID v4** と定められている（P1「連番にすると端末間で衝突する」）が、
/// 生成する実装はこれまでリポジトリのどこにも無かった。ここが唯一の実装になる。
///
/// ★★ `uuid` パッケージを入れない ★★
/// UUID v4 は乱数 16 バイトに 6 ビット立てるだけで、依存を 1 つ増やす価値が無い。
/// `docs/UI設計メモ.md` §9-2 が `package_info_plus` を同じ理由で却下したのと一貫させる。
///
/// ★★ `Random.secure()` を使う。`Random()` は使わない ★★
/// CLAUDE.md §1 が禁じているのは **seed なしの `Random()`**（同じ入力から同じ結果が
/// 出なくなるため）。`Random.secure()` は OS の暗号論的乱数源を読むもので
/// **seed という概念を持たない**ため、この禁止に抵触しない。
///
/// ★★ `loveca_core` の `DeterministicRng` とは別物である ★★
/// あちらはシャッフル（総合ルール 10.2.3）の再現性のためのもので、
/// Phase 6 の権威サーバがその結果に権威を持つ。
/// **`deckId` の生成は再現性の対象外**であり、同じ seed から同じ deckId が
/// 出てはならない（出たら端末間で衝突する）。混同すると
/// Phase 6 のリプレイ再現性の話に紛れ込むので、ここで分けておく。
library;

import 'dart:math';
import 'dart:typed_data';

/// `deckId` の供給元。★`Clock`（`clock.dart` / 設計メモ §9-1）と同じ形で注入する。
/// テストで固定値を入れられるようにするため。
typedef DeckIdGenerator = String Function();

/// ★UI 層で乱数を引く場所の 1 つ（ほかに `state/board_seed.dart`）。
///
/// ★★ ここに「唯一」「N 箇所」と書かない ★★
/// 2026-08-24 の時点では本当に唯一で、その日の走査もそう記録している。
/// だが M-B1 で `board_seed.dart` が増えたとき、**この行だけが「唯一の場所」のまま残り**、
/// 同じリポジトリの `board_seed.dart` と正反対のことを書いていた
/// （`ルール整合性チェック_v1.06.md` **D-15**。2026-08-25 に訂正）。
/// ★★**一覧の正は `docs/決定事項一覧.md` の D81 詳細 1 箇所だけである。**★★
/// 3 箇所目を足すなら、そこを直す。**ここには数を書かない。**
final Random _secureRandom = Random.secure();

const String _hex = '0123456789abcdef';

/// RFC 4122 の UUID v4 を 1 つ作る。
///
/// ★★ version / variant のビットを立て忘れても「見た目は UUID」である ★★
/// 32 桁の 16 進数が並んでいるだけなので、目視では絶対に気づけない。
/// `test/data/deck_id_test.dart` が形式を機械的に検査している。
///
/// 立てるビットは 2 箇所（RFC 4122 §4.4）。
///   - 7 バイト目の上位 4 ビット = `0100`（version 4）→ 文字列の 13 桁目が `4`
///   - 9 バイト目の上位 2 ビット = `10`（variant）    → 文字列の 17 桁目が `8/9/a/b`
String randomDeckIdV4() {
  final bytes = Uint8List(16);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }

  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    // 8-4-4-4-12 の区切り。
    if (i == 4 || i == 6 || i == 8 || i == 10) out.write('-');
    final b = bytes[i];
    out
      ..write(_hex[(b >> 4) & 0x0f])
      ..write(_hex[b & 0x0f]);
  }
  return out.toString();
}
