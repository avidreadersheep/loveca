/// エネルギーデッキ置き場からの抽出（決定 D73 / 整合性チェック B-2 の解消）.
///
/// ★★ 「一番上」を採らない。無作為に 1 枚ずつ抜く ★★
///
/// | 条 | 本文（要旨） |
/// |---|---|
/// | 4.9.2 | エネルギーデッキ置き場は非公開領域で、**カードの順番は管理されません** |
/// | 4.9.3 | 他の領域に**複数枚移動する場合、1 枚ずつ移動を行います** |
/// | 6.2.1.3 | エネルギーデッキを置き場に**置きます**（★シャッフルの指示が無い） |
/// | 6.2.1.7 | エネルギーデッキ置き場の**上から 3 枚**をエネルギー置き場へ |
/// | 7.5.2 | 自身のエネルギーデッキの**一番上のカード**をエネルギー置き場へ |
///
/// ★★ 「非公開領域だから観測上の差は出ない」は成立しない ★★
///   6.2.1.3 がシャッフルしないので [Zone.energyDeck] の並びは
///   **デッキリストを並べた順そのもの**になる。つまり「一番上」＝
///   プレイヤーが構築時に決めた順であり、**プレイヤーが選べてしまう**。
///   4.9.2 が「順番は管理されない」と定めて奪っているはずの選択を、
///   `deck.first` を採る実装が返していた。
///
/// ★★ 「6.2.1.3 でシャッフルしてから上から採る」も採らない ★★
///   ①条文に無いシャッフルを足すことになる。
///   ②エネルギーカードは控え室を経由しない**閉ループ**
///     (4.9.1 →(6.2.1.7 / 7.5.2)→ 4.7 → 5.10.1 → 10.5.4) で
///     **デッキへ戻ってくる**ため、戻すたびに再シャッフルが要り、
///     **挿入位置が観測可能な設計になる**。
///   無作為抽出なら**戻す位置を決める必要が最初から無い**。
///
/// ★★ 「見て 1 枚選ぶ」は別の操作である ★★
///   効果がエネルギーデッキを見て指定する場合は `MoveCard`（instanceId 指定）を使う。
///   無作為と指定を片方に畳まないこと（決定 D73 の変更 #3）。
library;

import 'card_move.dart';
import 'game_state.dart';
import 'rng.dart';
import 'zone.dart';

/// エネルギーデッキ置き場から**無作為に** [count] 枚をエネルギー置き場へ移す。
///
/// ★★ この関数が D73 の唯一の実装である ★★
///   呼び出し元は 3 つ。
///     - 7.5.2（`StepEngine` のエネルギーフェイズ / [count] は 1）
///     - `DrawEnergy` アクション（`reduce`）
///     - 6.2.1.7（`GameSetup.dealInitialEnergy` / [count] は
///       `RuleConfig.initialEnergyOnField`）
///   増やすときもここを直す。**抽出の実装を 2 つにしない。**
///
/// ★4.9.3「1 枚ずつ移動を行います」に合わせ、1 回ごとに index を引き直す。
///   まとめて [count] 枚を選ぶのではない。
///
/// ★★ 足りなければ引けた分で止まる ★★
///   エネルギーは閉ループでメインデッキのようなリフレッシュ (10.2) が無いため、
///   6.1.1.3 の 12 枚を使い切ると出せなくなる。**例外にしない**（7.5.2 は
///   毎ターン自動で走るので、尽きた瞬間にゲームが止まってしまう）。
///   ★代わりに UI 側がボタンを無効にして理由を出すこと（黙って何も起きない形にしない）。
GameState drawEnergyRandomly(
  GameState state,
  String playerId,
  int count,
  DeterministicRng rng,
) {
  var next = state;
  for (var i = 0; i < count; i++) {
    final deck = cardsIn(next, playerId, Zone.energyDeck);
    if (deck.isEmpty) break;

    // ★4.9.2: 順番が管理されない領域なので、位置に意味を持たせない。
    final index = rng.nextInt(deck.length);

    // 4.7.3 / 4.3.2.3: エネルギー置き場は向きを持ち、既定はアクティブ状態。
    // 4.1.2.1 / 4.7.2: エネルギー置き場は公開領域なので表向き。
    final moved = placedIn(deck[index], Zone.energyField);

    next = replaceZone(next, playerId, Zone.energyDeck, [
      ...deck.sublist(0, index),
      ...deck.sublist(index + 1),
    ]);
    next = replaceZone(
      next,
      playerId,
      Zone.energyField,
      insertInto(
        cardsIn(next, playerId, Zone.energyField),
        [moved],
        ZonePosition.top,
      ),
    );
  }
  return next;
}
