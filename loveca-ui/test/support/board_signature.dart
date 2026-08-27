/// 盤面の署名（M-B5 で `state/board_session_test.dart` に置いたものを共有へ移した）.
///
/// ★★ `GameState` に `==` が無い（`StepCursor` にしかない）★★
/// 一致を見るには構造を書き出すしかない。**手で列挙する以上、落ちた項目は
/// 検査されない**ので、領域は `Zone.values` から回して漏れを防ぐ。
///
/// ★★ 2 か所目の利用者が出たので抜き出した（M-B7 / 決定 D98）★★
/// `board/board_auto_advance_test.dart` の番人 4（停止ステップは盤面を触らない）が
/// 同じ比較を要る。**同じものを 2 つ書くと、片方だけ直されて食い違う**
/// （`ルール整合性チェック_v1.06.md` D-15 と同じ型）。
library;

import 'package:loveca_core/loveca_core.dart';

/// 盤面の全体を 1 つの文字列へ写す。
String boardSignature(GameState state) {
  final out = StringBuffer()
    ..writeln('turn=${state.turnNumber}')
    ..writeln('first=${state.firstPlayerId}')
    ..writeln('cursor=${state.cursor.phase.ruleRef}/${state.cursor.step.ruleRef}')
    ..writeln('judgeWin=${_sorted(state.liveJudgement?.winnerIds)}')
    ..writeln('judgeMoved=${_sorted(state.liveJudgement?.movedToSuccessIds)}')
    ..writeln('resolution=${state.resolution.map(cardSignature).join(',')}');

  for (final player in state.players) {
    out.writeln('-- ${player.playerId}');
    for (final zone in Zone.values) {
      // ★実体を持たない / 専用の入れ物がある 3 つは `cardsIn` が受け取らない。
      if (zone == Zone.stage ||
          zone == Zone.memberArea ||
          zone == Zone.resolution) {
        continue;
      }
      final cards = cardsIn(state, player.playerId, zone);
      out.writeln('${zone.ruleRef}=${cards.map(cardSignature).join(',')}');
    }
    for (final area in player.memberAreas) {
      final stacks = [
        for (final stack in area.stacks)
          '${cardSignature(stack.member)}'
              '[${stack.beneath.map(cardSignature).join('+')}]',
      ];
      out.writeln('area(${area.slot.name})=${stacks.join(' ')}'
          ' orphans=${area.orphans.map(cardSignature).join(',')}');
    }
    for (final zone in OutOfRuleZone.values) {
      final cards = cardsInOutOfRule(state, player.playerId, zone);
      out.writeln('outOfRule(${zone.name})=${cards.map(cardSignature).join(',')}');
    }
  }
  return out.toString();
}

/// 8.4.6 / 8.4.7 の記録。★`Set` は順が不定なので並べてから写す。
String _sorted(Set<String>? ids) =>
    ids == null ? '-' : (ids.toList()..sort()).join(',');

/// ★向き・表裏まで見る。位置だけ見ると 5.2 / 5.3 の取り消しが検査から漏れる。
String cardSignature(CardInstance card) => '${card.instanceId}'
    '/${card.face.name}/${card.orientation?.name ?? '-'}';
