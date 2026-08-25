/// ★★ 相手を「描かない」のではなく「そもそも参照しない」（決定 D88 / 盤面設計メモ §14-5）★★
///
/// ソロでも `GameState.players` は 2 人のままである（1.1.1）。
/// **2 人居ることと、ソロに相手が居ることは別**なので、
/// 「ソロでは相手側を描かない」を描画の分岐で守ると、
/// M-B6 以降で誰かが 2 人目を読んで機能を足したときに**幽霊が漏れる。**
///
/// ★★ 手当ては 2 段ある ★★
///
/// | # | 手当て | 効き方 |
/// |---|---|---|
/// | 1 | `BoardView.opponent` を **`PlayerState?`** にする | ★相手を読んでいる箇所が**全部コンパイルエラーになる** |
/// | 2 | ★**この走査** | 型で守れない「引き直し」を機械で塞ぐ |
///
/// D77 が「`HiddenPile` は枚数しか受け取らない」で秘匿を守ったのと**同じ形**である。
///
/// ★★ 禁じているのは「引き直すこと」であって「受け取ること」ではない ★★
/// `BoardSummaryPanel(players: ...)` のように**渡された一覧**を読むのは正しい。
/// だから走査は `state.players` と `playerOf(`（＝ `GameState` から引く 2 経路）だけを見る。
///
/// ★★ 陽性対照を対で置く（`ルール整合性チェック_v1.06.md` D-15 §12-5）★★
/// 0 件は「無い」と「見えていない」の区別がつかない。
///
/// ★`state/game_store.dart` は走査の対象外である。理由 ——
/// `BoardState.opponentId` は**モードを見て `String?` を返す**ので型で守られており、
/// 盤面の描画そのものではなく Store の内部だから。★対象は
/// 「盤面を描くところ」＝ `lib/src/ui/board/` と `lib/src/state/board_*.dart`。
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// `GameState` からプレイヤーを**引き直す**経路。
///
/// ★`widget.players` / `this.players`（受け取った一覧）には当たらない。
final _playerLookup = RegExp(r'\bplayerOf\(|\bstate\.players\b');

/// `lib/src/state/` のうち盤面のもの。
Map<String, int> _boardStateHits() {
  final hits = scanDart('lib/src/state', _playerLookup);
  hits.removeWhere((name, _) => !name.startsWith('board_'));
  return hits;
}

void main() {
  test('★★ 陽性対照: 同じ走査が loveca_core では当たる ★★', () {
    // ★これが 0 件なら、下の「0 件」は「無い」ではなく「見えていない」。
    final hits = scanDart(coreLibPath, _playerLookup);

    expect(hits, isNotEmpty);
    expect(hits.keys, contains('turn_order.dart'),
        reason: '★opponentOf / turnPlayerOf が state.players を読む');
  });

  test('★★ ui/board/ で引き直すのは board_view.dart だけ ★★', () {
    final hits = scanDart('lib/src/ui/board', _playerLookup);

    // ★見つかっていることを先に確かめる（0 件は何も証明しない）。
    expect(hits, isNotEmpty);
    expect(hits.keys.toSet(), {'board_view.dart'},
        reason: '★盤面の各所が GameState からプレイヤーを引き直している。'
            'ソロで相手側の幽霊が漏れる経路になる（決定 D88 / §14-5）');
  });

  test('★★ state/board_*.dart では 1 件も引き直さない ★★', () {
    // ★★ ここは「0 件」でよい ★★
    //   上のテストが同じ走査の生きていることを示しており、
    //   陽性対照も別に置いてある。
    expect(_boardStateHits(), isEmpty,
        reason: '★描くプレイヤーは受け取る（`derivedBoardNotices` の引数）');
  });

  test('★ 走査の対象そのものが空でない（前提）', () {
    // ★★ ディレクトリ名を間違えていると、上の 0 件は「見ていない」になる ★★
    //   走査対象に .dart が実在することを、別の語で確かめる。
    expect(scanDart('lib/src/ui/board', RegExp(r'\bBoardView\b')), isNotEmpty);
    expect(scanDart('lib/src/state', RegExp(r'\bBoardNotice\b')), isNotEmpty);
  });
}
